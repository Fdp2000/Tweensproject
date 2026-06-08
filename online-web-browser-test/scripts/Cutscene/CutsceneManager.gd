extends Node3D

@export var skip_cutscene: bool = false

@export var thief_preview_scene: PackedScene = preload("res://Assets/Models/Chameleon/chameleon.tscn")
@export var thief_rotation_offset_degrees: float = -90.0
@export var thief_versus_anims: Array[String] = [
	"Dismissing Gesture",
	"Pointing Gesture",
	"Taunt",
	"Waving Gesture"
]

@export var cop_preview_scene: PackedScene = preload("res://Assets/Models/Chameleon/chameleon.tscn")
@export var cop_rotation_offset_degrees: float = -90.0
@export var cop_versus_anims: Array[String] = [
	"Standing Taunt Chest Thump",
	"Standing Taunt Battlecry"
]
@export var versus_duration: float = 3.0
@export var fly_to_player_time: float = 1.5
@export var chameleon_skin_materials: Array[Material]
@export var rhino_skin_materials: Array[Material]


@export_group("Transition & Blend Timings")
@export var pre_game_fade_to_black_time: float = 1.0
@export var versus_fade_in_time: float = 1.0
@export var versus_fade_out_time: float = 1.0
@export var museum_fade_in_time: float = 0.5
@export var cop_head_hide_threshold: float = 0.85
@export var anim_blend_in_time: float = 0.2
@export var anim_blend_out_time: float = 0.5

@onready var intro_camera: Camera3D = $Node3D/IntroCamera
@onready var cutscene_ui: CutsceneUI = $"../VersusScreen"
@onready var cutscene_markers: Node3D = $CutsceneMarkers

# Markers
@onready var versus_pos: Marker3D = $CutsceneMarkers/VersusPos
@onready var left_spawn: Marker3D = $CutsceneMarkers/VersusPos/LeftSpawn
@onready var right_spawn: Marker3D = $CutsceneMarkers/VersusPos/RightSpawn


var default_intro_cull_mask: int
var local_player: Node3D
var spawned_dummy_models: Array[Node] = []

func _ready():
	default_intro_cull_mask = intro_camera.cull_mask
	var game_manager = get_tree().get_root().find_child("GameManager", true, false)
	if game_manager:
		game_manager.pre_game_started.connect(_on_pre_game_started)
		game_manager.game_started.connect(_on_game_started)
		game_manager.game_ended.connect(_on_game_ended)

	if versus_pos:
		versus_pos.hide()

func _on_game_ended():
	if versus_pos:
		versus_pos.hide()

func _on_pre_game_started(_assignments):
	cutscene_ui.background.modulate.a = 0.0
	cutscene_ui.visible = true
	AudioManager.stop_music(pre_game_fade_to_black_time)
	await cutscene_ui.fade_to_black(pre_game_fade_to_black_time)

func _on_game_started():
	await get_tree().create_timer(0.3).timeout
	local_player = await wait_for_local_player()
	
	if local_player == null:
		return
		
	if local_player.get("charge_ui_ref"):
		local_player.charge_ui_ref.modulate.a = 0.0
		
	# Skip logic
	if skip_cutscene:
		finish_cutscene_immediately()
		return

	# Disable player controls early
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(false)
		
	# Turn off lobby camera
	var lobby_camera = get_tree().get_first_node_in_group("menu_camera") as Camera3D
	if lobby_camera:
		lobby_camera.current = false
		
	intro_camera.current = true
	
	# --- SHADER PRECOMPILER (WEB OPTIMIZATION) ---
	# We dynamically attach the precompiler to the active intro_camera. 
	# Because the screen is perfectly black from fade_to_black(), the player never sees the shaders flash!
	var precompiler_script = load("res://scripts/managers/shader_precompiler.gd")
	if precompiler_script:
		var precompiler = Node3D.new()
		precompiler.set_script(precompiler_script)
		intro_camera.add_child(precompiler)
	# ---------------------------------------------
	
	# Start orchestrating the cutscene
	await run_cinematic_flow()

func wait_for_local_player() -> Node3D:
	var attempts := 0
	while attempts < 60:
		var player = find_local_player()
		if player != null:
			return player
		attempts += 1
		await get_tree().process_frame
	return null

func find_local_player() -> Node3D:
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if spawned == null: return null
	var my_id := multiplayer.get_unique_id()
	
	for player in spawned.get_children():
		if str(player.name) == str(my_id):
			# Ensure we are grabbing the NEW game player, not the old lobby player
			var my_role = GameManager.players.get(my_id, {}).get("role")
			if my_role != null and player.get("team_index") == my_role:
				return player
	return null

func get_display_name(player: Node3D) -> String:
	var n = player.get("player_name")
	if n != null and str(n) != "":
		return str(n)
	return "Player " + str(player.name)

# ---------------------------------------------------------
# THE CINEMATIC FLOW
# ---------------------------------------------------------
func run_cinematic_flow():
	# Reset camera mask in case it was modified in a previous match
	intro_camera.cull_mask = default_intro_cull_mask
	
	if versus_pos:
		versus_pos.show()
	
	# 1. Ensure screen is black (already done in _on_game_started)
	
	# 2. Setup Versus Scene in the 3D world
	var lineup_cam_pos = $CutsceneMarkers/VersusPos/LineupCameraPos if $CutsceneMarkers/VersusPos.has_node("LineupCameraPos") else versus_pos
	intro_camera.global_transform = lineup_cam_pos.global_transform
	
	# If the user placed a preview Camera3D under LineupCameraPos, use its FOV!
	var preview_cam = lineup_cam_pos.find_child("Camera3D", true, false)
	if preview_cam:
		intro_camera.fov = preview_cam.fov
	else:
		intro_camera.fov = 35.0
	setup_versus_lineup()
	
	# 3. Fade into Versus Screen
	var vs_label = cutscene_ui.get_node_or_null("Root/VSLabel")
	if vs_label:
		vs_label.show()
		
	AudioManager.play_music("match_start", 0.0)
	await cutscene_ui.fade_in(versus_fade_in_time)
	
	await get_tree().create_timer(0.10).timeout
	
	# Trigger the randomized taunts now that the screen is visible!
	play_versus_taunts()
	
	# 4. Wait for versus duration
	await get_tree().create_timer(versus_duration).timeout
	
	# 5. Fade to black to transition to Museum Pans
	await cutscene_ui.fade_to_black(versus_fade_out_time)
	
	# Hide the dummies from view entirely so they don't photobomb the background!
	if versus_pos:
		versus_pos.hide()
	
	vs_label = cutscene_ui.get_node_or_null("Root/VSLabel")
	if vs_label:
		vs_label.hide()
	
	# 6. Play 3 Cinematic Clips
	await play_cinematic_clip($CutsceneMarkers/Clip1Start, $CutsceneMarkers/Clip1End, 3.0)
	await play_cinematic_clip($CutsceneMarkers/Clip2Start, $CutsceneMarkers/Clip2End, 3.0)
	
	var is_cop = local_player.get("team_index") == 1
	var clip3_start = $CutsceneMarkers/Clip3CopStart if is_cop else $CutsceneMarkers/Clip3ThiefStart
	var clip3_end = $CutsceneMarkers/Clip3CopEnd if is_cop else $CutsceneMarkers/Clip3ThiefEnd
	await play_cinematic_clip(clip3_start, clip3_end, 3.0)
	
	# 7. Smooth fly to the actual player camera
	var target_cam = get_player_gameplay_camera(local_player)
	await fly_camera_to_target(target_cam)
	
	# Switch to real player camera
	target_cam.current = true
	
	# 8. Delay 1 second
	await get_tree().create_timer(1.0).timeout
	
	# 9. Play Countdown and fade in UI
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("fade_in"):
		hud.fade_in(1.5)
		
	get_tree().call_group("dotted_rings", "fade_in", 3.0)
		
	if local_player.get("charge_ui_ref"):
		var fade_tween = create_tween()
		fade_tween.tween_property(local_player.charge_ui_ref, "modulate:a", 1.0, 3.0)
		
	if local_player.has_method("unlock_camera"):
		local_player.unlock_camera()
		
	await cutscene_ui.play_countdown()
	
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)
		
	AudioManager.play_music("base_tension", 0.1)
	GameManager.start_game_clock()

# ---------------------------------------------------------
# VERSUS LINEUP LOGIC
# ---------------------------------------------------------
func get_dummies(parent_node: Node3D) -> Array:
	var dummies = []
	for child in parent_node.find_children("*", "Node3D", true, false):
		if child.has_node("NameTag"):
			dummies.append(child)
			
	# Sort dummies alphabetically by their parent marker's name
	# This allows the user to rename the markers (e.g. ThiefPreviewPos0) to reorder the players!
	dummies.sort_custom(func(a, b): return str(a.get_parent().name) < str(b.get_parent().name))
	
	return dummies

func setup_versus_lineup():
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if spawned == null: return
	
	var robbers := []
	var cops := []
	
	for player in spawned.get_children():
		var team_index = player.get("team_index")
		if team_index == 1:
			cops.append(player)
		else:
			robbers.append(player)
			
	var preplaced_thieves = get_dummies(right_spawn)
	var preplaced_cops = get_dummies(left_spawn)
			
	for i in range(preplaced_thieves.size()):
		var model = preplaced_thieves[i]
		if i < robbers.size():
			model.show()
			apply_versus_skin(model, robbers[i])
			play_emote(model, "Idle1")
			add_name_tag_to_model(model, get_display_name(robbers[i]))
		else:
			model.hide()
			
	for i in range(preplaced_cops.size()):
		var model = preplaced_cops[i]
		if i < cops.size():
			model.show()
			apply_versus_skin(model, cops[i])
			play_emote(model, "Idle")
			add_name_tag_to_model(model, get_display_name(cops[i]))
		else:
			model.hide()

func apply_versus_skin(model: Node3D, real_player: Node3D) -> void:
	var player_id := str(real_player.name).to_int()
	var role = real_player.get("team_index")

	if not GameManager.players.has(player_id):
		print("Versus skin: No GameManager data for player ", player_id)
		return

	if role == GameManager.PlayerRole.COP:
		var skin_index = GameManager.players[player_id].get("rhino_skin", 0)
		apply_rhino_versus_skin(model, skin_index)
	else:
		var skin_index = GameManager.players[player_id].get("chameleon_skin", 0)
		apply_chameleon_versus_skin(model, skin_index)


func apply_chameleon_versus_skin(model: Node3D, skin_index: int) -> void:
	if chameleon_skin_materials.is_empty():
		print("Versus skin: No chameleon materials assigned.")
		return

	skin_index = clampi(skin_index, 0, chameleon_skin_materials.size() - 1)
	var selected_material := chameleon_skin_materials[skin_index].duplicate()

	var mesh := model.find_child("Chameleon", true, false) as MeshInstance3D

	if mesh:
		mesh.set_surface_override_material(0, selected_material)
		print("Applied versus chameleon skin: ", skin_index)
	else:
		print("Versus skin: Could not find Chameleon mesh on ", model.name)


func apply_rhino_versus_skin(model: Node3D, skin_index: int) -> void:
	if rhino_skin_materials.is_empty():
		print("Versus skin: No rhino materials assigned.")
		return

	skin_index = clampi(skin_index, 0, rhino_skin_materials.size() - 1)
	var selected_material := rhino_skin_materials[skin_index].duplicate()

	var body := model.find_child("Rhino_Body", true, false) as MeshInstance3D
	var head := model.find_child("Rhino_Head", true, false) as MeshInstance3D

	if body:
		body.material_override = selected_material
		print("Applied versus rhino body skin: ", skin_index)
	else:
		print("Versus skin: Could not find Rhino_Body on ", model.name)

	if head:
		head.material_override = selected_material
		print("Applied versus rhino head skin: ", skin_index)

func play_versus_taunts():
	var preplaced_thieves = get_dummies(right_spawn)
	for model in preplaced_thieves:
		if model.visible:
			var anim = thief_versus_anims.pick_random() if thief_versus_anims.size() > 0 else ""
			if anim != "":
				play_emote_with_return(model, anim, "Idle1")
				
	var preplaced_cops = get_dummies(left_spawn)
	for model in preplaced_cops:
		if model.visible:
			var anim = cop_versus_anims.pick_random() if cop_versus_anims.size() > 0 else ""
			if anim != "":
				play_emote_with_return(model, anim, "Idle")

func play_emote_with_return(model: Node3D, anim_name: String, return_anim: String):
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim:
		if anim.has_animation(anim_name):
			anim.play(anim_name, anim_blend_in_time)
			# Once the taunt finishes, smoothly crossfade back into the idle animation!
			anim.animation_finished.connect(func(finished_anim_name): anim.play(return_anim, anim_blend_out_time), CONNECT_ONE_SHOT)

	# We no longer apply manual rotation offsets here because the user
	# sets the rotations natively in the editor using the Dummy scenes!

func add_name_tag_to_model(model: Node3D, text: String):
	# The Label3D is now built directly into the Thief/Cop scenes so the user can preview and edit it visually!
	var label = model.get_node_or_null("NameTag")
	if label and label is Label3D:
		label.text = text

func play_emote(model: Node3D, anim_name: String):
	var anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		if anim.has_animation(anim_name):
			anim.play(anim_name)
		elif anim.has_animation("Emote"):
			anim.play("Emote")
		elif anim.has_animation("Idle1"):
			anim.play("Idle1")
		elif anim.has_animation("Idle"):
			anim.play("Idle")


	# We intentionally leave model.scale at Vector3.ONE so we don't mess up perfectly scaled player scenes!

# ---------------------------------------------------------
# CAMERA TWEENS
# ---------------------------------------------------------
func play_cinematic_clip(start_marker: Marker3D, end_marker: Marker3D, duration: float):
	intro_camera.global_transform = start_marker.global_transform
	
	# Fade in at start of clip
	cutscene_ui.fade_in(museum_fade_in_time)
	
	var tween = create_tween()
	tween.tween_property(intro_camera, "global_transform", end_marker.global_transform, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var start_fov = 75.0
	var end_fov = 85.0
	
	var start_cam = start_marker.find_child("Camera3D", true, false)
	if start_cam:
		start_fov = start_cam.fov
		
	var end_cam = end_marker.find_child("Camera3D", true, false)
	if end_cam:
		end_fov = end_cam.fov
	elif start_cam:
		end_fov = start_cam.fov # If only start cam exists, don't zoom
	
	intro_camera.fov = start_fov
	tween.parallel().tween_property(intro_camera, "fov", end_fov, duration).set_trans(Tween.TRANS_SINE)
	
	await tween.finished

func fly_camera_to_target(target_cam: Camera3D):
	if target_cam == null: return
	
	var tween = create_tween()
	tween.tween_property(intro_camera, "global_transform", target_cam.global_transform, fly_to_player_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(intro_camera, "fov", target_cam.fov, fly_to_player_time).set_trans(Tween.TRANS_CUBIC)
	
	# To prevent clipping into the inside of the Cop's head (which has an outline shader),
	# we sync the intro_camera's cull_mask to the player's camera right before it reaches the head.
	get_tree().create_timer(fly_to_player_time * cop_head_hide_threshold).timeout.connect(func():
		if is_instance_valid(intro_camera) and is_instance_valid(target_cam):
			intro_camera.cull_mask = target_cam.cull_mask
	)
	
	await tween.finished

func get_player_gameplay_camera(player: Node3D) -> Camera3D:
	return player.get_node("PitchPivot/SpringArm3D/Camera3D")

func finish_cutscene_immediately():
	var target_cam = get_player_gameplay_camera(local_player)
	if target_cam:
		target_cam.current = true
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)
		
	AudioManager.play_music("base_tension", 0.1)
	GameManager.start_game_clock()
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("fade_in"):
		hud.fade_in(0.0)
		
	get_tree().call_group("dotted_rings", "show_immediately")
		
	cutscene_ui.visible = false

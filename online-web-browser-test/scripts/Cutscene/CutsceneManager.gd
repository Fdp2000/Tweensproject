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

@onready var intro_camera: Camera3D = $Node3D/IntroCamera
@onready var cutscene_ui: CutsceneUI = $"../VersusScreen"
@onready var cutscene_markers: Node3D = $CutsceneMarkers

# Markers
@onready var versus_pos: Marker3D = $CutsceneMarkers/VersusPos
@onready var left_spawn: Marker3D = $CutsceneMarkers/VersusPos/LeftSpawn
@onready var right_spawn: Marker3D = $CutsceneMarkers/VersusPos/RightSpawn

var local_player: Node3D
var spawned_dummy_models: Array[Node] = []

func _ready():
	intro_camera.current = true
	var game_manager = get_tree().get_root().find_child("GameManager", true, false)
	if game_manager:
		game_manager.game_started.connect(_on_game_started)

func _on_game_started():
	# INSTANTLY black out the screen to prevent frame lag of the player camera
	cutscene_ui.background.modulate.a = 1.0
	cutscene_ui.visible = true
	
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
	var lobby_camera = get_tree().get_root().find_child("LobbyCamera", true, false)
	if lobby_camera:
		lobby_camera.current = false
		
	intro_camera.current = true
	
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
	await cutscene_ui.fade_in(1.0)
	
	await get_tree().create_timer(0.10).timeout
	
	# Trigger the randomized taunts now that the screen is visible!
	play_versus_taunts()
	
	# 4. Wait for versus duration
	await get_tree().create_timer(versus_duration).timeout
	
	# 5. Fade to black to transition to Museum Pans
	await cutscene_ui.fade_to_black(1.0)
	
	# Free the dummies from memory entirely so they don't photobomb the background!
	for model in get_dummies(right_spawn): model.queue_free()
	for model in get_dummies(left_spawn): model.queue_free()
	
	var vs_label = cutscene_ui.get_node_or_null("Root/VSLabel")
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
		
	if local_player.get("charge_ui_ref"):
		var fade_tween = create_tween()
		fade_tween.tween_property(local_player.charge_ui_ref, "modulate:a", 1.0, 3.0)
		
	await cutscene_ui.play_countdown()
	
	# 10. Enable controls and start game clock!
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)
		
	GameManager.start_game_clock()
		
	queue_free()
	cutscene_ui.queue_free()

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
			play_emote(model, "Idle1") # Start in idle during the fade-in!
			add_name_tag_to_model(model, get_display_name(robbers[i]))
		else:
			model.hide()
			
	for i in range(preplaced_cops.size()):
		var model = preplaced_cops[i]
		if i < cops.size():
			model.show()
			play_emote(model, "Idle") # Start in idle during the fade-in!
			add_name_tag_to_model(model, get_display_name(cops[i]))
		else:
			model.hide()

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
			anim.play(anim_name, 0.2)
			# Once the taunt finishes, smoothly crossfade back into the idle animation!
			anim.animation_finished.connect(func(finished_anim_name): anim.play(return_anim, 0.5), CONNECT_ONE_SHOT)

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
	cutscene_ui.fade_in(0.5)
	
	var tween = create_tween()
	tween.tween_property(intro_camera, "global_transform", end_marker.global_transform, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Subtle FOV dolly zoom
	intro_camera.fov = 75.0
	tween.parallel().tween_property(intro_camera, "fov", 85.0, duration).set_trans(Tween.TRANS_SINE)
	
	await tween.finished

func fly_camera_to_target(target_cam: Camera3D):
	if target_cam == null: return
	
	var tween = create_tween()
	tween.tween_property(intro_camera, "global_transform", target_cam.global_transform, fly_to_player_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(intro_camera, "fov", target_cam.fov, fly_to_player_time).set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished

func get_player_gameplay_camera(player: Node3D) -> Camera3D:
	return player.get_node("PitchPivot/SpringArm3D/Camera3D")

func finish_cutscene_immediately():
	var target_cam = get_player_gameplay_camera(local_player)
	if target_cam:
		target_cam.current = true
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)
		
	GameManager.start_game_clock()
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("fade_in"):
		hud.fade_in(0.0)
		
	queue_free()
	cutscene_ui.queue_free()

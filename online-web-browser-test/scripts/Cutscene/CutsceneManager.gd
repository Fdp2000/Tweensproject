extends Node3D

@export var skip_cutscene: bool = false # <-- ADDED: Toggle this in the editor!

@onready var intro_camera: Camera3D = $Node3D/IntroCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var versus_screen: CanvasLayer = $"../VersusScreen"
@export var versus_duration: float = 6.0
@export var fly_to_player_time: float = 2.0
@export var local_player: Node3D

var target_camera: Camera3D
var intro_running: bool = false


func _ready():
	intro_camera.current = true
	var game_manager = get_tree().get_root().find_child("GameManager", true, false)

	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		print("CutsceneManager connected to GameManager.")
	else:
		push_error("Could not find GameManager.")



func _on_game_started():
	await get_tree().create_timer(0.3).timeout

	local_player = await wait_for_local_player()

	if local_player == null:
		push_error("No local player found before versus screen.")
		intro_running = false
		return

	# ==========================================
	# --- SKIP CUTSCENE LOGIC ---
	# ==========================================
	if skip_cutscene:
		print("[DEV] Skipping intro cutscene...")
		
		# Turn off lobby camera
		var lobby_camera = get_tree().get_root().find_child("LobbyCamera", true, false)
		if lobby_camera:
			lobby_camera.current = false
			
		# Give player immediate control and camera
		target_camera = get_player_gameplay_camera(local_player)
		if target_camera:
			target_camera.current = true
			
		if local_player.has_method("enable_controls"):
			local_player.enable_controls(true)
			
		intro_running = false
		return
	# ==========================================

	intro_running = true
	intro_camera.current = true

	target_camera = get_player_gameplay_camera(local_player)
	if target_camera:
		target_camera.current = false

	if local_player.has_method("enable_controls"):
		local_player.enable_controls(false)

	if versus_screen:
		var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
		if spawned:
			versus_screen.show_from_spawned(spawned)
			await get_tree().create_timer(versus_duration).timeout
			versus_screen.hide_matchup()

	start_intro()

func wait_for_local_player() -> Node3D:
	var attempts := 0

	while attempts < 60:
		var player = find_local_player()

		if player != null:
			return player

		attempts += 1
		await get_tree().process_frame

	return null

func start_intro():
	# intro_running is already true from _on_game_started()

	# Turn off lobby camera immediately
	var lobby_camera = get_tree().get_root().find_child("LobbyCamera", true, false)
	if lobby_camera:
		lobby_camera.current = false

	# Make intro camera active as early as possible
	intro_camera.current = true

	local_player = find_local_player()

	if local_player == null:
		push_error("No local player found.")
		intro_running = false
		return

	# Disable player gameplay camera during intro
	target_camera = get_player_gameplay_camera(local_player)
	if target_camera:
		target_camera.current = false

	if local_player.has_method("enable_controls"):
		local_player.enable_controls(false)

	animation_player.play("museum_pan")

	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func find_enemy_player(my_player: Node3D) -> Node3D:
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)

	if spawned == null or my_player == null:
		return null

	for player in spawned.get_children():
		if player != my_player:
			return player

	return null

func find_local_player() -> Node3D:
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)

	if spawned == null:
		push_error("Could not find SpawnedObjects.")
		return null

	var my_id := multiplayer.get_unique_id()

	for player in spawned.get_children():
		if str(player.name) == str(my_id):
			return player

	return null


func _on_animation_finished(anim_name: StringName):
	if anim_name == "museum_pan":
		start_fly_to_player()


func start_fly_to_player():
	target_camera = get_player_gameplay_camera(local_player)

	if target_camera == null:
		push_error("No target camera found.")
		intro_running = false
		return

	await move_intro_camera_to_target(target_camera)

	target_camera.current = true

	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)

	intro_running = false

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
	
	await tween.finished

func get_player_gameplay_camera(player: Node3D) -> Camera3D:
	return player.get_node("PitchPivot/SpringArm3D/Camera3D")


func move_intro_camera_to_target(cam: Camera3D):
	var start_transform := intro_camera.global_transform
	var end_transform := cam.global_transform

	var timer := 0.0

	while timer < fly_to_player_time:
		timer += get_process_delta_time()

		var t := timer / fly_to_player_time
		t = clamp(t, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)

		intro_camera.global_transform = start_transform.interpolate_with(end_transform, t)

		await get_tree().process_frame

	intro_camera.global_transform = end_transform

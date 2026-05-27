extends Node3D

@export var skip_cutscene: bool = false

@export var thief_preview_scene: PackedScene = preload("res://Assets/Models/Chameleon/chameleon.tscn")
@export var thief_rotation_offset_degrees: float = -90.0
@export var cop_preview_scene: PackedScene = preload("res://Assets/Models/Chameleon/chameleon.tscn")
@export var cop_rotation_offset_degrees: float = -90.0
@export var versus_duration: float = 6.0
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
	setup_versus_lineup()
	
	# 3. Fade into Versus Screen
	await cutscene_ui.fade_in(1.0)
	
	# 4. Wait for versus duration
	await get_tree().create_timer(versus_duration).timeout
	
	# 5. Fade to black to transition to Museum Pans
	await cutscene_ui.fade_to_black(1.0)
	
	# Cleanup dummies
	for dummy in spawned_dummy_models:
		dummy.queue_free()
	spawned_dummy_models.clear()
	
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
	
	# 9. Play Countdown
	await cutscene_ui.play_countdown()
	
	# 10. Enable controls and cleanup!
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)
		
	queue_free()
	cutscene_ui.queue_free()

# ---------------------------------------------------------
# VERSUS LINEUP LOGIC
# ---------------------------------------------------------
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
			
	var spawned_thieves = []
	var spawned_cops = []
			
	for i in range(robbers.size()):
		var model = thief_preview_scene.instantiate()
		right_spawn.add_child(model) # Thieves on Right
		spawned_dummy_models.append(model)
		spawned_thieves.append(model)
		apply_lineup_transform(model, i, robbers.size(), false)
		play_emote(model)
		add_name_tag_to_model(model, get_display_name(robbers[i]))
		
	for i in range(cops.size()):
		var model = cop_preview_scene.instantiate()
		left_spawn.add_child(model) # Cops on Left
		spawned_dummy_models.append(model)
		spawned_cops.append(model)
		apply_lineup_transform(model, i, cops.size(), true)
		play_emote(model)
		add_name_tag_to_model(model, get_display_name(cops[i]))

	# Apply manual rotation offsets (no look_at logic)
	for t_model in spawned_thieves:
		t_model.rotation.y = deg_to_rad(thief_rotation_offset_degrees)
		t_model.rotation.x = 0
		t_model.rotation.z = 0
			
	for c_model in spawned_cops:
		c_model.rotation.y = deg_to_rad(cop_rotation_offset_degrees)
		c_model.rotation.x = 0
		c_model.rotation.z = 0

func get_closest_node(source: Node3D, targets: Array) -> Node3D:
	var closest = null
	var min_dist = 999999.0
	for t in targets:
		var dist = source.global_position.distance_to(t.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = t
	return closest

func add_name_tag_to_model(model: Node3D, text: String):
	# The Label3D is now built directly into the Thief/Cop scenes so the user can preview and edit it visually!
	var label = model.get_node_or_null("NameTag")
	if label and label is Label3D:
		label.text = text

func play_emote(model: Node3D):
	var anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		if anim.has_animation("emote"):
			anim.play("emote")
		elif anim.has_animation("Idle1"):
			anim.play("Idle1")

func apply_lineup_transform(model: Node3D, index: int, total: int, is_cop: bool):
	var parent = left_spawn if is_cop else right_spawn
	
	# Try to find a manual WYSIWYG marker in World.tscn first!
	var marker_name = ("CopPreviewPos" if is_cop else "ThiefPreviewPos") + str(index)
	var manual_marker = parent.get_node_or_null(marker_name)
	
	if manual_marker and manual_marker is Marker3D:
		model.position = manual_marker.position
		return
		
	# Fallback math if the user deletes a marker
	var side := -1.0 if is_cop else 1.0
	var x := 0.0
	var z := 0.0

	match total:
		1: x = side * 1.5
		2: x = side * (1.0 + index * 1.5)
		3: x = side * (0.8 + index * 1.2)
		4: x = side * (0.6 + index * 1.0)
		_:
			# 5+ models (e.g. 7 thieves) arranged in a spacious 2-row grid
			var row := int(index / 4) # Max 4 per row
			var col := index % 4
			x = side * (0.8 + col * 1.2)
			z = row * -1.5

	model.position = Vector3(x, 0, z)
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
	queue_free()
	cutscene_ui.queue_free()

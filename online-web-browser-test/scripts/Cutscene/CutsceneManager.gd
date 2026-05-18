extends Node3D

@onready var intro_camera: Camera3D = $Node3D/IntroCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var fly_to_player_time: float = 2.0
@export var local_player: Node3D

var target_camera: Camera3D
var intro_running: bool = false


func _ready():
	var game_manager = get_tree().get_root().find_child("GameManager", true, false)

	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		print("CutsceneManager connected to GameManager.")
	else:
		push_error("Could not find GameManager.")


# Temporary test input
func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		start_intro()


func _on_game_started():
	start_intro()


func start_intro():

	if intro_running:
		return

	intro_running = true

	if local_player == null:
		local_player = find_local_player()

	if local_player == null:
		push_error("No local player found.")
		intro_running = false
		return

	if local_player.has_method("enable_controls"):
		local_player.enable_controls(false)

	intro_camera.current = true
	animation_player.play("museum_pan")

	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func find_local_player() -> Node3D:
	var spawned = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects")

	if spawned == null:
		push_error("Could not find World/main/SpawnedObjects.")
		return null

	for player in spawned.get_children():
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
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


func get_player_gameplay_camera(player: Node3D) -> Camera3D:

	var team_index = player.get("team_index")

	if team_index == 1:
		return player.get_node("Head/FirstPersonCamera")

	if team_index == 0:
		return player.get_node("CameraPivot/ThirdPersonCamera")

	# Fallback for your temporary test player
	if player.get("team") == "Guard":
		return player.get_node("Head/FirstPersonCamera")

	if player.get("team") == "Thief":
		return player.get_node("CameraPivot/ThirdPersonCamera")

	return null


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

extends Node3D

@onready var intro_camera: Camera3D = $Node3D/IntroCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var fly_to_player_time: float = 2.0
@export var local_player: Node3D

var target_camera: Camera3D


func _ready():
	start_intro()


func start_intro():

	if local_player == null:
		push_error("No local player assigned.")
		return

	# Disable controls
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(false)

	# Use intro camera
	intro_camera.current = true

	# Play museum pan animation
	animation_player.play("museum_pan")

	# Connect animation finished signal
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: StringName):

	if anim_name == "museum_pan":
		start_fly_to_player()


func start_fly_to_player():

	target_camera = get_player_gameplay_camera(local_player)

	if target_camera == null:
		push_error("No target camera found.")
		return

	await move_intro_camera_to_target(target_camera)

	# Switch to gameplay camera
	target_camera.current = true

	# Re-enable controls
	if local_player.has_method("enable_controls"):
		local_player.enable_controls(true)


func get_player_gameplay_camera(player: Node3D) -> Camera3D:

	if player.team == "Guard":
		return player.get_node("Head/FirstPersonCamera")

	if player.team == "Thief":
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

		# Smooth ease
		t = t * t * (3.0 - 2.0 * t)

		intro_camera.global_transform = start_transform.interpolate_with(end_transform, t)

		await get_tree().process_frame

	intro_camera.global_transform = end_transform

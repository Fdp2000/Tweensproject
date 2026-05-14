extends CharacterBody3D

@export var team: String = "Thief"

var controls_enabled := true

func enable_controls(value: bool):
	controls_enabled = value


func _physics_process(delta):

	if !controls_enabled:
		return

	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		input_dir.z -= 1

	if Input.is_action_pressed("ui_down"):
		input_dir.z += 1

	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1

	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1

	velocity.x = input_dir.x * 5.0
	velocity.z = input_dir.z * 5.0

	move_and_slide()

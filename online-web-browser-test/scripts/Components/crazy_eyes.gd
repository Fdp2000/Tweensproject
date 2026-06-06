extends Node

@export var left_eye_pivot: Node3D
@export var right_eye_pivot: Node3D

@export_group("Eye Timing")
@export var min_interval: float = 0.2
@export var max_interval: float = 1.5
@export var rotation_speed: float = 15.0

@export_group("Eye Movement Limits")
# How crazy the eyes can look (in degrees)
@export var pitch_limit: float = 45.0 # Up/Down
@export var yaw_limit: float = 60.0 # Left/Right
@export var roll_limit: float = 20.0 # Tilt

var target_rot_l: Vector3
var target_rot_r: Vector3
var timer_l: float = 0.0
var timer_r: float = 0.0

func _ready():
	_pick_new_rotation_l()
	_pick_new_rotation_r()

func _process(delta):
	if not left_eye_pivot or not right_eye_pivot:
		return
		
	# Left Eye Timer
	timer_l -= delta
	if timer_l <= 0:
		_pick_new_rotation_l()
		
	# Right Eye Timer
	timer_r -= delta
	if timer_r <= 0:
		_pick_new_rotation_r()
		
	# Smoothly rotate the pivots towards the random targets using Slerp
	var q_l = Quaternion.from_euler(target_rot_l)
	var q_r = Quaternion.from_euler(target_rot_r)
	
	left_eye_pivot.quaternion = left_eye_pivot.quaternion.slerp(q_l, delta * rotation_speed)
	right_eye_pivot.quaternion = right_eye_pivot.quaternion.slerp(q_r, delta * rotation_speed)

func _pick_new_rotation_l():
	target_rot_l = Vector3(
		deg_to_rad(randf_range(-pitch_limit, pitch_limit)),
		deg_to_rad(randf_range(-yaw_limit, yaw_limit)),
		deg_to_rad(randf_range(-roll_limit, roll_limit))
	)
	timer_l = randf_range(min_interval, max_interval)

func _pick_new_rotation_r():
	target_rot_r = Vector3(
		deg_to_rad(randf_range(-pitch_limit, pitch_limit)),
		deg_to_rad(randf_range(-yaw_limit, yaw_limit)),
		deg_to_rad(randf_range(-roll_limit, roll_limit))
	)
	timer_r = randf_range(min_interval, max_interval)

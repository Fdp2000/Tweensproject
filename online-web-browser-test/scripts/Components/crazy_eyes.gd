@tool
extends Node

@export var left_eye_pivot: Node3D
@export var right_eye_pivot: Node3D

@export_group("Editor Preview")
## Turn this on to see the random eye movement running live in the editor!
@export var preview_random_movement: bool = false:
	set(value):
		preview_random_movement = value
		if value: 
			enable_limit_testing = false

## Turn this on to freeze the eyes and manually test the limits with the sliders below.
@export var enable_limit_testing: bool = false:
	set(value):
		enable_limit_testing = value
		if value: 
			preview_random_movement = false
		_update_test_limits()

## Slide to test up/down limits (-1.0 is max down, 1.0 is max up)
@export_range(-1.0, 1.0) var test_pitch_percent: float = 0.0:
	set(value):
		test_pitch_percent = value
		_update_test_limits()

## Slide to test left/right limits (-1.0 is max left, 1.0 is max right)
@export_range(-1.0, 1.0) var test_yaw_percent: float = 0.0:
	set(value):
		test_yaw_percent = value
		_update_test_limits()

## Slide to test tilt limits (-1.0 is max tilt left, 1.0 is max tilt right)
@export_range(-1.0, 1.0) var test_roll_percent: float = 0.0:
	set(value):
		test_roll_percent = value
		_update_test_limits()

@export_group("Eye Timing")
@export var min_interval: float = 0.2
@export var max_interval: float = 1.5
## Forces the eyes to never move at the exact same time. Ensures at least this many seconds between movements.
@export var offset_gap: float = 0.4
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
	if not Engine.is_editor_hint():
		_pick_new_rotation_l()
		_pick_new_rotation_r()
		# On startup, ensure they don't move exactly together initially
		timer_r += offset_gap

func _update_test_limits():
	if Engine.is_editor_hint():
		if enable_limit_testing and left_eye_pivot and right_eye_pivot:
			var pitch = deg_to_rad(pitch_limit * test_pitch_percent)
			var yaw = deg_to_rad(yaw_limit * test_yaw_percent)
			var roll = deg_to_rad(roll_limit * test_roll_percent)
			
			var target_q = Quaternion.from_euler(Vector3(pitch, yaw, roll))
			left_eye_pivot.quaternion = target_q
			right_eye_pivot.quaternion = target_q
		elif not enable_limit_testing and not preview_random_movement:
			if left_eye_pivot: left_eye_pivot.quaternion = Quaternion.IDENTITY
			if right_eye_pivot: right_eye_pivot.quaternion = Quaternion.IDENTITY

func _process(delta):
	if not left_eye_pivot or not right_eye_pivot:
		return
		
	if Engine.is_editor_hint():
		if not preview_random_movement:
			return # Stop _process from running in the editor if preview is off
		
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
	# If this new time is too close to the right eye's upcoming movement, push it back
	if abs(timer_l - timer_r) < offset_gap:
		timer_l += offset_gap

func _pick_new_rotation_r():
	target_rot_r = Vector3(
		deg_to_rad(randf_range(-pitch_limit, pitch_limit)),
		deg_to_rad(randf_range(-yaw_limit, yaw_limit)),
		deg_to_rad(randf_range(-roll_limit, roll_limit))
	)
	timer_r = randf_range(min_interval, max_interval)
	# If this new time is too close to the left eye's upcoming movement, push it back
	if abs(timer_r - timer_l) < offset_gap:
		timer_r += offset_gap

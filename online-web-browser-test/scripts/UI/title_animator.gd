extends Node

@export var scale_multiplier: float = 1.05
@export var rotation_wobble_degrees: float = 2.0
@export var animation_duration: float = 2.5

var _base_scale
var _base_rotation

func _ready() -> void:
	# Ensure the parent is ready and we can read its transform
	call_deferred("_start_animation")

func _start_animation() -> void:
	var target = get_parent()
	
	if target is Node3D:
		_base_scale = target.scale
		_base_rotation = target.rotation
		_animate_3d(target)
	elif target is Control:
		_base_scale = target.scale
		_base_rotation = target.rotation
		
		# Set pivot to center so it scales/rotates from the middle!
		target.pivot_offset = target.size / 2.0
		
		_animate_2d(target)
	elif target is Node2D:
		_base_scale = target.scale
		_base_rotation = target.rotation
		_animate_2d(target)
	else:
		printerr("TitleAnimator: Parent must be a Node3D, Control, or Node2D!")

func _animate_3d(target: Node3D) -> void:
	var scale_tween = create_tween().set_loops()
	
	# Smooth, breathing pulse effect
	scale_tween.tween_property(
		target, 
		"scale", 
		_base_scale * scale_multiplier, 
		animation_duration / 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	scale_tween.tween_property(
		target, 
		"scale", 
		_base_scale, 
		animation_duration / 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Subtle floating rotation wobble
	var rot_tween = create_tween().set_loops()
	rot_tween.tween_property(target, "rotation:z", _base_rotation.z + deg_to_rad(rotation_wobble_degrees), animation_duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(target, "rotation:z", _base_rotation.z - deg_to_rad(rotation_wobble_degrees), animation_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(target, "rotation:z", _base_rotation.z, animation_duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _animate_2d(target: Node) -> void:
	var scale_tween = create_tween().set_loops()
	
	# Smooth, breathing pulse effect
	scale_tween.tween_property(
		target, 
		"scale", 
		_base_scale * scale_multiplier, 
		animation_duration / 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	scale_tween.tween_property(
		target, 
		"scale", 
		_base_scale, 
		animation_duration / 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Subtle floating rotation wobble
	var rot_tween = create_tween().set_loops()
	rot_tween.tween_property(target, "rotation", _base_rotation + deg_to_rad(rotation_wobble_degrees), animation_duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(target, "rotation", _base_rotation - deg_to_rad(rotation_wobble_degrees), animation_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(target, "rotation", _base_rotation, animation_duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

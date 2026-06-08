extends Sprite3D

@export var max_shadow_distance: float = 10.0

var raycast: RayCast3D

func _ready() -> void:
	# Detach the shadow's rotation and position from the player
	# This ensures the shadow doesn't rotate when the player turns
	top_level = true
	
	# Create a RayCast dynamically to find the floor
	raycast = RayCast3D.new()
	add_child(raycast)
	raycast.target_position = Vector3(0, -max_shadow_distance, 0)
	
	# The raycast also needs to be detached so it always points strictly downwards
	raycast.top_level = true
	
	# Ignore the player's own collider so the shadow doesn't cast on the player's head
	var parent = get_parent()
	if parent is CollisionObject3D:
		raycast.add_exception(parent)

func _physics_process(_delta: float) -> void:
	var character_pos = get_parent().global_position
	
	# Move the raycast directly to the character's center
	raycast.global_position = character_pos
	
	if raycast.is_colliding():
		show()
		var hit_point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		
		# Place shadow on the floor, bumped up slightly along the normal to prevent flickering (Z-fighting)
		global_position = hit_point + (normal * 0.05)
		
		# Align the shadow perfectly with the slope's angle
		if not normal.is_equal_approx(Vector3.UP) and not normal.is_equal_approx(Vector3.DOWN):
			var x_axis = Vector3.UP.cross(normal).normalized()
			var z_axis = x_axis.cross(normal).normalized()
			global_transform.basis = Basis(x_axis, normal, z_axis)
		else:
			global_transform.basis = Basis.IDENTITY
			
		# Optional Polish: Fade the shadow out the higher the character jumps
		var dist = character_pos.distance_to(hit_point)
		modulate.a = clamp(1.0 - (dist / max_shadow_distance), 0.0, 1.0)
	else:
		hide()

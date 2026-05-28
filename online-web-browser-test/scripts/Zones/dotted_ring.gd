extends Node3D
class_name DottedRing

@export var radius: float = 4.0:
	set(val):
		radius = val
		if is_inside_tree(): _update_dots()

@export var dot_count: int = 32:
	set(val):
		dot_count = val
		if is_inside_tree(): _update_dots()

@export var dot_color: Color = Color(1, 1, 1, 0.5):
	set(val):
		dot_color = val
		if _material:
			_material.albedo_color = dot_color

@export var dot_size: float = 0.15:
	set(val):
		dot_size = val
		if is_inside_tree(): _update_dots()

var multimesh_instance: MultiMeshInstance3D
var _material: StandardMaterial3D
var _current_rotation: float = 0.0

func _ready():
	multimesh_instance = MultiMeshInstance3D.new()
	add_child(multimesh_instance)
	
	var mesh = SphereMesh.new()
	mesh.radius = dot_size / 2.0
	mesh.height = dot_size
	
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = dot_color
	
	multimesh_instance.material_override = _material
	multimesh_instance.multimesh = MultiMesh.new()
	multimesh_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh_instance.multimesh.mesh = mesh
	multimesh_instance.multimesh.instance_count = dot_count

	# Calculate positions once on startup
	call_deferred("_update_dots")

func _update_dots():
	if not visible or dot_count == 0: return
	
	multimesh_instance.multimesh.instance_count = dot_count
	var space_state = get_world_3d().direct_space_state
	
	for i in range(dot_count):
		var angle = (float(i) / dot_count) * TAU
		var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		
		# Start raycast high above the center point
		var start_pos = global_position + offset + Vector3(0, 10, 0)
		var end_pos = global_position + offset - Vector3(0, 10, 0)
		
		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.collision_mask = 1 # Only hit world geometry (Layer 1)
		
		var result = space_state.intersect_ray(query)
		
		var final_pos = global_position + offset
		if result:
			# Place slightly above the hit point along the normal
			final_pos = result.position + result.normal * 0.05
			
		# Convert to local position for the multimesh
		var local_pos = to_local(final_pos)
		var t = Transform3D(Basis(), local_pos)
		multimesh_instance.multimesh.set_instance_transform(i, t)

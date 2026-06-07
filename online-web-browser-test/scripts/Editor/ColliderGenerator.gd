@tool
extends EditorScript

const EXCLUSION_NODE_NAME = "KEEP"

func _run() -> void:
	var scene_root: Node = get_scene()
	
	if not scene_root:
		printerr("Collider Generator: No scene is currently open!")
		return
		
	print("Collider Generator: Starting BoxShape processing on scene '", scene_root.name, "'...")
	_process_node_recursive(scene_root, false)
	print("Collider Generator: Finished processing!")


func _process_node_recursive(current_node: Node, is_ancestor_kept: bool) -> void:
	var should_ignore: bool = is_ancestor_kept or current_node.name == EXCLUSION_NODE_NAME
	
	if not should_ignore and current_node is MeshInstance3D:
		_ensure_collider_exists(current_node)
		
	for child in current_node.get_children():
		_process_node_recursive(child, should_ignore)


func _ensure_collider_exists(mesh_instance: MeshInstance3D) -> void:
	# 1. Skip if it already has a collider
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			return 
			
	# 2. Skip if the MeshInstance doesn't actually have a mesh resource assigned
	if not mesh_instance.mesh:
		return
		
	# 3. Get the AABB (Axis-Aligned Bounding Box) in local space
	var aabb: AABB = mesh_instance.get_aabb()
	
	# 4. Create the necessary nodes
	var static_body := StaticBody3D.new()
	var coll_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	
	# 5. Configure the BoxShape size and position
	box_shape.size = aabb.size
	coll_shape.shape = box_shape
	
	# The AABB might not be perfectly centered at 0,0,0, so we must offset the collision shape
	coll_shape.position = aabb.get_center()
	
	# 6. Build the hierarchy
	static_body.add_child(coll_shape)
	mesh_instance.add_child(static_body)
	
	# 7. Set the owners so they serialize correctly in the .tscn file
	var scene_root: Node = get_scene()
	static_body.owner = scene_root
	coll_shape.owner = scene_root

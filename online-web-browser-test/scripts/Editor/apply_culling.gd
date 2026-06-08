@tool
extends EditorScript

# How far away (in meters) before objects disappear
const CULL_DISTANCE = 75.0 
# Max size (in meters) of an object to be considered for culling. 
# We don't want giant floors or walls to vanish!
const MAX_AABB_SIZE = 5.0 

func _run():
	var root = get_scene()
	if not root:
		print("Please open the PrototypeLevel.tscn scene first!")
		return
		
	var culled_count = 0
	culled_count = _apply_culling_recursive(root, culled_count)
	
	print("Done! Applied Max Range Culling to ", culled_count, " small objects.")

func _apply_culling_recursive(node: Node, count: int) -> int:
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var aabb: AABB
		
		if node is MeshInstance3D and node.mesh:
			aabb = node.mesh.get_aabb()
		elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
			aabb = node.multimesh.mesh.get_aabb()
			
		if aabb:
			var max_size = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
			
			# Only apply culling to small/medium props!
			if max_size <= MAX_AABB_SIZE:
				# Apply distance culling (End margin adds a nice fade-out effect)
				node.visibility_range_end = CULL_DISTANCE
				node.visibility_range_end_margin = 2.0
				count += 1
			
	for child in node.get_children():
		count = _apply_culling_recursive(child, count)
		
	return count

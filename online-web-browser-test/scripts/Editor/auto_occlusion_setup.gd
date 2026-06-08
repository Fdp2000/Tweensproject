@tool
extends EditorScript

# 1. MIN_AABB_SIZE: Minimum size in meters. If a mesh is smaller than this, it's too small to block vision.
const MIN_AABB_SIZE = 4.0 

# 2. MAX_VERTICES: If a mesh has more triangles than this, it's too complex and will lag the CPU culler.
const MAX_TRIANGLES = 500

func _run():
	var root = get_scene()
	if not root:
		print("Please open PrototypeLevel.tscn!")
		return
		
	var hidden_count = 0
	hidden_count = _process_node(root, hidden_count)
	
	print("--------------------------------------------------")
	print("✅ AUTO-OCCLUSION SETUP COMPLETE")
	print("Hid %d bad meshes (Too small or too detailed)!" % hidden_count)
	print("--------------------------------------------------")
	print("NEXT STEPS:")
	print("1. Select your OccluderInstance3D")
	print("2. Click 'Bake Occluders' at the top of the viewport")
	print("3. Run 'auto_occlusion_restore.gd' to unhide everything!")
	print("--------------------------------------------------")

func _process_node(node: Node, count: int) -> int:
	if node is MeshInstance3D and node.visible:
		if _should_hide(node.mesh):
			node.visible = false
			node.set_meta("auto_occlude_hidden", true)
			count += 1
			
	elif node is MultiMeshInstance3D and node.visible:
		if node.multimesh and _should_hide(node.multimesh.mesh):
			node.visible = false
			node.set_meta("auto_occlude_hidden", true)
			count += 1
			
	for child in node.get_children():
		count = _process_node(child, count)
		
	return count

func _should_hide(mesh: Mesh) -> bool:
	if not mesh: return true
	
	# Rule 1: Is it too small to block vision?
	var aabb = mesh.get_aabb()
	var max_size = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if max_size < MIN_AABB_SIZE:
		return true
		
	# Rule 2: Is it too complex for the CPU culler?
	var faces = mesh.get_faces()
	var triangle_count = faces.size() / 3
	if triangle_count > MAX_TRIANGLES:
		return true
		
	# It's large and low-poly! Perfect for baking!
	return false

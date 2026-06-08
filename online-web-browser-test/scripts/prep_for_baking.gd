@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("ERROR: Please open a scene first!")
		return
		
	var updated_count = 0
	
	var nodes_to_check = [root]
	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		if current is MeshInstance3D:
			# Set the Global Illumination Mode to Static!
			current.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			updated_count += 1
			
	print("=========================================")
	print("✅ SCENE PREPARED FOR BAKING ✅")
	print("=========================================")
	print("Successfully set GI Mode to 'Static' on ", updated_count, " meshes.")

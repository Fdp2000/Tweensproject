@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		return
		
	var restored_count = 0
	
	# 1. Delete all the messed up MultiMesh outputs
	for child in root.get_children():
		if "MultiMeshMerger_Output" in child.name:
			child.name = "DELETING_" + child.name
			child.queue_free()
			
	# 2. Make all original meshes visible again
	var nodes_to_check = [root]
	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		if current is MeshInstance3D and current.has_meta("merged_hidden"):
			current.visible = true
			current.remove_meta("merged_hidden")
			restored_count += 1
			
	print("✅ UNDO COMPLETE! Restored " + str(restored_count) + " meshes back to normal!")

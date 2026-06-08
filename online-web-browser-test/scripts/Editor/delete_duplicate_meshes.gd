@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("❌ Please open your scene (e.g. PrototypeLevel.tscn)!")
		return
		
	print("🔍 Scanning for overlapping duplicate meshes (Z-fighting)...")
	var deleted_count = 0
	
	# Dictionary mapping "mesh_id_material_id" -> Array of Global Transforms
	var seen_meshes = {}
	
	var nodes_to_check = [root]
	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		# Skip MultiMeshes, we only check raw meshes
		if "MultiMeshMerger" in current.name:
			continue
			
		if current is MeshInstance3D and current.mesh != null:
			var mat_key = ""
			for i in range(current.mesh.get_surface_count()):
				var mat = current.get_surface_override_material(i)
				if not mat: 
					mat = current.mesh.surface_get_material(i)
				if mat: 
					mat_key += str(mat.get_instance_id())
			
			var group_key = str(current.mesh.get_instance_id()) + "_" + mat_key
			var global_pos = current.global_position
			
			if not seen_meshes.has(group_key):
				seen_meshes[group_key] = []
				
			var is_duplicate = false
			for seen_pos in seen_meshes[group_key]:
				# If two identical meshes are within 1mm of each other...
				if seen_pos.distance_to(global_pos) < 0.001:
					is_duplicate = true
					break
					
			if is_duplicate:
				print("🙈 Z-FIGHTING FIX: Hiding exact duplicate mesh -> ", current.name, " at ", global_pos)
				current.visible = false
				current.name = "HIDDEN_DUPLICATE_" + current.name
				deleted_count += 1
			else:
				seen_meshes[group_key].append(global_pos)
				
	print("=========================================")
	print("✅ Z-FIGHTING DUPLICATE SCAN COMPLETE")
	print("Deleted %d perfect duplicates!" % deleted_count)
	print("=========================================")

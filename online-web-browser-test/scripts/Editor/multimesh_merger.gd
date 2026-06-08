@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("❌ ERROR: You must have a scene open in the editor (like PrototypeLevel.tscn)!")
		return
		
	print("🔍 Scanning scene for mergeable meshes...")
	
	# Dictionary to group meshes by their exact Mesh + Material combination
	var mesh_groups = {} 
	
	var nodes_to_check = [root]
	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		# Skip nodes that we already created so we don't infinitely merge!
		if "MultiMeshMerger" in current.name:
			continue
			
		# We only care about active MeshInstance3Ds that are NOT rigged/animated
		if current is MeshInstance3D and current.visible and current.mesh != null and current.skeleton.is_empty():
			
			# Build a unique signature for this exact Mesh + Material combo
			var mat_key = ""
			for i in range(current.mesh.get_surface_count()):
				var mat = current.get_surface_override_material(i)
				if not mat: 
					mat = current.mesh.surface_get_material(i)
				if mat: 
					# Use the material's unique memory ID as the key
					mat_key += str(mat.get_instance_id())
			
			var group_key = str(current.mesh.get_instance_id()) + "_" + mat_key
			
			if not mesh_groups.has(group_key):
				mesh_groups[group_key] = {
					"mesh": current.mesh,
					"materials": [],
					"instances": []
				}
				# Store the materials so we can apply them to the MultiMesh
				for i in range(current.mesh.get_surface_count()):
					var mat = current.get_surface_override_material(i)
					if not mat: 
						mat = current.mesh.surface_get_material(i)
					mesh_groups[group_key]["materials"].append(mat)
					
			mesh_groups[group_key]["instances"].append(current)

	# Now compress them into MultiMeshes
	var merged_count = 0
	var original_count = 0
	
	var multimesh_root = Node3D.new()
	multimesh_root.name = "MultiMeshMerger_Output_" + str(Time.get_ticks_msec())
	root.add_child(multimesh_root)
	multimesh_root.owner = root
	
	for key in mesh_groups:
		var group = mesh_groups[key]
		var instances = group["instances"]
		
		# Only merge if there are at least 5 of the exact same object
		# (Merging 2 objects isn't worth the overhead)
		if instances.size() < 5: 
			continue
		
		var mm_instance = MultiMeshInstance3D.new()
		mm_instance.name = "MergedBatch_" + str(merged_count) + "_" + str(instances.size()) + "Items"
		
		var mmesh = MultiMesh.new()
		mmesh.transform_format = MultiMesh.TRANSFORM_3D
		mmesh.instance_count = instances.size()
		mmesh.mesh = group["mesh"]
		mm_instance.multimesh = mmesh
		
		var base_mesh = group["mesh"]
		var surface_count = base_mesh.get_surface_count()
		
		# Apply the material!
		if surface_count == 1:
			# For single-surface meshes, material_override is completely safe and fast!
			if group["materials"].size() > 0 and group["materials"][0]:
				mm_instance.material_override = group["materials"][0]
			mmesh.mesh = base_mesh
		else:
			# MultiMeshInstance3D does not support overriding individual surfaces!
			# If we use material_override on a multi-surface mesh, it forces ALL surfaces to use the same material,
			# causing Z-fighting and broken visuals. Instead, we bake the materials directly into a duplicated Mesh!
			if base_mesh.has_method("surface_set_material"):
				var new_mesh = base_mesh.duplicate()
				for i in range(surface_count):
					if i < group["materials"].size() and group["materials"][i]:
						new_mesh.surface_set_material(i, group["materials"][i])
				mmesh.mesh = new_mesh
			else:
				print("⚠️ WARNING: Multi-surface mesh does not support surface_set_material: ", base_mesh)
				mmesh.mesh = base_mesh
		
		# We MUST add the MultiMesh to the tree FIRST so it calculates its true Global Transform!
		multimesh_root.add_child(mm_instance)
		mm_instance.owner = root
		
		# Now we convert the original's World Transform into a Local Transform relative to the MultiMesh
		var inv_transform = mm_instance.global_transform.affine_inverse()
		
		# Copy the transforms from the original objects into the MultiMesh
		for i in range(instances.size()):
			var original = instances[i]
			mmesh.set_instance_transform(i, inv_transform * original.global_transform)
			original_count += 1
			
			# INSTEAD of deleting the original (which breaks collisions and instanced scenes),
			# we simply make it invisible! 
			# An invisible MeshInstance costs 0 GPU draw calls, but preserves 100% of your physics/hierarchy!
			original.visible = false
			original.set_meta("merged_hidden", true)
			
		merged_count += 1
		
	print("=========================================")
	print("🚀 DRAW CALLS NUKED 🚀")
	print("=========================================")
	print("Individual Meshes hidden from GPU: ", original_count)
	print("MultiMeshes created to replace them: ", merged_count)
	print("Total Draw Calls Saved: ", original_count - merged_count)
	print("=========================================")

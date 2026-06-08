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
		
		# Apply the material!
		# Note: MultiMeshInstance3D does not support overriding individual surfaces. 
		# We apply the first valid material as a global override.
		for i in range(group["materials"].size()):
			if group["materials"][i]:
				mm_instance.material_override = group["materials"][i]
				break
		
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
			
		merged_count += 1
		
	print("=========================================")
	print("🚀 DRAW CALLS NUKED 🚀")
	print("=========================================")
	print("Individual Meshes hidden from GPU: ", original_count)
	print("MultiMeshes created to replace them: ", merged_count)
	print("Total Draw Calls Saved: ", original_count - merged_count)
	print("=========================================")

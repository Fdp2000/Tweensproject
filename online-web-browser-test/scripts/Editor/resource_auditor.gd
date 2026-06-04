@tool
extends EditorScript

## HOW TO RUN:
## 1. Have your Level open in the 2D/3D viewport!
## 2. Open this script in the Script editor.
## 3. Go to File -> Run (or press Ctrl+Shift+X)

func _run():
	var root = get_scene()
	if root == null:
		print("ERROR: Please open a scene first.")
		return
		
	var unique_meshes = {}
	var embedded_materials = []
	var mesh_instances_count = 0
	
	# Function to recursively scan nodes
	var scan_node = func(node: Node, self_ref: Callable):
		if node is MeshInstance3D:
			mesh_instances_count += 1
			
			# 1. Audit Meshes
			var m = node.mesh
			if m != null:
				var m_id = m.get_instance_id()
				if not unique_meshes.has(m_id):
					unique_meshes[m_id] = {"name": node.name, "path": m.resource_path, "count": 0}
				unique_meshes[m_id].count += 1
				
			# 2. Audit Materials
			var mats_to_check = []
			
			# Check Override
			if node.material_override != null:
				mats_to_check.append(node.material_override)
				
			# Check Surface Overrides & Mesh Materials
			if m != null:
				for i in range(m.get_surface_count()):
					var mat = node.get_surface_override_material(i)
					if mat == null:
						mat = m.surface_get_material(i)
					if mat != null:
						mats_to_check.append(mat)
						
			for mat in mats_to_check:
				var path = mat.resource_path
				# If path is empty, or contains "::" (which indicates a sub-resource in Godot 4)
				if path.is_empty() or "::" in path:
					if not embedded_materials.has(mat):
						embedded_materials.append(mat)
						print("⚠️ EMBEDDED MATERIAL FOUND ON: ", node.name)

		for child in node.get_children():
			self_ref.call(child, self_ref)
			
	print("\n--- 🔍 STARTING RESOURCE AUDIT ---")
	scan_node.call(root, scan_node)
	
	print("\n--- 📊 AUDIT RESULTS ---")
	print("Total MeshInstance3D nodes: ", mesh_instances_count)
	print("Total Unique Meshes loaded: ", unique_meshes.size())
	print("Total Embedded ('Made Unique') Materials: ", embedded_materials.size())
	
	if embedded_materials.size() > 0:
		print("\n❌ WARNING: You have " + str(embedded_materials.size()) + " embedded materials!")
		print("Embedded materials increase your .tscn file size and cost extra draw calls.")
		print("Consider right-clicking them in the inspector and saving them as .tres files!")
	else:
		print("\n✅ EXCELLENT: No embedded materials found. Perfect architecture!")
	print("-----------------------------\n")

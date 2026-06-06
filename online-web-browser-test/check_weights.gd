@tool
extends EditorScript

func _run():
	print("--- STARTING WEIGHT CHECK ---")
	var scene = load("res://Assets/Models/Chameleon/chameleon.tscn")
	if not scene:
		print("Could not load scene!")
		return
		
	var instance = scene.instantiate()
	var skel = _find_skeleton(instance)
	
	_check_all_meshes(instance, skel)
	print("--- FINISHED WEIGHT CHECK ---")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var s = _find_skeleton(child)
		if s: return s
	return null

func _check_all_meshes(node: Node, skel: Skeleton3D):
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		_analyze_mesh(node.name, node.mesh, skel)
	for child in node.get_children():
		_check_all_meshes(child, skel)

func _analyze_mesh(mesh_name: String, mesh: ArrayMesh, skel: Skeleton3D):
	print("\n--- Analyzing: ", mesh_name, " ---")
	var arrays = mesh.surface_get_arrays(0)
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	
	if bones == null or weights == null or bones.size() == 0:
		print("No bone weights found on this mesh.")
		return
		
	var vertex_count = arrays[Mesh.ARRAY_VERTEX].size()
	var has_mixed_weights = false
	var mixed_examples = 0
	
	var all_bone_names = {}
	
	for i in range(vertex_count):
		var b_idx = i * 4
		var active_bones = 0
		var bone_strings = []
		
		for j in range(4):
			var w = weights[b_idx + j]
			if w > 0.05: # More than 5% influence
				active_bones += 1
				var bone_id = int(bones[b_idx + j])
				var b_name = skel.get_bone_name(bone_id) if skel else str(bone_id)
				bone_strings.append(b_name + "(" + str(snapped(w, 0.01)) + ")")
				all_bone_names[b_name] = true
				
		if active_bones > 1:
			has_mixed_weights = true
			if mixed_examples < 5:
				print("Vertex ", i, " has mixed weights: ", ", ".join(bone_strings))
				mixed_examples += 1
				
	print("Bones influencing this mesh: ", all_bone_names.keys())
	if has_mixed_weights:
		print("CONCLUSION: ", mesh_name, " DEFINITELY has mixed bone weights!")
	else:
		print("CONCLUSION: ", mesh_name, " is rigidly weighted.")

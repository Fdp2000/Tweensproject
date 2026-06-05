@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("No scene open! Please open PrototypeLevel.tscn first.")
		return
	
	print("--- FIXING SCALES IN ", root.name, " ---")
	var count = [0]
	_fix_node(root, "", count)
	print("Fixed ", count[0], " StaticBody3D nodes!")

func _fix_node(node: Node, path: String, count_ref: Array):
	if node is StaticBody3D:
		var s = node.scale
		# Check if it has a non-uniform scale
		var is_uniform = abs(s.x - s.y) < 0.001 and abs(s.x - s.z) < 0.001
		
		# We also want to fix uniform scales that aren't 1,1,1 just to be safe with Jolt, 
		# but the error is specifically about non-uniform scaling.
		if not is_uniform and (abs(s.x - 1.0) > 0.001 or abs(s.y - 1.0) > 0.001 or abs(s.z - 1.0) > 0.001):
			print("Fixing scale at: ", path + "/" + node.name, " -> ", s)
			
			# 1. Reset the StaticBody3D scale to (1,1,1)
			node.scale = Vector3.ONE
			
			# 2. Transfer the scale to its children
			for child in node.get_children():
				if child is Node3D:
					if child is MeshInstance3D:
						child.scale = child.scale * s
						child.position = child.position * s
					elif child is CollisionShape3D:
						child.position = child.position * s
						if child.shape != null:
							# Duplicate to prevent modifying shared shapes (like 50 benches sharing 1 box shape)
							child.shape = child.shape.duplicate()
							
							if child.shape is BoxShape3D:
								child.shape.size = child.shape.size * s
							else:
								print("  -> WARNING: ", child.name, " uses ", child.shape.get_class(), " which cannot be auto-scaled. Manual adjustment required.")
					else:
						# Other nodes (like Marker3D)
						child.scale = child.scale * s
						child.position = child.position * s
			
			count_ref[0] += 1
			
	for child in node.get_children():
		_fix_node(child, path + "/" + node.name, count_ref)

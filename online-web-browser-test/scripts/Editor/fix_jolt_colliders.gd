@tool
extends EditorScript

func _run():
	var root = get_scene()
	
	if root == null or root.name != "PrototypeLevel":
		print("ERROR: Please open PrototypeLevel.tscn and make it your active scene before running this script.")
		return
		
	print("--- STARTING JOLT PHYSICS FIXER ---")
	
	var fixed_count = 0
	
	var fix_colliders = func(node: Node, self_ref: Callable):
		for child in node.get_children():
			if child is CollisionShape3D:
				var parent = child.get_parent()
				
				# We only care about StaticBody3D parents for this level
				if parent is StaticBody3D:
					var shape_scale = child.scale
					var parent_scale = parent.scale
					
					# Check if either scale is not exactly Vector3.ONE
					var is_shape_scaled = not shape_scale.is_equal_approx(Vector3.ONE)
					var is_parent_scaled = not parent_scale.is_equal_approx(Vector3.ONE)
					
					if is_shape_scaled or is_parent_scaled:
						# Only auto-fix BoxShape3D
						if child.shape is BoxShape3D:
							var box = child.shape as BoxShape3D
							
							# 1. Bake the combined scale directly into the Box size
							var combined_scale = parent_scale * shape_scale
							box.size = box.size * combined_scale.abs()
							
							# 2. If the parent was scaled, the child's local position was also affected globally. 
							# We must bake the parent's scale into the child's position before resetting the parent!
							child.position = child.position * parent_scale
							
							# 3. Reset the scales back to pure 1.0 to make Jolt happy
							child.scale = Vector3.ONE
							parent.scale = Vector3.ONE
							
							print("FIXED: " + str(parent.name) + "/" + str(child.name) + " (Baked scale into BoxShape Size)")
							fixed_count += 1
						else:
							print("WARNING: Found scaled collider that is NOT a BoxShape3D: " + str(parent.name) + "/" + str(child.name) + ". You must fix this manually!")
							
			self_ref.call(child, self_ref)
			
	fix_colliders.call(root, fix_colliders)
	
	print("SUCCESS: Automatically fixed " + str(fixed_count) + " scaled colliders!")
	print("Jolt Physics errors should now be completely gone. Please save the scene.")

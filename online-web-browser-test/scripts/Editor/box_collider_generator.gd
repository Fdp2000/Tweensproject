@tool
extends EditorScript

## HOW TO RUN:
## 1. Have your Level scene open in your 2D/3D viewport
## 2. Open this script in the Script editor
## 3. Go to File -> Run (or press Ctrl+Shift+X)

func _run():
	var root = get_scene()
	
	if root == null:
		print("ERROR: Please open a scene and make it your active scene before running this script.")
		return
		
	print("--- STARTING BOX COLLIDER GENERATION FOR: " + root.name + " ---")
	
	var colliders_generated = 0
	
	# Recursive function to find MeshInstance3D nodes
	var generate_colliders = func(node: Node, self_ref: Callable):
		for child in node.get_children():
			if child is MeshInstance3D and child.mesh != null:
				
				# 1. Check if it already has a collider and delete it if we want a fresh box
				var existing_body = null
				for c in child.get_children():
					if c is StaticBody3D:
						existing_body = c
						break
				
				if existing_body == null:
					var static_body = StaticBody3D.new()
					static_body.name = "StaticBody3D"
					child.add_child(static_body)
					static_body.owner = root
					
					var col_shape = CollisionShape3D.new()
					col_shape.name = "CollisionShape3D"
					var box = BoxShape3D.new()
					
					var aabb = child.mesh.get_aabb()
					var s = child.scale
					
					# Counter-act the parent's scale so Jolt Physics doesn't complain about non-uniform scaling!
					var safe_scale = Vector3(
						1.0 / s.x if s.x != 0 else 1.0,
						1.0 / s.y if s.y != 0 else 1.0,
						1.0 / s.z if s.z != 0 else 1.0
					)
					static_body.scale = safe_scale
					
					box.size = aabb.size * s.abs()
					col_shape.shape = box
					
					# Offset the shape by the AABB's local position center, scaled up
					col_shape.position = (aabb.position + (aabb.size / 2.0)) * s
					
					static_body.add_child(col_shape)
					col_shape.owner = root
					
					colliders_generated += 1
			
			# Continue searching down the tree
			self_ref.call(child, self_ref)
			
	# Start the recursion from the root node
	generate_colliders.call(root, generate_colliders)
	
	print("SUCCESS! Auto-generated " + str(colliders_generated) + " primitive Box Colliders.")
	print("--- Please save your scene (Ctrl+S) ---")

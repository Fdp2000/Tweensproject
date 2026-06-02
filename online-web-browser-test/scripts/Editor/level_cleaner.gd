@tool
extends EditorScript

## HOW TO RUN:
## 1. Have PrototypeLevel.tscn OPEN in your 2D/3D viewport!
## 2. Open this script in the Script editor.
## 3. Go to File -> Run (or press Ctrl+Shift+X)

func _run():
	var root = get_scene()
	
	if root == null or root.name != "PrototypeLevel":
		print("ERROR: Please open PrototypeLevel.tscn and make it your active scene before running this script.")
		return
		
	var nav_region: NavigationRegion3D = null
	
	# 1. Find the existing NavigationRegion3D recursively
	var nav_regions = root.find_children("*", "NavigationRegion3D", true, false)
	if nav_regions.size() > 0:
		nav_region = nav_regions[0]
			
	if nav_region == null:
		print("ERROR: Could not find NavigationRegion3D in PrototypeLevel.")
		return
		
	print("--- STARTING PROTOTYPE LEVEL CLEANUP ---")
	
	# PREVENT CYCLIC DEPENDENCIES: Move nav_region to root first!
	if nav_region.get_parent() != root:
		var global_trans = nav_region.global_transform
		nav_region.get_parent().remove_child(nav_region)
		root.add_child(nav_region)
		nav_region.owner = root
		nav_region.global_transform = global_trans
		
		# Ensure its children keep the root as owner
		var set_owner_recursive = func(n: Node, self_ref: Callable):
			for c in n.get_children():
				c.owner = root
				self_ref.call(c, self_ref)
		set_owner_recursive.call(nav_region, set_owner_recursive)
	
	# 2. Recursively delete all colliders unless they have "KEEP" in their name
	var nodes_deleted = 0
	var bodies_to_delete = []
	
	# Function to recursively find nodes
	var find_colliders = func(node: Node, self_ref: Callable):
		for child in node.get_children():
			if "KEEP" in child.name.to_upper():
				pass # Skip this node!
			elif child is StaticBody3D or child is CollisionShape3D or child is CollisionPolygon3D:
				# If we found a body, queue it for deletion and skip its children
				if child not in bodies_to_delete:
					bodies_to_delete.append(child)
					nodes_deleted += 1
			else:
				self_ref.call(child, self_ref)
				
	find_colliders.call(root, find_colliders)
	
	for body in bodies_to_delete:
		body.get_parent().remove_child(body)
		body.queue_free()
		
	print("DELETED " + str(nodes_deleted) + " unoptimized colliders (Ignored nodes with 'KEEP' in name).")
	
	# 3. Move all standalone MeshInstance3D and Node3D geometry into the NavRegion!
	var nodes_moved = 0
	var nodes_to_move = []
	
	for child in root.get_children():
		if child == nav_region: continue
		
		# Skip cameras, managers, spawn points, or lighting
		if child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment or "Spawn" in child.name:
			continue
			
		# If it's a model/mesh, we want it in the NavRegion!
		if child is Node3D and "KEEP" not in child.name.to_upper():
			nodes_to_move.append(child)
			
	for node in nodes_to_move:
		var global_trans = node.global_transform
		root.remove_child(node)
		nav_region.add_child(node)
		node.owner = root # VERY IMPORTANT for saving in Godot Editor
		node.global_transform = global_trans
		
		# Recursively set owner for all children so they save properly in the scene!
		var set_owner_recursive = func(n: Node, self_ref: Callable):
			for c in n.get_children():
				c.owner = root
				self_ref.call(c, self_ref)
		set_owner_recursive.call(node, set_owner_recursive)
		nodes_moved += 1
		
	print("MOVED " + str(nodes_moved) + " root nodes into the NavigationRegion3D.")
	
	# 4. Auto-Generate Primitive Box Colliders for everything!
	var colliders_generated = 0
	
	# Function to recursively find MeshInstance3D nodes
	var generate_colliders = func(node: Node, self_ref: Callable):
		for child in node.get_children():
			if child is MeshInstance3D and child.mesh != null:
				# Check if it already has a StaticBody3D so we don't duplicate
				var has_collider = false
				for c in child.get_children():
					if c is StaticBody3D:
						has_collider = true
						break
				
				if not has_collider:
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
					
					# Offset the shape by the AABB's local position center, scaled up!
					col_shape.position = (aabb.position + (aabb.size / 2.0)) * s
					
					static_body.add_child(col_shape)
					col_shape.owner = root
					
					colliders_generated += 1
			
			self_ref.call(child, self_ref)
			
	generate_colliders.call(nav_region, generate_colliders)
	
	print("AUTO-GENERATED " + str(colliders_generated) + " primitive Box Colliders!")
	print("--- CLEANUP & GENERATION COMPLETE! ---")

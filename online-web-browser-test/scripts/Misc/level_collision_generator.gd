extends Node3D
## Attach this script to the PrototypeLevel root node.
## Generates SIMPLIFIED convex collision at runtime for all MeshInstance3D
## children. Convex shapes are dramatically lighter than trimesh.

var skip_prefixes := ["Arch", "Dingus", "WallBigCorner", "Artifact"]
var count := 0
var skipped := 0

func _ready():
	_generate_collision()

func _generate_collision():
	count = 0
	skipped = 0
	# We use a single recursive pass to avoid "climbing" the parent tree repeatedly
	_process_node_recursive(self, false)
	print("[LevelCollision] Generated convex collision for ", count, " meshes (skipped ", skipped, ")")

func _process_node_recursive(node: Node, parent_is_skipped: bool):
	var should_skip_branch = parent_is_skipped
	
	# Check if THIS specific node or its name warrants skipping the entire branch
	if not should_skip_branch:
		for prefix in skip_prefixes:
			if node.name.begins_with(prefix):
				should_skip_branch = true
				break
		
		if not should_skip_branch:
			if node.is_in_group("artifact") or node.has_node("InteractionArea"):
				should_skip_branch = true

	# If it's a mesh and we aren't skipping it, generate collision
	if node is MeshInstance3D and node.mesh != null:
		if should_skip_branch:
			skipped += 1
		else:
			# Skip if this mesh already has a StaticBody child
			var already_has_collision := false
			for c in node.get_children():
				if c is StaticBody3D:
					already_has_collision = true
					break
			
			if not already_has_collision:
				var shape = node.mesh.create_convex_shape(true, true)
				if shape != null:
					var body = StaticBody3D.new()
					var col = CollisionShape3D.new()
					col.shape = shape
					body.add_child(col)
					node.add_child(body)
					count += 1
	
	# Pass the skip status down to children
	for child in node.get_children():
		_process_node_recursive(child, should_skip_branch)

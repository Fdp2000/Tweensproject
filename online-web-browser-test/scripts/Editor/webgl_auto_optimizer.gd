@tool
extends EditorScript

# Optimization Settings
const CULL_DISTANCE = 80.0
const CULL_MARGIN = 5.0
const MAX_SHADOW_VOLUME = 8.0 # Cubic meters. If smaller than this, it won't cast shadows

func _run():
	var root = get_scene()
	if not root:
		print("No scene open! Open PrototypeLevel.tscn first.")
		return
		
	print("--- STARTING WEBGL OPTIMIZATION ---")
	var stats = {"shadows_disabled": 0, "culling_applied": 0, "gi_set": 0}
	_optimize_node(root, stats)
	
	print("--- OPTIMIZATION COMPLETE ---")
	print("Turned off shadows for ", stats["shadows_disabled"], " small props.")
	print("Applied distance culling to ", stats["culling_applied"], " meshes.")
	print("Set GI mode to STATIC for ", stats["gi_set"], " meshes to allow light baking.")
	print("Please press Ctrl+S to save the scene!")

func _optimize_node(node: Node, stats: Dictionary):
	if node is GeometryInstance3D:
		# 1. Apply Distance Culling
		# Only apply if it's not already set
		if node.visibility_range_end == 0.0:
			node.visibility_range_end = CULL_DISTANCE
			node.visibility_range_end_margin = CULL_MARGIN
			stats["culling_applied"] += 1
			
		# 2. Disable Shadows for small objects
		if node is MeshInstance3D and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var aabb = node.get_aabb()
			var volume = aabb.size.x * aabb.size.y * aabb.size.z
			# If the volume of the mesh is very small (like bushes, floor tiles, small boxes)
			if volume < MAX_SHADOW_VOLUME:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				stats["shadows_disabled"] += 1
			# 3. Setup Light Baking
			if node.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
				node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
				stats["gi_set"] += 1
				
	for child in node.get_children():
		_optimize_node(child, stats)

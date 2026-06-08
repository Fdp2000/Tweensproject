@tool
extends EditorScript

# === CONFIGURATION ===
# Tweak these numbers and hit File -> Run (or Ctrl+Shift+X) until it looks perfect!

# Any mesh smaller than this total volume (in cubic meters) will lose its shadow.
# E.g., 0.5 removes shadows from small cups, books, and tiny props.
const MIN_VOLUME = 0.1

# Any mesh SHORTER than this (in world-space meters) will lose its shadow.
# This ensures flat floors and rugs never cast shadows, but walls do!
const MIN_HEIGHT = 0.1

func _run():
	var root = get_scene()
	if not root:
		print("ERROR: Please open a level scene (like PrototypeLevel.tscn) first!")
		return
		
	var optimized_count = 0
	var kept_count = 0
	
	var nodes_to_check = [root]
	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		if current is MeshInstance3D:
			# Get the local bounding box
			var local_aabb = current.get_aabb()
			
			# Convert the bounding box to TRUE WORLD SPACE.
			# This is where your previous script likely failed! 
			# By transforming it into world space, we account for the mesh's global scale AND rotation.
			var world_aabb = current.global_transform * local_aabb
			
			var volume = world_aabb.size.x * world_aabb.size.y * world_aabb.size.z
			var world_height = world_aabb.size.y
			
			# Is it tiny? Or is it perfectly flat on the ground?
			if volume < MIN_VOLUME or world_height < MIN_HEIGHT:
				current.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				optimized_count += 1
			else:
				current.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				kept_count += 1

	print("=========================================")
	print("🚀 SHADOW OPTIMIZATION COMPLETE 🚀")
	print("=========================================")
	print("- Shadows turned OFF (Too small or flat): ", optimized_count)
	print("- Shadows kept ON (Large walls/objects): ", kept_count)
	print("Tip: If it removed too much, lower MIN_VOLUME to 0.5 and Run again!")

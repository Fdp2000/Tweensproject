@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("ERROR: Please open a scene first!")
		return
		
	var disabled_count = 0
	
	var nodes_to_check = [root]
	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		if current is MeshInstance3D:
			current.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			disabled_count += 1
			
		elif current is DirectionalLight3D or current is OmniLight3D or current is SpotLight3D:
			current.shadow_enabled = false

	print("=========================================")
	print("🌑 ALL SHADOWS DISABLED 🌑")
	print("=========================================")
	print("- Meshes stripped of shadows: ", disabled_count)
	print("- Lights stripped of shadows as well.")

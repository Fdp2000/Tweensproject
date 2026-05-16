extends Node
class_name ThiefStealthManager

var thief: Node3D
var camo_material: ShaderMaterial
var hypno_material: ShaderMaterial

var _is_dual_mesh_setup = false
var base_meshes: Array[MeshInstance3D] = []
var camo_meshes: Array[MeshInstance3D] = []
var local_outline_mat: ShaderMaterial = null

var stationary_time = 0.0
var current_alpha = 1.0
var target_alpha = 1.0

var _last_rendered_alpha: float = -1.0
var _last_rendered_highlight: bool = false
var _last_rendered_hypnotized: bool = false
var last_outlined_target: Node3D = null

func setup(parent: Node3D, camo: ShaderMaterial, hypno: ShaderMaterial):
	thief = parent
	camo_material = camo
	hypno_material = hypno

func process_stealth(delta: float, speed: float, is_hypnotized: bool, is_jailed: bool, is_highlighted: bool):
	if speed < 0.2:
		stationary_time += delta
	else:
		stationary_time = 0.0
		
	if is_hypnotized or is_jailed:
		target_alpha = 1.0
	elif stationary_time >= Balance.thief_camo_activation_time:
		target_alpha = 0.0
	else:
		target_alpha = 1.0
		
	# --- USE BALANCE TRANSITION SPEED ---
	current_alpha = lerp(current_alpha, target_alpha, Balance.thief_camo_transition_speed * delta)
	
	if abs(current_alpha - _last_rendered_alpha) > 0.01 or is_highlighted != _last_rendered_highlight or is_hypnotized != _last_rendered_hypnotized:
		_apply_visual_states(current_alpha, target_alpha, is_hypnotized, is_jailed, is_highlighted)
		_last_rendered_alpha = current_alpha
		_last_rendered_highlight = is_highlighted
		_last_rendered_hypnotized = is_hypnotized

func update_outlines(target: Node3D):
	if target == last_outlined_target: return
	
	if last_outlined_target and is_instance_valid(last_outlined_target):
		if last_outlined_target.has_method("set_highlight"):
			last_outlined_target.set_highlight(false)
		else:
			last_outlined_target.set("is_highlighted", false)
			
	last_outlined_target = target
	
	if target and is_instance_valid(target):
		if target.has_method("set_highlight"):
			target.set_highlight(true)
		else:
			target.set("is_highlighted", true)

func _setup_dual_meshes(node: Node):
	if node is MeshInstance3D and not node.has_meta("mats_setup"):
		base_meshes.append(node)
		
		var node_mats = []
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_surface_override_material(i)
			if not mat:
				mat = node.mesh.surface_get_material(i)
			
			if mat and mat is ShaderMaterial:
				mat = mat.duplicate()
				mat.next_pass = null 
				node.set_surface_override_material(i, mat)
				node_mats.append(mat)
			else:
				node_mats.append(mat)
				
		node.set_meta("orig_mats", node_mats)
		node.set_meta("mats_setup", true)
		
		var camo_mesh = MeshInstance3D.new()
		camo_mesh.name = node.name + "_Camo"
		camo_mesh.set_meta("is_camo", true)
		camo_mesh.mesh = node.mesh
		camo_mesh.transform = node.transform
		camo_mesh.scale = Vector3(0.99, 0.99, 0.99)
		if node.skeleton: camo_mesh.skeleton = node.skeleton
		if node.skin: camo_mesh.skin = node.skin
		
		node.get_parent().add_child.call_deferred(camo_mesh)
		
		for i in range(camo_mesh.mesh.get_surface_count()):
			if camo_material:
				var c_mat = camo_material.duplicate()
				c_mat.render_priority = -1 
				camo_mesh.set_surface_override_material(i, c_mat)
		
		camo_mesh.hide()
		camo_meshes.append(camo_mesh)
		
	for child in node.get_children():
		if child.name != "InteractionArea" and child.name != "InteractionScanner" and not child.has_meta("is_camo"):
			_setup_dual_meshes(child)

func _apply_visual_states(alpha_val: float, t_alpha: float, is_hypnotized: bool, is_jailed: bool, is_highlighted: bool):
	if not _is_dual_mesh_setup:
		_setup_dual_meshes(thief)
		_is_dual_mesh_setup = true
		
	if not local_outline_mat:
		local_outline_mat = ShaderMaterial.new()
		var shader = preload("res://Assets/Shaders/HighlightShader/cartoony_outline.gdshader")
		if shader:
			local_outline_mat.shader = shader
			
	var stealth_amount = 1.0 - alpha_val 
	var is_stealthed = stealth_amount > 0.01
	
	if local_outline_mat:
		local_outline_mat.set_shader_parameter("stealth_fade", stealth_amount)
	
	for c_mesh in camo_meshes:
		if is_stealthed and not is_hypnotized and not is_jailed:
			c_mesh.show()
		else:
			c_mesh.hide()
			
	for b_mesh in base_meshes:
		if is_stealthed and stealth_amount >= 0.99:
			b_mesh.hide()
		else:
			b_mesh.show()
			
		if t_alpha > 0.0:
			b_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			b_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			
		var orig_mats = b_mesh.get_meta("orig_mats")
		for i in range(b_mesh.mesh.get_surface_count()):
			var active_mat = null
			
			if is_hypnotized:
				if hypno_material:
					var h_mat = null
					if b_mesh.has_meta("instanced_hypno"):
						h_mat = b_mesh.get_meta("instanced_hypno")
					else:
						h_mat = hypno_material.duplicate()
						b_mesh.set_meta("instanced_hypno", h_mat)
					active_mat = h_mat
			else:
				active_mat = orig_mats[i] if i < orig_mats.size() else null
				if active_mat and active_mat is ShaderMaterial:
					active_mat.set_shader_parameter("stealth_fade", stealth_amount)
					
			if active_mat:
				if is_highlighted:
					active_mat.next_pass = local_outline_mat
				else:
					active_mat.next_pass = null
					
			b_mesh.set_surface_override_material(i, active_mat)

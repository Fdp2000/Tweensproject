extends "res://scripts/Player/player.gd"

@export var camo_material: ShaderMaterial
@export var hypno_material: ShaderMaterial

var _is_dual_mesh_setup = false
var base_meshes: Array[MeshInstance3D] = []
var camo_meshes: Array[MeshInstance3D] = []
var local_outline_mat: ShaderMaterial = null

var stationary_time = 0.0
const INVISIBLE_TIME = 2.0
var current_alpha = 1.0
var target_alpha = 1.0
var carried_artifact: Node3D = null
var cash_contributed: int = 0
var is_hypnotized: bool = false
var is_rescue_halted: bool = false
var is_jailed: bool = false
var jail_walk_target: Vector3 = Vector3.ZERO   # Where the thief walks to (outside jail door)
var jail_cell_target: Vector3 = Vector3.ZERO   # Where the thief gets teleported (inside cell)
var is_highlighted: bool = false
var is_mobile_interact: bool = false
var last_pos: Vector3 = Vector3.ZERO
var nav_agent: NavigationAgent3D
var current_speed_mult: float = 1.0

var nearby_interactables: Array[Node3D] = []
var interaction_scanner: Area3D

var _last_rendered_alpha: float = -1.0
var _last_rendered_highlight: bool = false
var _last_rendered_hypnotized: bool = false


func get_carried_artifact():
	return carried_artifact

func on_artifact_pickup(artifact: Node3D):
	carried_artifact = artifact

func on_artifact_drop():
	carried_artifact = null

var rescue_progress: float = 0.0
var active_rescuer_id: int = -1
var is_rescuing: bool = false
var current_interact_target: Node3D = null
var rescue_ui_ref: Control = null
var last_outlined_target: Node3D = null
var outline_mat: StandardMaterial3D = null
const RESCUE_TIME_REQUIRED = 2.0

var debug_path_mesh: MeshInstance3D
var debug_label: Label3D

func _ready():
	super._ready()
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5   # Prevent cutting corners into walls
	nav_agent.target_desired_distance = 1.0  # Get closer to the jail cell door
	nav_agent.radius = 0.5                   # Keeps paths away from walls by this distance
	nav_agent.avoidance_enabled = false      # We don't need dynamic obstacle avoidance
	add_child(nav_agent)
	
	if is_multiplayer_authority():
		# Setup Debug Path Visualizer
		debug_path_mesh = MeshInstance3D.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.MAGENTA
		mat.emission_enabled = true
		mat.emission = Color.MAGENTA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.flags_no_depth_test = true
		debug_path_mesh.material_override = mat
		get_tree().root.call_deferred("add_child", debug_path_mesh)
		
		# Setup Debug Text Label
		debug_label = Label3D.new()
		debug_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		debug_label.position = Vector3(0, 2.5, 0)
		debug_label.pixel_size = 0.005
		debug_label.modulate = Color.GREEN
		debug_label.outline_modulate = Color.BLACK
		debug_label.no_depth_test = true
		add_child(debug_label)

	
	if is_multiplayer_authority():
		interaction_scanner = Area3D.new()
		interaction_scanner.name = "InteractionScanner"
		interaction_scanner.collision_layer = 0
		interaction_scanner.collision_mask = 10 # Layer 2 (Players) + Layer 4 (Artifacts)
		add_child(interaction_scanner)
		
		var col = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 3.0
		col.shape = sphere
		interaction_scanner.add_child(col)
		
		interaction_scanner.body_entered.connect(_on_interactable_entered)
		interaction_scanner.body_exited.connect(_on_interactable_exited)
		interaction_scanner.area_entered.connect(_on_interactable_entered)
		interaction_scanner.area_exited.connect(_on_interactable_exited)
		
		await get_tree().process_frame
		var canvas = get_node_or_null("PlayerCanvas")
		if canvas:
			var ui = Control.new()
			ui.set_script(load("res://scripts/UI/dash_ui.gd"))
			ui.ring_color = Color(0.2, 1.0, 0.4, 0.9)
			ui.ready_color = Color(1.0, 1.0, 1.0, 0.0)
			ui.custom_minimum_size = Vector2(40, 40)
			ui.set_anchors_preset(Control.PRESET_CENTER)
			ui.offset_left = -20 + 40
			ui.offset_right = 20 + 40
			ui.offset_top = -20 - 20
			ui.offset_bottom = 20 - 20
			ui.hide_when_empty = true
			ui.name = "RescueUI"
			rescue_ui_ref = ui
			canvas.add_child(ui)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	# --- DEV TOOL: Toggle Hypnotized ---
	if event is InputEventKey and event.physical_keycode == KEY_H and event.pressed and not event.echo:
		rpc("dev_toggle_hypnotize")
		return
		
	if is_hypnotized:
		# Allow them to look around with the mouse, but only rotate the camera pivot, not the body
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var actual_sens = mouse_sensitivity * 0.001
			pitch_pivot.rotate_y(-event.relative.x * actual_sens)
			pitch_pivot.rotate_x(-event.relative.y * actual_sens)
			pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, -1.0, 1.0)
		return
		
	super._unhandled_input(event)
	
	# Interact/Pickup/Drop/Rescue
	var is_interact = (event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_interact:
		if carried_artifact: 
			_try_drop()
		else:
			var target = get_closest_interactable()
			if target and not target.has_method("on_captured"): # Artifact
				target.rpc_id(1, "request_pickup", multiplayer.get_unique_id())

func _try_drop():
	if carried_artifact:
		carried_artifact.rpc("drop")
		carried_artifact = null

func _on_interactable_entered(node: Node3D):
	var target = node
	if node is Area3D and node.get_parent().is_in_group("artifact"):
		target = node.get_parent()
		
	if target not in nearby_interactables:
		nearby_interactables.append(target)

func _on_interactable_exited(node: Node3D):
	var target = node
	if node is Area3D and node.get_parent().is_in_group("artifact"):
		target = node.get_parent()
		
	if target in nearby_interactables:
		nearby_interactables.erase(target)

func get_closest_interactable() -> Node3D:
	var closest_thief: Node3D = null
	var closest_art: Node3D = null
	var min_dist_thief: float = 3.0
	var min_dist_art: float = 3.0
	
	nearby_interactables = nearby_interactables.filter(func(n): return is_instance_valid(n))
	
	for target in nearby_interactables:
		var dist = global_position.distance_to(target.global_position)
		
		if target.has_method("on_captured") and target != self and target.get("team_index") == 0 and target.get("is_hypnotized"):
			if dist < min_dist_thief:
				closest_thief = target
				min_dist_thief = dist
				
		elif target.is_in_group("artifact") and not target.get("is_carried"):
			if dist < min_dist_art:
				closest_art = target
				min_dist_art = dist
				
	if closest_thief: return closest_thief
	return closest_art

func _update_outlines(target: Node3D):
	if target == last_outlined_target: return
	
	# Turn off old highlight
	if last_outlined_target and is_instance_valid(last_outlined_target):
		if last_outlined_target.has_method("set_highlight"):
			last_outlined_target.set_highlight(false)
		else:
			last_outlined_target.set("is_highlighted", false)
			
	last_outlined_target = target
	
	# Turn on new highlight
	if target and is_instance_valid(target):
		if target.has_method("set_highlight"):
			target.set_highlight(true)
		else:
			target.set("is_highlighted", true)


func update_jail_targets(walk_pos: Vector3, cell_pos: Vector3):
	jail_walk_target = walk_pos
	jail_cell_target = cell_pos
	if nav_agent:
		nav_agent.target_position = jail_walk_target

func _custom_physics_process(delta, direction):
	if is_hypnotized:
		if is_multiplayer_authority():
			if is_rescue_halted:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			else:
				var dist_to_target = global_position.distance_to(jail_walk_target)
				
				if dist_to_target < 1.0:
					rpc("on_jailed", jail_cell_target)
					velocity.x = 0
					velocity.z = 0
				elif nav_agent.is_navigation_finished():
					# The path is finished, but we haven't reached the jail!
					# This means the NavMesh is severed/broken and the jail is unreachable.
					velocity.x = move_toward(velocity.x, 0, SPEED)
					velocity.z = move_toward(velocity.z, 0, SPEED)
					draw_debug_path()
				else:
					var next_pos = nav_agent.get_next_path_position()
					draw_debug_path()
					
					# Dynamically negate any vertical mismatch between the NavMesh and the Thief's physical feet.
					# This forces Godot's internal waypoint-clearance check to evaluate as a pure 2D horizontal distance,
					# preventing the freezing bug while allowing us to keep a strict 0.5m path_desired_distance!
					nav_agent.path_height_offset = next_pos.y - global_position.y
					
					# Flatten the positions to ignore vertical mismatches between NavMesh and Physics
					var flat_global = Vector3(global_position.x, 0, global_position.z)
					var flat_next = Vector3(next_pos.x, 0, next_pos.z)
					var dist_to_next_flat = flat_global.distance_to(flat_next)
					
					if dist_to_next_flat < 0.1:
						# We are practically standing on the waypoint horizontally.
						# Stop applying velocity so we don't vibrate from floating point dust.
						velocity.x = move_toward(velocity.x, 0, SPEED)
						velocity.z = move_toward(velocity.z, 0, SPEED)
						if debug_label: debug_label.text = "STOPPED (dist_flat < 0.1)\nVel: " + str(velocity.length())
					else:
						# Calculate pure horizontal direction
						var dir_to_next = flat_global.direction_to(flat_next)
						
						velocity.x = dir_to_next.x * (SPEED * 0.4)
						velocity.z = dir_to_next.z * (SPEED * 0.4)
						
						if debug_label: debug_label.text = "MOVING\ndist_flat: " + str(dist_to_next_flat).pad_decimals(2) + "\nVel: " + str(velocity.length()).pad_decimals(2)
						
						# --- CAMERA FIX: DECOUPLE FROM BODY ROTATION ---
						var old_cam_basis = pitch_pivot.global_basis
						var target_transform = transform.looking_at(global_position + dir_to_next, Vector3.UP)
						transform = transform.interpolate_with(target_transform, 5.0 * delta)
						pitch_pivot.global_basis = old_cam_basis.orthonormalized()
						# -----------------------------------------------
						
		if multiplayer.is_server():
			if active_rescuer_id != -1:
				var rescuer = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(active_rescuer_id))
				if rescuer and rescuer.global_position.distance_to(global_position) <= 4.0:
					if not is_rescue_halted:
						is_rescue_halted = true
						rpc("sync_rescue_halt", true)
						
					rescue_progress += delta
					rpc("sync_rescue_progress", rescue_progress)
					
					if rescue_progress >= RESCUE_TIME_REQUIRED:
						active_rescuer_id = -1
						rescue_progress = 0.0
						rpc("sync_rescue_progress", 0.0)
						rpc("sync_rescue_halt", false)
						rpc("rescue_successful")
				else:
					active_rescuer_id = -1
					if is_rescue_halted:
						is_rescue_halted = false
						rpc("sync_rescue_halt", false)
			else:
				if is_rescue_halted:
					is_rescue_halted = false
					rpc("sync_rescue_halt", false)
		return
		
	if carried_artifact:
		# Apply weight penalty instantly when holding an item
		current_speed_mult = carried_artifact.weight_penalty
	else:
		# If NOT holding an item, smoothly recover back to 1.0 (normal speed)
		# delta * 0.3 means it recovers 30% speed per second. 
		# (e.g., A 60% slow from a Large artifact will take 2 seconds to wear off)
		current_speed_mult = move_toward(current_speed_mult, 1.0, delta * 0.3)
		
	if direction:
		velocity.x = direction.x * (SPEED * current_speed_mult)
		velocity.z = direction.z * (SPEED * current_speed_mult)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * current_speed_mult)
		velocity.z = move_toward(velocity.z, 0, SPEED * current_speed_mult)
	
func _process(delta):
		# --- ADD THIS LINE RIGHT HERE! ---
	# This tells Godot to run the network smoothing math from Player.gd!
	super._process(delta) 
	# ---------------------------------
	# 1. VISUAL TRANSPARENCY (Runs for EVERYONE to calculate smooth visual alpha)
	var speed = 0.0
	if is_multiplayer_authority():
		speed = Vector3(velocity.x, 0, velocity.z).length()
	else:
		var dist = Vector3(global_position.x, 0, global_position.z).distance_to(Vector3(last_pos.x, 0, last_pos.z))
		speed = dist / delta
		last_pos = global_position
		
	if speed < 0.2:
		stationary_time += delta
	else:
		stationary_time = 0.0
		
	if is_hypnotized:
		target_alpha = 1.0
	elif stationary_time >= INVISIBLE_TIME:
		target_alpha = 0.0
	else:
		target_alpha = 1.0
		
	current_alpha = lerp(current_alpha, target_alpha, 8.0 * delta)
	
	if abs(current_alpha - _last_rendered_alpha) > 0.01 or is_highlighted != _last_rendered_highlight or is_hypnotized != _last_rendered_hypnotized:
		_apply_visual_states(current_alpha, target_alpha)
		_last_rendered_alpha = current_alpha
		_last_rendered_highlight = is_highlighted
		_last_rendered_hypnotized = is_hypnotized


	# 2. HIGHLIGHT & INTERACTION LOGIC (Runs ONLY for the local player)
	if not is_multiplayer_authority(): return
	
	# FIX: If hypnotized or jailed, immediately clear highlights and stop rescuing!
	if is_hypnotized or is_jailed:
		_update_outlines(null)
		if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
			rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null
		return

	# Scan for targets
	var target = null
	if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
		target = current_interact_target
	else:
		target = get_closest_interactable()
		
	_update_outlines(target)
	
	# UI and Input Handling
	if rescue_ui_ref:
		if current_interact_target and is_instance_valid(current_interact_target) and current_interact_target.has_method("on_captured"):
			rescue_ui_ref.progress = current_interact_target.rescue_progress / RESCUE_TIME_REQUIRED
		else:
			rescue_ui_ref.progress = 0.0
			
	if Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or is_mobile_interact:
		if not is_rescuing and target and is_instance_valid(target):
			if target.has_method("on_captured") and not carried_artifact:
				is_rescuing = true
				current_interact_target = target
				rpc_id(1, "request_start_rescue", int(str(target.name)))
	else:
		if is_rescuing:
			if current_interact_target and is_instance_valid(current_interact_target):
				rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null
			
	if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
		if global_position.distance_to(current_interact_target.global_position) > 3.0 or not current_interact_target.get("is_hypnotized"):
			rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null

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
				mat.next_pass = null # Clean up old next_pass testing
				node.set_surface_override_material(i, mat)
				node_mats.append(mat)
			else:
				node_mats.append(mat)
				
		node.set_meta("orig_mats", node_mats)
		node.set_meta("mats_setup", true)
		
		# Create local camo duplicate
		var camo_mesh = MeshInstance3D.new()
		camo_mesh.name = node.name + "_Camo"
		camo_mesh.set_meta("is_camo", true)
		camo_mesh.mesh = node.mesh
		camo_mesh.transform = node.transform
		# Shrink the camo mesh microscopically to prevent Z-fighting with the base mesh
		camo_mesh.scale = Vector3(0.99, 0.99, 0.99)
		if node.skeleton: camo_mesh.skeleton = node.skeleton
		if node.skin: camo_mesh.skin = node.skin
		
		node.get_parent().add_child.call_deferred(camo_mesh)
		
		for i in range(camo_mesh.mesh.get_surface_count()):
			if camo_material:
				var c_mat = camo_material.duplicate()
				c_mat.render_priority = -1 # Guarantee it draws BEFORE BaseMesh!
				camo_mesh.set_surface_override_material(i, c_mat)
		
		camo_mesh.hide()
		camo_meshes.append(camo_mesh)
		
	for child in node.get_children():
		if child.name != "InteractionArea" and child.name != "InteractionScanner" and not child.has_meta("is_camo"):
			_setup_dual_meshes(child)

func _apply_visual_states(alpha_val: float, target_alpha: float):
	if not _is_dual_mesh_setup:
		_setup_dual_meshes(self)
		_is_dual_mesh_setup = true
		
	if not local_outline_mat:
		local_outline_mat = ShaderMaterial.new()
		var shader = preload("res://Assets/Shaders/HighlightShader/cartoony_outline.gdshader")
		if shader:
			local_outline_mat.shader = shader
			
	var stealth_amount = 1.0 - alpha_val # 0 is visible, 1 is invisible
	var is_stealthed = stealth_amount > 0.01
	
	local_outline_mat.set_shader_parameter("stealth_fade", stealth_amount)
	
	# Update Camo Meshes
	for c_mesh in camo_meshes:
		if is_stealthed and not is_hypnotized:
			c_mesh.show()
		else:
			c_mesh.hide()
			
	# Update Base Meshes
	for b_mesh in base_meshes:
		if is_stealthed and stealth_amount >= 0.99:
			b_mesh.hide()
		else:
			b_mesh.show()
			
		# Turn off shadow instantly when aiming for invisible, turn on instantly when aiming for visible
		if target_alpha > 0.0:
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

@rpc("any_peer", "call_local")
func on_captured():
	if is_hypnotized: return
	is_hypnotized = true
	disable_body_rotation = true # Toggle camera free-look
	
	collision_layer = 8 
	collision_mask = 5  
	
	if carried_artifact:
		if multiplayer.is_server():
			carried_artifact.rpc("drop")
		carried_artifact = null
	
	var jails = get_tree().get_nodes_in_group("jail")
	if jails.size() > 0:
		var jail = jails[0]
		var walk_pos = jail.get_node("WalkTarget").global_position
		var cell_pos = jail.get_node("CellTarget").global_position
		update_jail_targets(walk_pos, cell_pos)
		
	if multiplayer.is_server():
		GameManager.rpc("thief_captured")

@rpc("any_peer", "call_local")
func dev_toggle_hypnotize():
	if not is_hypnotized:
		is_hypnotized = true
		disable_body_rotation = true
		collision_layer = 8 
		collision_mask = 5  
		
		var jails = get_tree().get_nodes_in_group("jail")
		if jails.size() > 0:
			var jail = jails[0]
			var walk_pos = jail.get_node("WalkTarget").global_position
			var cell_pos = jail.get_node("CellTarget").global_position
			update_jail_targets(walk_pos, cell_pos)
			
		print("[DEV] Thief HYPNOTIZED via hotkey")
	else:
		is_hypnotized = false
		disable_body_rotation = false
		collision_layer = 2
		collision_mask = 3
		
		# Reset camera to look forward again
		pitch_pivot.rotation = Vector3.ZERO
		
		print("[DEV] Thief UN-hypnotized via hotkey")

func _exit_tree():
	if debug_path_mesh and is_instance_valid(debug_path_mesh):
		debug_path_mesh.queue_free()

func draw_debug_path():
	if not debug_path_mesh: return
	var path = nav_agent.get_current_navigation_path()
	if path.size() < 2:
		debug_path_mesh.mesh = null
		return
		
	var im_mesh = ImmediateMesh.new()
	im_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(path.size() - 1):
		# Draw a bright line 0.5m above the ground
		im_mesh.surface_add_vertex(path[i] + Vector3(0, 0.5, 0))
		im_mesh.surface_add_vertex(path[i+1] + Vector3(0, 0.5, 0))
	im_mesh.surface_end()
	debug_path_mesh.mesh = im_mesh

@rpc("any_peer", "call_local")
func request_start_rescue(target_id: int):
	if not multiplayer.is_server(): return
	var target = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(target_id))
	if target and target.get("is_hypnotized"):
		target.active_rescuer_id = multiplayer.get_remote_sender_id()

@rpc("any_peer", "call_local")
func request_stop_rescue(target_id: int):
	if not multiplayer.is_server(): return
	var target = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(target_id))
	if target and target.active_rescuer_id == multiplayer.get_remote_sender_id():
		target.active_rescuer_id = -1

@rpc("any_peer", "call_local", "unreliable")
func sync_rescue_progress(prog: float):
	rescue_progress = prog

@rpc("any_peer", "call_local", "reliable")
func sync_rescue_halt(halted: bool):
	is_rescue_halted = halted

@rpc("any_peer", "call_local")
func rescue_successful():
	if not is_hypnotized: return
	
	is_hypnotized = false
	disable_body_rotation = false # Turn off free-look
	
	collision_layer = 4 
	collision_mask = 15 
	
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0 # Snap camera back to body's forward direction
		pitch_pivot.rotation.z = 0 # Fix any dutch-angle tilt introduced by the global_basis override
		
	if multiplayer.is_server():
		GameManager.rpc("thief_rescued")

@rpc("any_peer", "call_local")
func on_jailed(cell_pos: Vector3):
	is_hypnotized = false
	is_jailed = true
	disable_body_rotation = false # No this needs to be false when jailed to gain control again normally
	
	collision_layer = 4 
	collision_mask = 15 
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0
		pitch_pivot.rotation.z = 0
	
	global_position = cell_pos

func _add_custom_mobile_ui(mobile_ui: Control, ui_scale: float):
	var interact_btn = Button.new()
	interact_btn.name = "InteractButton"
	interact_btn.text = "INTERACT"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.15)
	style.set_corner_radius_all(100)
	style.set_border_width_all(4)
	style.border_color = Color(1, 1, 1, 0.4)
	
	interact_btn.add_theme_stylebox_override("normal", style)
	interact_btn.add_theme_stylebox_override("hover", style)
	interact_btn.add_theme_stylebox_override("pressed", style)
	interact_btn.add_theme_font_size_override("font_size", 18 * ui_scale)
	
	var btn_size = 130 * ui_scale
	interact_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	interact_btn.anchor_left = 1.0
	interact_btn.anchor_top = 1.0
	interact_btn.anchor_right = 1.0
	interact_btn.anchor_bottom = 1.0
	interact_btn.offset_left = -btn_size - (40 * ui_scale)
	interact_btn.offset_top = -btn_size - (280 * ui_scale)
	
	mobile_ui.add_child(interact_btn)
	
	# Handle both Pickup (Single Press) and Rescue (Holding)
	interact_btn.button_down.connect(func():
		is_mobile_interact = true
		# Trigger the "Single Press" logic for pickups
		if not carried_artifact:
			var target = get_closest_interactable()
			if target and not target.has_method("on_captured"):
				target.rpc_id(1, "request_pickup", multiplayer.get_unique_id())
		else:
			_try_drop()
	)
	interact_btn.button_up.connect(func():
		is_mobile_interact = false
	)

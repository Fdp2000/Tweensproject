extends "res://scripts/player.gd"

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

func _ready():
	super._ready()
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 1.5   # How close to a waypoint before moving to the next one
	nav_agent.target_desired_distance = 1.5  # How close to the final target to consider "arrived"
	nav_agent.radius = 0.6                   # Keeps paths away from walls by this distance
	nav_agent.avoidance_enabled = false      # We don't need dynamic obstacle avoidance
	add_child(nav_agent)
	
	if is_multiplayer_authority():
		await get_tree().process_frame
		var canvas = get_node_or_null("PlayerCanvas")
		if canvas:
			var ui = Control.new()
			ui.set_script(preload("res://scripts/dash_ui.gd"))
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
	
	if is_hypnotized or is_jailed:
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

func get_closest_interactable() -> Node3D:
	var closest: Node3D = null
	var min_dist: float = 3.0
	
	# Priority 1: Hypnotized Thieves
	var spawned = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects")
	if spawned:
		for player in spawned.get_children():
			if player != self and player.get("team_index") == 0 and player.get("is_hypnotized"):
				var dist = global_position.distance_to(player.global_position)
				if dist < min_dist:
					closest = player
					min_dist = dist
					
	if closest: return closest
	
	# Priority 2: Artifacts
	var artifacts = get_tree().get_nodes_in_group("artifact")
	for art in artifacts:
		if not art.get("is_carried"):
			var dist = global_position.distance_to(art.global_position)
			if dist < min_dist:
				closest = art
				min_dist = dist
				
	return closest

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
		# The host takes over movement to march the thief to jail
		if multiplayer.is_server():
			if active_rescuer_id != -1:
				var rescuer = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(active_rescuer_id))
				if rescuer and rescuer.global_position.distance_to(global_position) <= 4.0:
					rescue_progress += delta
					rpc("sync_rescue_progress", rescue_progress)
					
					if rescue_progress >= RESCUE_TIME_REQUIRED:
						active_rescuer_id = -1
						rescue_progress = 0.0
						rpc("sync_rescue_progress", 0.0)
						rpc("rescue_successful")
				else:
					active_rescuer_id = -1
					
			if active_rescuer_id != -1: # Halted by rescuer
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			else:
				var dist_to_target = global_position.distance_to(jail_walk_target)
				
				# When close enough to the walk target, teleport into the cell
				if dist_to_target < 1.5:
					rpc("on_jailed", jail_cell_target)
					velocity.x = 0
					velocity.z = 0
				else:
					var next_pos = nav_agent.get_next_path_position()
					var dir_to_next = global_position.direction_to(next_pos)
					dir_to_next.y = 0
					dir_to_next = dir_to_next.normalized()
					
					velocity.x = dir_to_next.x * (SPEED * 0.4)
					velocity.z = dir_to_next.z * (SPEED * 0.4)
					
					if dir_to_next.length_squared() > 0.01:
						var target_transform = transform.looking_at(global_position + dir_to_next, Vector3.UP)
						transform = transform.interpolate_with(target_transform, 5.0 * delta)
		return
		
	# Override base class movement to apply weight penalty
	var speed_mult = 1.0
	if carried_artifact:
		speed_mult = carried_artifact.weight_penalty
		
	if direction:
		velocity.x = direction.x * (SPEED * speed_mult)
		velocity.z = direction.z * (SPEED * speed_mult)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * speed_mult)
		velocity.z = move_toward(velocity.z, 0, SPEED * speed_mult)
	
func _process(delta):
	if is_multiplayer_authority() and not is_hypnotized and not is_jailed:
		var target = null
		if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
			target = current_interact_target
		else:
			target = get_closest_interactable()
			
		_update_outlines(target)
		
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
	
	# Compute visual speed (works for both local authority and remote clients observing)
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
		target_alpha = 0.1
	else:
		target_alpha = 1.0
		
	# Smoothly tween the alpha for nice visual flair
	current_alpha = lerp(current_alpha, target_alpha, 8.0 * delta)
	
	_apply_alpha_to_model(self, current_alpha)
func _apply_alpha_to_model(node: Node, alpha: float):
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_surface_override_material(i)
			if not mat:
				var mesh_mat = node.mesh.surface_get_material(i)
				if mesh_mat:
					mat = mesh_mat.duplicate()
					node.set_surface_override_material(i, mat)
			
			if mat and mat is BaseMaterial3D:
				
				if not mat.has_meta("orig_color"):
					mat.set_meta("orig_color", mat.albedo_color)
				
				var base_color = mat.get_meta("orig_color")
				if base_color == null: base_color = Color.WHITE
				
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.95 else BaseMaterial3D.TRANSPARENCY_DISABLED
				
				if is_highlighted:
					mat.albedo_color = Color(1.0, 1.0, 0.4, alpha)
					mat.emission_enabled = true
					mat.emission = Color(0.4, 0.4, 0.0)
				elif is_hypnotized:
					mat.albedo_color = Color(1.0, 0.2, 0.8, alpha)
					mat.emission_enabled = false
				else:
					mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, alpha)
					mat.emission_enabled = false
			
	for child in node.get_children():
		if child.name == "InteractionArea": continue
		_apply_alpha_to_model(child, alpha)

@rpc("any_peer", "call_local")
func on_captured():
	if is_hypnotized: return
	is_hypnotized = true
	
	collision_layer = 8 # Move to Layer 4
	collision_mask = 5  # Collide with World (1) and Normal Thieves (3)
	
	if carried_artifact:
		if multiplayer.is_server():
			carried_artifact.rpc("drop")
		carried_artifact = null
	
	# EVERY peer must update authority, otherwise clients will spam unauthorized sync data
	set_multiplayer_authority(1)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
	
	# Only the host enforces the movement routing
	if multiplayer.is_server():
		var jails = get_tree().get_nodes_in_group("jail")
		if jails.size() > 0:
			var jail = jails[0]
			var walk_pos = jail.get_node("WalkTarget").global_position
			var cell_pos = jail.get_node("CellTarget").global_position
			update_jail_targets(walk_pos, cell_pos)
			
		GameManager.rpc("thief_captured")

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

@rpc("any_peer", "call_local")
func rescue_successful():
	if not is_hypnotized: return
	
	is_hypnotized = false
	
	collision_layer = 4 # Back to Layer 3
	collision_mask = 15 # Collide with 1, 2, 3, and 4
	
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0
	
	# All peers update authority so the client can move again
	var peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
		
	if multiplayer.is_server():
		GameManager.rpc("thief_rescued")

@rpc("any_peer", "call_local")
func on_jailed(cell_pos: Vector3):
	is_hypnotized = false
	is_jailed = true
	collision_layer = 4 # Back to Layer 3
	collision_mask = 15 # Collide with 1, 2, 3, and 4
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0
	
	global_position = cell_pos
	
	# All peers update authority so the client can move inside the cell
	var peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

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

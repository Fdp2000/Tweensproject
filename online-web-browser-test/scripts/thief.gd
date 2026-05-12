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
var jail_target: Vector3 = Vector3(0, 0, 0) # Placeholder jail coordinate
var last_pos: Vector3 = Vector3.ZERO
var nav_agent: NavigationAgent3D

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
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
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
	
	# Remove old outline
	if last_outlined_target and is_instance_valid(last_outlined_target):
		if last_outlined_target.has_node("MeshInstance3D"):
			last_outlined_target.get_node("MeshInstance3D").material_overlay = null
			
	last_outlined_target = target
	
	# Add new outline
	if target and is_instance_valid(target):
		if not outline_mat:
			outline_mat = StandardMaterial3D.new()
			outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			outline_mat.albedo_color = Color(1.0, 1.0, 0.2, 0.5) # Yellowish highlight
			outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			
		if target.has_node("MeshInstance3D"):
			target.get_node("MeshInstance3D").material_overlay = outline_mat

func on_artifact_pickup(artifact):
	carried_artifact = artifact

func get_carried_artifact() -> Node3D:
	return carried_artifact

func update_jail_target(jail_pos: Vector3):
	jail_target = jail_pos
	if nav_agent:
		nav_agent.target_position = jail_target

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
				var dist_to_target = global_position.distance_to(jail_target)
				if dist_to_target < 1.0:
					velocity.x = 0
					velocity.z = 0
				else:
					var dir_to_next = global_position.direction_to(jail_target)
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
	if is_hypnotized:
		if has_node("MeshInstance3D"):
			var mat = $MeshInstance3D.get_surface_override_material(0)
			if mat:
				mat.albedo_color = Color(1.0, 0.2, 0.8, 1.0) # Bright Purple/Pink
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		return
	
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
				
		if Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
		
	if stationary_time >= INVISIBLE_TIME:
		target_alpha = 0.1
	else:
		target_alpha = 1.0
		
	# Smoothly tween the alpha for nice visual flair
	current_alpha = lerp(current_alpha, target_alpha, 8.0 * delta)
	
	if has_node("MeshInstance3D"):
		var mat = $MeshInstance3D.get_surface_override_material(0)
		if mat:
			if current_alpha < 0.99:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			# Keep the inherited team color for the Thief, but update alpha
			mat.albedo_color = Color(team_color.r, team_color.g, team_color.b, current_alpha)

@rpc("any_peer", "call_local")
func on_captured():
	if is_hypnotized: return
	is_hypnotized = true
	
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
		var jails = get_tree().get_nodes_in_group("jail_zone")
		if jails.size() > 0:
			var jail = jails[0]
			if jail.has_node("WalkTarget"):
				update_jail_target(jail.get_node("WalkTarget").global_position)
			
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
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0
	
	global_position = cell_pos
	
	# All peers update authority so the client can move inside the cell
	var peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

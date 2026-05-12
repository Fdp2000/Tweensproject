extends "res://scripts/player.gd"

var stationary_time = 0.0
const INVISIBLE_TIME = 2.0
var current_alpha = 1.0
var target_alpha = 1.0
var carried_artifact: Node3D = null
var is_hypnotized: bool = false
var is_rescue_halted: bool = false
var is_jailed: bool = false
var jail_target: Vector3 = Vector3(0, 0, 0) # Placeholder jail coordinate
var last_pos: Vector3 = Vector3.ZERO
var nav_agent: NavigationAgent3D

var is_rescuing: bool = false
var rescue_target: Node3D = null
var rescue_timer: float = 0.0
const RESCUE_TIME_REQUIRED = 2.0

func _ready():
	super._ready()
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	add_child(nav_agent)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if is_hypnotized or is_jailed: return # No inputs while hypnotized or interacting while jailed
	super._unhandled_input(event)
	
	# Interact/Pickup/Drop/Rescue
	if event is InputEventKey and event.physical_keycode == KEY_E:
		if event.pressed and not event.echo:
			if carried_artifact: _try_drop()
			else: _try_interact()
		elif not event.pressed:
			_cancel_rescue()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if carried_artifact: _try_drop()
			else: _try_interact()
		else:
			_cancel_rescue()

func _try_drop():
	if carried_artifact:
		carried_artifact.rpc("drop")
		carried_artifact = null

func _cancel_rescue():
	if is_rescuing and rescue_target:
		rescue_target.rpc_id(1, "set_rescue_halt", false)
		rescue_target = null
		is_rescuing = false
		rescue_timer = 0.0

func _try_interact():
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + Vector3(0, 1.0, 0)
	var forward_dir = -camera.global_transform.basis.z.normalized()
	var ray_end = ray_start + forward_dir * 3.5
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		if result.collider.has_method("request_pickup"):
			result.collider.rpc_id(1, "request_pickup", multiplayer.get_unique_id())
		elif result.collider is CharacterBody3D and result.collider.get("team_index") == 0 and result.collider.get("is_hypnotized") and not result.collider.get("is_jailed"):
			rescue_target = result.collider
			is_rescuing = true
			rescue_timer = 0.0
			rescue_target.rpc_id(1, "set_rescue_halt", true)

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
			if is_rescue_halted:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			else:
				var dir_to_next = Vector3.ZERO
				if nav_agent and not nav_agent.is_navigation_finished():
					var next_pos = nav_agent.get_next_path_position()
					dir_to_next = global_position.direction_to(next_pos)
				else:
					# Fallback to straight line
					dir_to_next = global_position.direction_to(jail_target)
					
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
	if is_hypnotized: return
	
	if is_rescuing and rescue_target:
		if global_position.distance_to(rescue_target.global_position) > 4.0:
			_cancel_rescue()
		else:
			rescue_timer += delta
			if rescue_timer >= RESCUE_TIME_REQUIRED:
				rescue_target.rpc_id(1, "rescue_successful")
				_cancel_rescue()
	
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
			mat.albedo_color.a = current_alpha

@rpc("any_peer", "call_local")
func on_captured():
	if is_hypnotized: return
	is_hypnotized = true
	
	if carried_artifact:
		if multiplayer.is_server():
			carried_artifact.rpc("drop")
		carried_artifact = null
	
	# The host takes over movement authority to enforce walking to jail
	if multiplayer.is_server():
		set_multiplayer_authority(1)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(1)
		GameManager.rpc("thief_captured")

@rpc("any_peer", "call_local")
func set_rescue_halt(halted: bool):
	if not multiplayer.is_server(): return
	is_rescue_halted = halted

@rpc("any_peer", "call_local")
func rescue_successful():
	if not multiplayer.is_server(): return
	if not is_hypnotized: return
	
	is_hypnotized = false
	is_rescue_halted = false
	
	var peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
		
	GameManager.rpc("thief_rescued")

@rpc("any_peer", "call_local")
func on_jailed(cell_pos: Vector3):
	is_hypnotized = false
	is_jailed = true
	is_rescue_halted = false
	
	global_position = cell_pos
	
	if multiplayer.is_server():
		var peer_id = str(name).to_int()
		set_multiplayer_authority(peer_id)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

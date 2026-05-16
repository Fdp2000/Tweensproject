extends CharacterBody3D

const SPEED = 6.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mobile_input: Node = null
var ping_manager: Node = null

var mouse_sensitivity: float = 2.0 
var target_shoulder_x = 1.0
var disable_body_rotation: bool = false

var player_name: String = ""
@export var team_index: int = 0
var team_color: Color = Color.WHITE

var kills: int = 0
var deaths: int = 0
var hits: int = 0

# Network sync targets for smooth interpolation
var sync_target_position: Vector3 = Vector3.ZERO
var sync_target_rotation: Vector3 = Vector3.ZERO
var sync_velocity: Vector3 = Vector3.ZERO # Velocity for Dead Reckoning
var _spawn_relay_ready: bool = false 

@onready var pitch_pivot = $PitchPivot
@onready var spring_arm = $PitchPivot/SpringArm3D
@onready var camera = $PitchPivot/SpringArm3D/Camera3D

func _enter_tree() -> void:
	var id = str(name).to_int()
	set_multiplayer_authority(id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(id)
		
func _exit_tree() -> void:
	if has_node("MultiplayerSynchronizer"):
		get_node("MultiplayerSynchronizer").public_visibility = false

func _ready():
	await get_tree().process_frame
	
	if not is_inside_tree() or multiplayer == null:
		return
	
	if multiplayer.is_server():
		_apply_team_colors()
	else:
		rpc_id(1, "request_team_color")
	
	if is_multiplayer_authority():
		var client_ui = get_tree().root.get_node_or_null("World/main/VBoxContainer/Clients/ClientUI")
		if client_ui and client_ui.local_player_name != "":
			player_name = client_ui.local_player_name
		else:
			player_name = "Player " + str(get_index() + 1)
		_sync_name.rpc(player_name)
	
	var cam_shape = SphereShape3D.new()
	cam_shape.radius = 0.5
	spring_arm.shape = cam_shape
	spring_arm.margin = 0.1
	spring_arm.add_excluded_object(get_rid())
	
	if is_multiplayer_authority():
		camera.current = true
		
		# ONLY cull the head for COPS (Team 1)
		if team_index == 1:
			var head_parts = ["Head", "Nose", "Eyes"]
			for part_name in head_parts:
				var part = find_child(part_name, true, false)
				if part and part is VisualInstance3D:
					part.layers = 2
			camera.cull_mask = ~(1 << 1) # Ignore Layer 2
		
		if not is_mobile_device():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		var canvas = CanvasLayer.new()
		canvas.name = "PlayerCanvas"
		add_child(canvas)
		
		# Replace setup_mobile_ui() with:
		mobile_input = MobileInputManager.new()
		add_child(mobile_input)
		mobile_input.setup(self)
	else:
		camera.current = false
	# (Everyone needs to be able to render a ping)
	ping_manager = PlayerPingManager.new()
	add_child(ping_manager)
	ping_manager.setup(self)

	if has_node("MultiplayerSynchronizer"):
		var sync_node = get_node("MultiplayerSynchronizer")
		if multiplayer.is_server():
			sync_node.public_visibility = false
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_inside_tree():
					sync_node.public_visibility = true
			)
		else:
			sync_node.public_visibility = true
			
	# Activate the relay flag for BOTH server and clients
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_inside_tree():
			_spawn_relay_ready = true
	)

func _set_layer_recursive(node: Node, layer: int):
	if node is VisualInstance3D:
		node.layers = layer
	for child in node.get_children():
		_set_layer_recursive(child, layer)

func _apply_team_colors():
	if team_index == 1:
		team_color = Color(0.4, 0.6, 1.0) # Light Blue (Cop)
	else:
		team_color = Color(1.0, 0.4, 0.4) # Light Red (Thief)
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color
	if has_node("MeshInstance3D"):
		$MeshInstance3D.set_surface_override_material(0, mat)

@rpc("any_peer", "call_remote", "reliable")
func request_team_color():
	if multiplayer.is_server():
		var requester = multiplayer.get_remote_sender_id()
		rpc_id(requester, "sync_team", team_index)

@rpc("any_peer", "call_local", "reliable")
func sync_team(assigned_team: int):
	team_index = assigned_team
	_apply_team_colors()

func _add_custom_mobile_ui(_mobile_ui: Control, _ui_scale: float):
	pass

func _input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if not is_mobile_device():
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_mobile_device() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventMouseMotion and not is_mobile_device() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var actual_sens = mouse_sensitivity * 0.001
		
		if disable_body_rotation:
			pitch_pivot.rotate_y(-event.relative.x * actual_sens)
		else:
			rotate_y(-event.relative.x * actual_sens)
			
		pitch_pivot.rotate_x(-event.relative.y * actual_sens)
		pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, -1.0, 1.0)
		
func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("secondary_action"):
		toggle_camera()

func toggle_camera():
	if target_shoulder_x == 1.0:
		target_shoulder_x = -1.0
	else:
		target_shoulder_x = 1.0


# --- SMOOTH INTERPOLATION (Visual frames) ---
func _process(delta):
	# Visual smoothing for remote network players
	if not is_multiplayer_authority():
		if sync_target_position != Vector3.ZERO:
			
			# --- DEAD RECKONING ---
			# Predict where the player is going by moving the target forward 
			# using the exact velocity they had when they sent the packet!
			sync_target_position += sync_velocity * delta
			# ----------------------
			
			var dist = global_position.distance_to(sync_target_position)
			
			# If the distance is huge (lag spike or teleport), snap them instantly
			if dist > 3.0:
				global_position = sync_target_position
			else:
				# Now that the target never stops moving, standard lerp is buttery smooth!
				global_position = global_position.lerp(sync_target_position, 15.0 * delta)
			
			# Slerp Rotation smoothly
			var current_quat = Quaternion(transform.basis)
			var target_quat = Quaternion(Basis.from_euler(sync_target_rotation))
			var new_quat = current_quat.slerp(target_quat, 15.0 * delta)
			transform.basis = Basis(new_quat)
			
	# Camera shoulder toggle smoothing (Local Player Only)
	else:
		var current_angle = spring_arm.rotation.y
		var target_angle = atan2(target_shoulder_x, 4.711)
		var new_angle = lerp_angle(current_angle, target_angle, 15.0 * delta)
		spring_arm.rotation.y = new_angle
		camera.rotation.y = -new_angle


# --- MOVEMENT REMAINS IN PHYSICS ---
func _physics_process(delta):
	# FIX: Send our position, rotation, AND VELOCITY to others!
	if is_multiplayer_authority() and _spawn_relay_ready:
		rpc("relay_position", global_position, rotation, velocity)
		
	if not is_multiplayer_authority():
		# Initialize the sync target if it's zero
		if sync_target_position == Vector3.ZERO:
			sync_target_position = global_position
			sync_target_rotation = rotation
			
		_custom_physics_process(delta, Vector3.ZERO)
		return 
	
	if not is_on_floor(): velocity.y -= gravity * delta

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if mobile_input and mobile_input.get_joystick_vector() != Vector2.ZERO:
		input_dir = mobile_input.get_joystick_vector()
		
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	_custom_physics_process(delta, direction)

	move_and_slide()


func _custom_physics_process(_delta, direction):
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)


# --- UPDATED RPC: EXPECTS 3 ARGUMENTS ---
@rpc("any_peer", "call_remote", "unreliable")
func relay_position(pos: Vector3, rot: Vector3, vel: Vector3):
	if not is_inside_tree(): return
	
	# Server acts as a relay tower and forwards all 3 arguments
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		for peer in multiplayer.get_peers():
			if peer != sender_id:
				rpc_id(peer, "relay_position", pos, rot, vel)
				
	if is_multiplayer_authority(): return
	
	# Apply the newly received real network data
	sync_target_position = pos
	sync_target_rotation = rot
	sync_velocity = vel 
# ----------------------------------------


@rpc("any_peer", "call_local", "reliable")
func _set_spawn_position(pos: Vector3):
	global_position = pos

@rpc("any_peer", "call_local")
func _sync_name(n: String):
	player_name = n

func is_mobile_device() -> bool:
	if OS.has_feature("mobile"): return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"): return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var ua = JavaScriptBridge.eval("navigator.userAgent")
		if ua:
			for m in ["Android", "iPhone", "iPad", "iPod", "Mobile"]:
				if m in ua: return true
	return false


# ================================
# CAMERA PING SYSTEM
# ================================

@rpc("any_peer", "call_local")
func get_pinged():
	if ping_manager:
		ping_manager.trigger_ping()

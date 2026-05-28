extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mobile_input: Node = null
var ping_manager: Node = null

var mouse_sensitivity: float = 2.0 
var target_shoulder_x = 1.0
var disable_body_rotation: bool = false

var player_name: String = ""
var allow_arrow_keys: bool = false
@export var team_index: int = 0
var team_color: Color = Color.WHITE

var kills: int = 0
var deaths: int = 0
var hits: int = 0

# Network sync targets for smooth interpolation
@export var sync_target_position: Vector3 = Vector3.ZERO
@export var sync_target_rotation: Vector3 = Vector3.ZERO
@export var sync_velocity: Vector3 = Vector3.ZERO # Velocity for Dead Reckoning
var _spawn_relay_ready: bool = false 
#cutscene extra
var controls_enabled: bool = true

@onready var pitch_pivot = $PitchPivot
@onready var spring_arm = $PitchPivot/SpringArm3D
@onready var camera = $PitchPivot/SpringArm3D/Camera3D

#cutscene extra
func enable_controls(value: bool):
	controls_enabled = value

func _enter_tree() -> void:
	var id = str(name).to_int()
	set_multiplayer_authority(id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(id)
		
func _exit_tree() -> void:
	if has_node("MultiplayerSynchronizer"):
		get_node("MultiplayerSynchronizer").public_visibility = false

func _ready():
	if not is_inside_tree() or multiplayer == null:
		return
	
	if multiplayer.is_server():
		_apply_team_colors()
	else:
		rpc_id(1, "request_initial_sync")
	
	var cam_shape = SphereShape3D.new()
	cam_shape.radius = Balance.camera_wall_radius
	spring_arm.shape = cam_shape
	spring_arm.margin = 0.1
	spring_arm.add_excluded_object(get_rid())
	
	if is_multiplayer_authority():
		var cutscene_manager = get_tree().get_root().find_child("CutsceneManager", true, false)

		if cutscene_manager and cutscene_manager.get("intro_running"):
			camera.current = false
		else:
			if spring_arm:
				camera.position.z = spring_arm.spring_length
			camera.current = true
			
			# Hide visuals for 1 frame to prevent the chameleon closeup flash
			visible = false
			get_tree().process_frame.connect(func():
				if is_inside_tree():
					visible = true
			, CONNECT_ONE_SHOT)
		
		# Tell the local camera to ALWAYS ignore Layer 10 (Bit value 512).
		# We will put the Cop's head on this layer later!
		camera.cull_mask = ~(1 << 9) 
		
		if not is_mobile_device():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		var canvas = CanvasLayer.new()
		canvas.name = "PlayerCanvas"
		add_child(canvas)
		
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
		sync_node.public_visibility = true
			
	_spawn_relay_ready = true

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
		
	# --- THE FIX: HANDLE HEAD VISIBILITY HERE ---
	if team_index == 1:
		# We intentionally leave "Head2" alone so it keeps casting shadows!
		var head_parts = ["Head", "Nose", "Eyes"] 
		for part_name in head_parts:
			var part = find_child(part_name, true, false)
			if part and part is VisualInstance3D:
				if is_multiplayer_authority():
					# Local Cop: Move to Layer 10 (Camera ignores this)
					part.layers = 512 
				else:
					# Remote Cop: Ensure it's on Layer 1 (Visible to everyone)
					part.layers = 1

@rpc("any_peer", "call_remote", "reliable")
func request_initial_sync():
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	rpc_id(sender, "_set_spawn_position", global_position)
	rpc_id(sender, "sync_team", team_index)
	rpc_id(sender, "_sync_name", player_name)



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
			
			# FIX: Only recapture the mouse if the DevPanel is NOT visible!
			if DevPanel and not DevPanel.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventMouseMotion and not is_mobile_device() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		# --- THE NECK LOCK GATE (UPDATED) ---
		if get("is_charging") == true:
			# Kill the left/right rotation, but allow up/down!
			event.relative.x = 0.0 
		# ------------------------------------
		
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

@export var skin_materials: Array[Material]
@export var skin_mesh_paths: Array[NodePath]

@rpc("any_peer", "call_local", "reliable")
func apply_skin(skin_index: int) -> void:
	print("apply_skin called on: ", name, " index: ", skin_index)

	if skin_materials.is_empty():
		print("No skin materials assigned on ", name)
		return

	skin_index = clampi(skin_index, 0, skin_materials.size() - 1)
	var selected_material := skin_materials[skin_index]

	for path in skin_mesh_paths:
		var mesh := get_node_or_null(path) as MeshInstance3D

		if mesh:
			mesh.material_override = null

			for i in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(i, selected_material)

			print("Applied skin to: ", mesh.name)
		else:
			print("Skin mesh path missing on ", name, ": ", path)
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
			var current_scale = scale
			var current_quat = Quaternion(transform.basis.orthonormalized())
			var target_quat = Quaternion(Basis.from_euler(sync_target_rotation).orthonormalized())
			var new_quat = current_quat.slerp(target_quat, 15.0 * delta)
			transform.basis = Basis(new_quat)
			scale = current_scale
			
	# Camera shoulder toggle smoothing (Local Player Only)
	else:
		var current_angle = spring_arm.rotation.y
		var target_angle = atan2(target_shoulder_x, Balance.thief_spring_arm_length)
		var new_angle = lerp_angle(current_angle, target_angle, 15.0 * delta)
		spring_arm.rotation.y = new_angle
		camera.rotation.y = -new_angle


# --- MOVEMENT REMAINS IN PHYSICS ---
func _physics_process(delta):
	#Cutscene Extra
	if not controls_enabled:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	# FIX: Keep sync variables updated so the MultiplayerSynchronizer can automatically broadcast them!
	if is_multiplayer_authority() and _spawn_relay_ready:
		sync_target_position = global_position
		sync_target_rotation = rotation
		sync_velocity = velocity
		
	if not is_multiplayer_authority():
		# Initialize the sync target if it's zero
		if sync_target_position == Vector3.ZERO:
			sync_target_position = global_position
			sync_target_rotation = rotation
			
		_custom_physics_process(delta, Vector3.ZERO)
		return 
	
	if not is_on_floor(): velocity.y -= gravity * delta

	var input_dir = Vector2.ZERO
	if allow_arrow_keys:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	else:
		# Only allow WASD keys manually if arrow keys are disabled
		var left = 1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0
		var right = 1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0
		var up = 1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0
		var down = 1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0
		input_dir = Vector2(right - left, down - up).normalized()
		
	if mobile_input and mobile_input.get_joystick_vector() != Vector2.ZERO:
		input_dir = mobile_input.get_joystick_vector()
		
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	_custom_physics_process(delta, direction)

	move_and_slide()


func _custom_physics_process(_delta, direction):
	if direction:
		velocity.x = direction.x * 6.5 # Hardcoded fallback
		velocity.z = direction.z * 6.5
	else:
		velocity.x = move_toward(velocity.x, 0, 6.5 * 60.0 * _delta) # Hardcoded fallback
		velocity.z = move_toward(velocity.z, 0, 6.5 * 60.0 * _delta)

# ----------------------------------------


@rpc("any_peer", "call_local")
func _set_spawn_position(pos: Vector3):
	global_position = pos
	
	# FIX: Hide the player for 1 frame when teleporting to prevent the camera from colliding 
	# with the old environment and flashing a closeup of the chameleon's face!
	if is_multiplayer_authority() and is_inside_tree():
		visible = false
		get_tree().process_frame.connect(func():
			if is_inside_tree():
				visible = true
		, CONNECT_ONE_SHOT)


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

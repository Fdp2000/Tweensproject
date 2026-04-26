extends CharacterBody3D

const SPEED = 6.5
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Dash variables
var is_dashing = false
var dash_time_left = 0.0
var dash_cooldown_left = 0.0
var dash_penalty_left = 0.0
const DASH_DURATION = 0.18
const DASH_SPEED = 25.0
const DASH_COOLDOWN = 1.3
const DASH_PENALTY_DURATION = 0.1
const DASH_PENALTY_SPEED = 2.0 # Move very slow during penalty
var dash_direction = Vector3.ZERO

var target_h_offset = 1.0
var mouse_sensitivity: float = 2.0 # User-friendly number
var sens_popup_timer = 0.0
var show_room_ui = false
var look_touch_index: int = -1
var last_look_pos: Vector2 = Vector2.ZERO

var dash_ui_ref: Control
var shoot_ui_ref: Control
var is_mobile_shooting: bool = false

@export var show_target_marker: bool = true

var team_color: Color = Color.WHITE
var plunger_color: Color = Color("ff1d1d")
var player_name: String = ""
var kills: int = 0
var deaths: int = 0
var hits: int = 0
@export var team_index: int = 0


@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D

func _enter_tree() -> void:
	var id = str(name).to_int()
	set_multiplayer_authority(id)
	$MultiplayerSynchronizer.set_multiplayer_authority(id)

func _ready():
	# Wait one frame to ensure authority is synced across the network
	await get_tree().process_frame
	
		# If I am the Server, I already know the truth. Apply it immediately!
	if multiplayer.is_server():
		_apply_team_colors()
	# If I am a Client, I must ask the Server what color this player is!
	else:
		rpc_id(1, "request_team_color")
	
	# Assign team color based on join order (sibling index)
	if team_index == 0:
		team_color = Color(0.4, 0.6, 1.0) # Light Blue
		plunger_color = Color("1d56ffff") # Vivid Blue
	else:
		team_color = Color(1.0, 0.4, 0.4) # Light Red
		plunger_color = Color("ff1d1d") # Vivid Red
	
	# Set player name from menu input or default
	if is_multiplayer_authority():
		var client_ui = get_tree().root.get_node_or_null("World/main/VBoxContainer/Clients/ClientUI")
		if client_ui and client_ui.local_player_name != "":
			player_name = client_ui.local_player_name
		else:
			player_name = "Player " + str(get_index() + 1)
		# Sync name to all peers
		_sync_name.rpc(player_name)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color
	$MeshInstance3D.set_surface_override_material(0, mat)
	
	if is_multiplayer_authority():
		camera.current = true
		if not is_mobile_device():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Dynamically create a simple dot crosshair for the local player
		var canvas = CanvasLayer.new()
		canvas.name = "PlayerCanvas"
		var crosshair = ColorRect.new()
		crosshair.color = Color(1, 1, 1, 0.8) # Slightly transparent white
		crosshair.custom_minimum_size = Vector2(4, 4)
		crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		canvas.add_child(crosshair)
		
		# Create the dynamic dash cooldown ring
		var dash_ui = Control.new()
		dash_ui.set_script(preload("res://scripts/dash_ui.gd"))
		dash_ui.custom_minimum_size = Vector2(40, 40)
		dash_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		dash_ui.position.y -= 80 # Move up from the bottom edge
		dash_ui.name = "DashUI"
		dash_ui_ref = dash_ui
		canvas.add_child(dash_ui)
		
		# Create the dynamic shoot cooldown ring
		var shoot_ui = Control.new()
		shoot_ui.set_script(preload("res://scripts/dash_ui.gd"))
		# Color based on team
		if team_index == 0: # Blue team
			shoot_ui.ring_color = Color(0.2, 0.4, 1.0, 0.9)
			shoot_ui.ready_color = Color(0.2, 0.4, 1.0, 0.9)
		else: # Red team
			shoot_ui.ring_color = Color(1.0, 0.2, 0.2, 0.9)
			shoot_ui.ready_color = Color(1.0, 0.2, 0.2, 0.9)
		shoot_ui.custom_minimum_size = Vector2(40, 40)
		shoot_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		shoot_ui.position.x -= 60 # Move in from the right edge
		shoot_ui.position.y -= 80 # Move up from the bottom edge
		shoot_ui.name = "ShootUI"
		shoot_ui_ref = shoot_ui
		canvas.add_child(shoot_ui)
		
		# Create the sensitivity popup label
		var sens_label = Label.new()
		sens_label.name = "SensLabel"
		sens_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		sens_label.position = Vector2(20, 20)
		sens_label.modulate.a = 0.0 # Hidden by default
		sens_label.add_theme_font_size_override("font_size", 24)
		# Add a slight black outline so it's readable anywhere
		sens_label.add_theme_color_override("font_outline_color", Color.BLACK)
		sens_label.add_theme_constant_override("outline_size", 4)
		canvas.add_child(sens_label)
		
		# Create the Scoreboard overlay (Hidden by default, toggled with TAB)
		var score_bg = ColorRect.new()
		score_bg.name = "ScoreboardBackground"
		score_bg.color = Color(0, 0, 0, 0.75)
		score_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		score_bg.hide()
		canvas.add_child(score_bg)
		
		# Room Key label (top left)
		var room_key_label = Label.new()
		room_key_label.name = "RoomKeyLabel"
		room_key_label.text = "Room Key: ..."
		if is_mobile_device():
			room_key_label.add_theme_font_size_override("font_size", 32)
		else:
			room_key_label.add_theme_font_size_override("font_size", 20)
		room_key_label.add_theme_color_override("font_outline_color", Color.BLACK)
		room_key_label.add_theme_constant_override("outline_size", 4)
		room_key_label.position = Vector2(20, 15)
		score_bg.add_child(room_key_label)
		
		# Scoreboard container (centered)
		var scoreboard = VBoxContainer.new()
		scoreboard.name = "Scoreboard"
		scoreboard.anchor_left = 0.5
		scoreboard.anchor_right = 0.5
		scoreboard.anchor_top = 0.5
		scoreboard.anchor_bottom = 0.5
		scoreboard.offset_left = -340
		scoreboard.offset_right = 340
		scoreboard.offset_top = -200
		scoreboard.offset_bottom = 200
		scoreboard.add_theme_constant_override("separation", 5)
		scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
		score_bg.add_child(scoreboard)
		
		# Team headers row
		var header_row = HBoxContainer.new()
		header_row.name = "HeaderRow"
		header_row.add_theme_constant_override("separation", 40)
		header_row.alignment = BoxContainer.ALIGNMENT_CENTER
		scoreboard.add_child(header_row)
		
		var red_header = Label.new()
		red_header.name = "RedHeader"
		red_header.text = "TEAM RED: 0"
		red_header.add_theme_font_size_override("font_size", 28)
		red_header.add_theme_color_override("font_color", Color("ff4444"))
		red_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		red_header.custom_minimum_size.x = 300
		header_row.add_child(red_header)
		
		var blue_header = Label.new()
		blue_header.name = "BlueHeader"
		blue_header.text = "TEAM BLUE: 0"
		blue_header.add_theme_font_size_override("font_size", 28)
		blue_header.add_theme_color_override("font_color", Color("4488ff"))
		blue_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blue_header.custom_minimum_size.x = 300
		header_row.add_child(blue_header)
		
		# Team columns row
		var columns_row = HBoxContainer.new()
		columns_row.name = "ColumnsRow"
		columns_row.add_theme_constant_override("separation", 40)
		columns_row.alignment = BoxContainer.ALIGNMENT_CENTER
		scoreboard.add_child(columns_row)
		
		var red_column = VBoxContainer.new()
		red_column.name = "RedColumn"
		red_column.custom_minimum_size = Vector2(300, 300)
		red_column.add_theme_constant_override("separation", 4)
		columns_row.add_child(red_column)
		
		var blue_column = VBoxContainer.new()
		blue_column.name = "BlueColumn"
		blue_column.custom_minimum_size = Vector2(300, 300)
		blue_column.add_theme_constant_override("separation", 4)
		columns_row.add_child(blue_column)
		
		add_child(canvas)
		
		# --- MOBILE CONTROLS ---
		if is_mobile_device():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var screen_size = DisplayServer.window_get_size()
			# Smaller, more conservative scaling (reference height 720p)
			var ui_scale = min(screen_size.x, screen_size.y) / 720.0 
			ui_scale = clamp(ui_scale, 0.8, 2.0) 
			var mobile_ui = Control.new()
			mobile_ui.name = "MobileUI"
			mobile_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			mobile_ui.mouse_filter = Control.MOUSE_FILTER_PASS
			canvas.add_child(mobile_ui)
			
			# Look Area (Background for rotation, handles touches that buttons don't)
			var look_area = Control.new()
			look_area.name = "LookArea"
			look_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			look_area.mouse_filter = Control.MOUSE_FILTER_STOP
			look_area.gui_input.connect(func(event):
				if event is InputEventScreenTouch:
					if event.pressed:
						if look_touch_index == -1:
							look_touch_index = event.index
							last_look_pos = event.position
					elif event.index == look_touch_index:
						look_touch_index = -1
				
				if event is InputEventScreenDrag and event.index == look_touch_index:
					var drag_relative = event.position - last_look_pos
					last_look_pos = event.position
					
					var actual_sens = mouse_sensitivity * 0.001
					rotate_y(-drag_relative.x * actual_sens)
					spring_arm.rotate_x(-drag_relative.y * actual_sens)
					spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.0, 1.0)
					get_viewport().set_input_as_handled()
			)
			mobile_ui.add_child(look_area)
			
			var joystick = load("res://scripts/virtual_joystick.gd").new()
			joystick.name = "Joystick"
			# Apply scale to joystick (Increased by 40%)
			var joy_size = 200 * ui_scale
			joystick.custom_minimum_size = Vector2(joy_size, joy_size)
			joystick.radius = 70 * ui_scale
			joystick.anchor_top = 1.0
			joystick.anchor_bottom = 1.0
			joystick.anchor_left = 0.0
			joystick.anchor_right = 0.0
			joystick.offset_left = 40 * ui_scale
			joystick.offset_right = (40 + 200) * ui_scale
			joystick.offset_top = - (220 * ui_scale)
			joystick.offset_bottom = - (20 * ui_scale)
			mobile_ui.add_child(joystick)
			
			# Camera switch button (Increased size & moved closer to joystick)
			var cam_btn = load("res://scripts/mobile_button.gd").new()
			cam_btn.action_name = "secondary_action"
			cam_btn.button_text = "CAM"
			cam_btn.radius = 45.0 * ui_scale 
			cam_btn.base_color = Color(0.5, 0.5, 0.5, 0.4)
			cam_btn.anchor_top = 1.0
			cam_btn.anchor_bottom = 1.0
			cam_btn.anchor_left = 0.0
			cam_btn.anchor_right = 0.0
			cam_btn.offset_left = 220 * ui_scale # Moved from 300 to 220 (closer to joystick)
			cam_btn.offset_top = - (80 * ui_scale)
			cam_btn.offset_right = (220 + 80) * ui_scale
			cam_btn.offset_bottom = - (0 * ui_scale)
			mobile_ui.add_child(cam_btn)
			
			var jump_btn = load("res://scripts/mobile_button.gd").new()
			jump_btn.action_name = "ui_accept"
			jump_btn.button_text = "JUMP"
			jump_btn.radius = 52.0 * ui_scale # Was 40 (+30%)
			jump_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			jump_btn.offset_left = - (160 * ui_scale)
			jump_btn.offset_top = - (160 * ui_scale)
			jump_btn.offset_right = - (60 * ui_scale)
			jump_btn.offset_bottom = - (60 * ui_scale)
			mobile_ui.add_child(jump_btn)
			
			var shoot_btn = load("res://scripts/mobile_button.gd").new()
			shoot_btn.action_name = "mobile_shoot" # CUSTOM ACTION
			shoot_btn.button_text = "FIRE"
			shoot_btn.radius = 72.0 * ui_scale # Was 55 (+30%)
			shoot_btn.base_color = Color(1, 0.2, 0.2, 0.5)
			shoot_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			shoot_btn.offset_left = - (320 * ui_scale)
			shoot_btn.offset_top = - (240 * ui_scale)
			shoot_btn.offset_right = - (180 * ui_scale)
			shoot_btn.offset_bottom = - (100 * ui_scale)
			mobile_ui.add_child(shoot_btn)
			
			var dash_btn = load("res://scripts/mobile_button.gd").new()
			dash_btn.action_name = "dash"
			dash_btn.button_text = "DASH"
			dash_btn.radius = 52.0 * ui_scale # Was 40 (+30%)
			dash_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			dash_btn.offset_left = - (130 * ui_scale)
			dash_btn.offset_top = - (300 * ui_scale)
			dash_btn.offset_right = - (30 * ui_scale)
			dash_btn.offset_bottom = - (200 * ui_scale)
			mobile_ui.add_child(dash_btn)
			
			# Move cooldown rings inside buttons for mobile
			dash_ui.reparent(dash_btn, false)
			dash_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			shoot_ui.reparent(shoot_btn, false)
			shoot_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			# Auto-show scoreboard for host on spawn (to see room key)
			if multiplayer.get_unique_id() == 1:
				show_room_ui = true
				score_bg.visible = true
				get_tree().create_timer(5.0).timeout.connect(func():
					show_room_ui = false
					score_bg.visible = false
				)
		# DEBUG MARKER: A red sphere to show EXACTLY where the raycast hits
		var debug_mesh = SphereMesh.new()
		debug_mesh.radius = 0.1
		debug_mesh.height = 0.2
		var debug_mat = StandardMaterial3D.new()
		debug_mat.albedo_color = Color.RED
		debug_mat.flags_no_depth_test = true # See it through walls
		debug_mesh.surface_set_material(0, debug_mat)
		
		var target_marker = MeshInstance3D.new()
		target_marker.mesh = debug_mesh
		target_marker.name = "TargetMarker"
		get_tree().root.call_deferred("add_child", target_marker)
		
		# Since the client has authority over their own player, the client can just pick their own spawn point locally!
		var spawn_points = get_node_or_null("/root/World/SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var random_spawn = spawn_points.get_children().pick_random()
			global_position = random_spawn.global_position
			position.y += 1.0
		else:
			position = Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2))
			
	else:
		camera.current = false

func _input(event):
	if not is_multiplayer_authority(): return
	
	# Desktop Look Rotation (Mouse only)
	if event is InputEventMouseMotion and not is_mobile_device():
		var actual_sens = mouse_sensitivity * 0.001
		rotate_y(-event.relative.x * actual_sens)
		spring_arm.rotate_x(-event.relative.y * actual_sens)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.0, 1.0)
		return

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
		
	# Handle Scroll Wheel Sensitivity
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			mouse_sensitivity = clamp(mouse_sensitivity + 0.20, 0.2, 10)
			show_sensitivity_popup()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mouse_sensitivity = clamp(mouse_sensitivity - 0.20, 0.2, 10)
			show_sensitivity_popup()

	if event.is_action_pressed("secondary_action"):
		toggle_camera()
			
	# Web Browser Fallback: Browsers require a physical click to hide the cursor!
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not show_room_ui:
			if not is_mobile_device():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# TAB hold to show scoreboard
	if event is InputEventKey and event.physical_keycode == KEY_TAB:
		var score_bg = get_node_or_null("PlayerCanvas/ScoreboardBackground")
		if score_bg:
			if event.pressed and not event.echo:
				show_room_ui = true
				score_bg.visible = true
			elif not event.pressed:
				show_room_ui = false
				score_bg.visible = false
	


func show_sensitivity_popup():
	var label = get_node_or_null("PlayerCanvas/SensLabel")
	if label:
		label.text = "Sensitivity: %.1f" % mouse_sensitivity
		label.modulate.a = 1.0
		sens_popup_timer = 2.0

func _populate_scoreboard(score_bg: Control):
	# Update room key
	var room_label = score_bg.get_node_or_null("RoomKeyLabel")
	var client_node = get_tree().root.get_node_or_null("World/main/VBoxContainer/Clients/ClientUI/Client")
	if room_label and client_node and client_node.get("lobby"):
		room_label.text = "Room Key: " + str(client_node.lobby)
	
	# Get all players
	var spawned = get_node_or_null("/root/World/main/SpawnedObjects")
	if not spawned: return
	
	var red_kills_total = 0
	var blue_kills_total = 0
	
	# Clear existing player rows
	var red_col = score_bg.get_node_or_null("Scoreboard/ColumnsRow/RedColumn")
	var blue_col = score_bg.get_node_or_null("Scoreboard/ColumnsRow/BlueColumn")
	if not red_col or not blue_col: return
	
	for child in red_col.get_children(): child.queue_free()
	for child in blue_col.get_children(): child.queue_free()
	
	# Collect player data into arrays for sorting
	var red_players = []
	var blue_players = []
	
	for p in spawned.get_children():
		if not p is CharacterBody3D: continue
		var p_name = p.player_name if p.player_name != "" else "Player " + str(p.get_index() + 1)
		var p_kills = p.kills if p.get("kills") != null else 0
		var p_deaths = p.deaths if p.get("deaths") != null else 0
		var p_hits = p.hits if p.get("hits") != null else 0
		var p_team = p.team_index if p.get("team_index") != null else 0
		
		var data = {"name": p_name, "kills": p_kills, "deaths": p_deaths, "hits": p_hits}
		if p_team == 1:
			red_players.append(data)
			red_kills_total += p_kills
		else:
			blue_players.append(data)
			blue_kills_total += p_kills
	
	# Sort by kills descending
	red_players.sort_custom(func(a, b): return a.kills > b.kills)
	blue_players.sort_custom(func(a, b): return a.kills > b.kills)
	
	# Build rows in sorted order
	for data in red_players:
		red_col.add_child(_make_player_row(data))
	for data in blue_players:
		blue_col.add_child(_make_player_row(data))
	
	# Update team score headers
	var red_header = score_bg.get_node_or_null("Scoreboard/HeaderRow/RedHeader")
	var blue_header = score_bg.get_node_or_null("Scoreboard/HeaderRow/BlueHeader")
	if red_header: red_header.text = "TEAM RED: %d" % red_kills_total
	if blue_header: blue_header.text = "TEAM BLUE: %d" % blue_kills_total

func _make_player_row(data: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.custom_minimum_size.x = 160
	name_label.clip_text = true
	row.add_child(name_label)
	
	var kd_label = Label.new()
	kd_label.text = "K %d / HITS %d / D %d" % [data.kills, data.hits, data.deaths]
	kd_label.add_theme_font_size_override("font_size", 18)
	row.add_child(kd_label)
	
	return row

var shoot_cooldown: float = 0.0

func _physics_process(delta):
	if multiplayer.is_server():
		rpc("relay_position", global_position, rotation)
	if not is_multiplayer_authority(): return
	
	# Real-time scoreboard update
	if show_room_ui:
		var score_bg = get_node_or_null("PlayerCanvas/ScoreboardBackground")
		if score_bg:
			_populate_scoreboard(score_bg)
	
	# Smoothly lerp the camera over the shoulder
	camera.h_offset = lerp(camera.h_offset, target_h_offset, 15.0 * delta)
	
	# Fade out the sensitivity popup
	if sens_popup_timer > 0:
		sens_popup_timer -= delta
		var label = get_node_or_null("PlayerCanvas/SensLabel")
		if label:
			if sens_popup_timer <= 0:
				label.modulate.a = 0.0
			elif sens_popup_timer < 1.0:
				label.modulate.a = sens_popup_timer # smooth fade out over the last second

	if shoot_cooldown > 0:
		shoot_cooldown -= delta
		
	if dash_cooldown_left > 0:
		dash_cooldown_left -= delta
		
	# Update Dash UI
	if dash_ui_ref:
		if DASH_COOLDOWN > 0:
			dash_ui_ref.progress = 1.0 - (dash_cooldown_left / DASH_COOLDOWN)
		else:
			dash_ui_ref.progress = 1.0
			
	# Update Shoot UI
	if shoot_ui_ref:
		var effective_shoot_cd = shoot_cooldown
		var shoot_max_cd = 0.6
		if is_dashing and dash_time_left > shoot_cooldown:
			effective_shoot_cd = dash_time_left
			shoot_max_cd = DASH_DURATION
			
		if shoot_max_cd > 0:
			shoot_ui_ref.progress = 1.0 - (effective_shoot_cd / shoot_max_cd)
		else:
			shoot_ui_ref.progress = 1.0

	if not is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_dashing: 
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var joystick = get_node_or_null("PlayerCanvas/MobileUI/Joystick")
	if joystick and joystick.get_value() != Vector2.ZERO:
		input_dir = joystick.get_value()
		
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0:
			is_dashing = false
			dash_penalty_left = DASH_PENALTY_DURATION
		else:
			# Lock velocity to dash direction and speed
			velocity.x = dash_direction.x * DASH_SPEED
			velocity.z = dash_direction.z * DASH_SPEED
	else:
		# Check for Dash Trigger
		if (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("dash")) and dash_cooldown_left <= 0:
			is_dashing = true
			dash_time_left = DASH_DURATION
			dash_cooldown_left = DASH_COOLDOWN
			dash_penalty_left = 0.0 # Cancel penalty
			if direction != Vector3.ZERO:
				dash_direction = direction
			else:
				# Default to camera forward if standing still
				dash_direction = -camera.global_transform.basis.z.normalized()
				dash_direction.y = 0 # Keep it horizontal
				dash_direction = dash_direction.normalized()
				
		# Normal Movement
		if not is_dashing:
			var current_speed = SPEED
			if dash_penalty_left > 0:
				dash_penalty_left -= delta
				current_speed = DASH_PENALTY_SPEED
				
			if direction:
				velocity.x = direction.x * current_speed
				velocity.z = direction.z * current_speed
			else:
				velocity.x = move_toward(velocity.x, 0, current_speed)
				velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	# --- CONSTANT CROSSHAIR RAYCAST ---
	# We MUST use project_ray_normal to calculate the ray because the Camera3D uses "h_offset"!
	# h_offset skews the visual projection matrix without moving the physical camera.
	# This means -basis.z is NOT the center of the screen!
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = viewport_size / 2.0
	
	var ray_start = camera.project_ray_origin(screen_center)
	var cam_forward = camera.project_ray_normal(screen_center)
	
	var space_state = get_world_3d().direct_space_state
	var ray_end = ray_start + cam_forward * 1000.0
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [get_rid()] 
	var result = space_state.intersect_ray(query)
	
	var target_pos = ray_end
	if result:
		target_pos = result.position
		
	# Move the debug marker so you can see it!
	var marker = get_node_or_null("/root/TargetMarker")
	if marker:
		marker.global_position = target_pos
		marker.visible = show_target_marker

	# Shoot Plunger
	var wants_to_shoot = false
	if is_mobile_device():
		wants_to_shoot = is_mobile_shooting
		is_mobile_shooting = false # Reset flag after checking
	else:
		wants_to_shoot = Input.is_action_just_pressed("ui_select") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		
	if wants_to_shoot and shoot_cooldown <= 0 and not is_dashing:
		shoot_cooldown = 0.6 # 0.5 seconds cooldown
		var main_node = get_node("/root/World/main")
		if main_node:
			var shoulder_side = sign(camera.h_offset) 
			if shoulder_side == 0: shoulder_side = 1.0
			# global_position is the center of the 2.0 height capsule.
			# So the top of the head is at +1.0. A Y-offset of 0.4 places it perfectly at chest/shoulder height.
			var chest_pos = global_position + Vector3(0, 0.8, 0)
			var ideal_muzzle_pos = chest_pos + (cam_forward * 0.8) + (global_transform.basis.x * shoulder_side * 0.6)
			
			# Prevent shooting through walls by clamping the muzzle position if it's inside a wall
			var query2 = PhysicsRayQueryParameters3D.create(chest_pos, ideal_muzzle_pos)
			query2.exclude = [get_rid()]
			var muzzle_hit = space_state.intersect_ray(query2)
			
			var muzzle_pos = ideal_muzzle_pos
			if muzzle_hit:
				# Pull it slightly back from the wall so it doesn't spawn inside the collider
				muzzle_pos = muzzle_hit.position - (ideal_muzzle_pos - chest_pos).normalized() * 0.1
			
			var shoot_dir = (target_pos - muzzle_pos).normalized()
			main_node.rpc("spawn_plunger", muzzle_pos, shoot_dir, multiplayer.get_unique_id())


var health = 3
var last_shooter_id: int = -1

@rpc("any_peer", "call_local")
func take_damage(hit_pos: Vector3, hit_normal: Vector3, incoming_plunger_color: Color = Color("ff1d1d"), shooter_id: int = -1): # <--- CHANGED NAME HERE
	health -= 1
	last_shooter_id = shooter_id
	
	# --- VISUAL STICKING PLUNGER ---
	# Create a purely visual "dummy" plunger to stick to the player
	var dummy_plunger = load("res://scenes/Plunger.tscn").instantiate()
	dummy_plunger.set_script(null) # Remove logic
	
	# Apply the shooter's team color to the plunger head
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = incoming_plunger_color # <--- USE NEW NAME HERE
	var head_mesh = dummy_plunger.get_node_or_null("MeshInstance3D2")
	if head_mesh:
		head_mesh.set_surface_override_material(0, head_mat)
	
	# Strip physics and networking to prevent crashes
	var col = dummy_plunger.get_node_or_null("CollisionShape3D")
	if col: col.queue_free()
	var sync = dummy_plunger.get_node_or_null("MultiplayerSynchronizer")
	if sync: sync.queue_free()
	
	# Attach to player mesh so it moves with the player
	$MeshInstance3D.add_child(dummy_plunger)
	
	# The plunger's origin is the center of the wooden stick, but the red suction cup is at the front.
	# We push the plunger out along the normal by 0.5 units (half its scale) so the suction cup sits flush on the skin!
	dummy_plunger.global_position = hit_pos + (hit_normal * 0.4)
	
	# Orient it correctly against the hit surface
	var look_target = hit_pos - hit_normal
	if abs(hit_normal.dot(Vector3.UP)) < 0.999:
		dummy_plunger.look_at(look_target, Vector3.UP)
	else:
		dummy_plunger.look_at(look_target, Vector3.RIGHT)
		
	# --- FLASH BRIGHT ---
	# Ensure we aren't sharing the material across all players
	if not $MeshInstance3D.get_surface_override_material(0):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = team_color
		$MeshInstance3D.set_surface_override_material(0, mat)
		
	var unique_mat = $MeshInstance3D.get_surface_override_material(0)
	# Create a vibrant version: keep hue, max out saturation and brightness
	var flash_color = Color.from_hsv(team_color.h, 1.0, 1.0)
	unique_mat.albedo_color = flash_color
	await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		unique_mat.albedo_color = team_color
		
	# --- DEATH ---
	if health <= 0:
		die()

func die():
	health = 3
	deaths += 1
	
	# Credit the kill to the shooter (server only to prevent double-counting)
	if multiplayer.is_server() and last_shooter_id > 0:
		var spawned = get_node_or_null("/root/World/main/SpawnedObjects")
		if spawned:
			var shooter = spawned.get_node_or_null(str(last_shooter_id))
			if shooter and shooter.has_method("register_kill"):
				shooter.rpc("register_kill")
	last_shooter_id = -1
	
	# Clean up all stuck plungers
	for child in $MeshInstance3D.get_children():
		if child is Area3D or "Plunger" in child.name:
			child.queue_free()
			
	if is_multiplayer_authority():
		# Teleport to a random spawn point
		var spawn_points = get_node_or_null("/root/World/SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var random_spawn = spawn_points.get_children().pick_random()
			global_position = random_spawn.global_position
			position.y += 1.0
		else:
			position = Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2))

@rpc("any_peer", "call_local")
func _sync_name(n: String):
	player_name = n

@rpc("any_peer", "call_local")
func register_kill():
	kills += 1

@rpc("any_peer", "call_local")
func register_hit():
	hits += 1
	


func _apply_team_colors():
	if team_index == 0:
		team_color = Color(0.4, 0.6, 1.0) # Light Blue
		plunger_color = Color("1d56ffff") # Vivid Blue
	else:
		team_color = Color(1.0, 0.4, 0.4) # Light Red
		plunger_color = Color("ff1d1d") # Vivid Red
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color
	
	# Safe check to make sure the mesh exists
	if has_node("MeshInstance3D"):
		$MeshInstance3D.set_surface_override_material(0, mat)
		
	# Update local UI if I own this player
	if is_inside_tree() and is_multiplayer_authority() and shoot_ui_ref:
		shoot_ui_ref.ring_color = team_color
		shoot_ui_ref.ready_color = team_color

func is_mobile_device() -> bool:
	if OS.has_feature("mobile"): return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"): return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var ua = JavaScriptBridge.eval("navigator.userAgent")
		if ua:
			for m in ["Android", "iPhone", "iPad", "iPod", "Mobile"]:
				if m in ua: return true
	return false
		
@rpc("any_peer", "call_remote", "reliable")
func request_team_color():
	# Only the Server is allowed to answer this question
	if multiplayer.is_server():
		var requester = multiplayer.get_remote_sender_id()
		# Send the true team index back to the specific client who asked
		rpc_id(requester, "sync_team", team_index)

@rpc("any_peer", "call_local", "reliable")
func sync_team(assigned_team: int):
	team_index = assigned_team
	_apply_team_colors()
	
@rpc("any_peer", "call_remote", "unreliable")
func relay_position(pos: Vector3, rot: Vector3):
	# If I am the client who owns this player, ignore this (so my movement doesn't stutter)
	if is_multiplayer_authority(): return
	
	# If I am a peer watching this player, update their visual position!
	global_position = pos
	rotation = rot

# Helper for toggling camera shoulder side (used by keyboard and mobile)
func toggle_camera():
	if target_h_offset == 1.0:
		target_h_offset = -1.0
	else:
		target_h_offset = 1.0

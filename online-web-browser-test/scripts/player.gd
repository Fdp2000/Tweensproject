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

var team_color: Color = Color.WHITE

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D

func _enter_tree() -> void:
	var id = str(name).to_int()
	set_multiplayer_authority(id)
	$MultiplayerSynchronizer.set_multiplayer_authority(id)

func _ready():
	# Wait one frame to ensure authority is synced across the network
	await get_tree().process_frame
	
	# Assign team color based on join order (sibling index)
	if get_index() % 2 == 0:
		team_color = Color(0.4, 0.6, 1.0) # Light Blue
	else:
		team_color = Color(1.0, 0.4, 0.4) # Light Red
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color
	$MeshInstance3D.set_surface_override_material(0, mat)
	
	if is_multiplayer_authority():
		camera.current = true
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
		canvas.add_child(dash_ui)
		
		# Create the dynamic shoot cooldown ring
		var shoot_ui = Control.new()
		shoot_ui.set_script(preload("res://scripts/dash_ui.gd"))
		shoot_ui.ring_color = Color(1.0, 0.2, 0.2, 0.9)
		shoot_ui.ready_color = Color(1.0, 0.2, 0.2, 0.9)
		shoot_ui.custom_minimum_size = Vector2(40, 40)
		shoot_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		shoot_ui.position.x -= 60 # Move in from the right edge
		shoot_ui.position.y -= 80 # Move up from the bottom edge
		shoot_ui.name = "ShootUI"
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
		
		add_child(canvas)
		
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
	
	# Handle Mouse Movement separately
	if event is InputEventMouseMotion:
		var actual_sens = mouse_sensitivity * 0.001 # Convert user number to radians
		rotate_y(-event.relative.x * actual_sens)
		spring_arm.rotate_x(-event.relative.y * actual_sens)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.0, 1.0)
		return # Stop here for mouse motion
		
	# Handle Scroll Wheel Sensitivity
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			mouse_sensitivity = clamp(mouse_sensitivity + 0.20, 0.2, 10)
			show_sensitivity_popup()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mouse_sensitivity = clamp(mouse_sensitivity - 0.20, 0.2, 10)
			show_sensitivity_popup()

	if Input.is_action_just_pressed("secondary_action"):
		if target_h_offset == 1.0:
			target_h_offset = -1.0
		else:
			target_h_offset = 1.0

func show_sensitivity_popup():
	var label = get_node_or_null("PlayerCanvas/SensLabel")
	if label:
		label.text = "Sensitivity: %.1f" % mouse_sensitivity
		label.modulate.a = 1.0
		sens_popup_timer = 2.0

var shoot_cooldown: float = 0.0

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
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
	var dash_ui = get_node_or_null("PlayerCanvas/DashUI")
	if dash_ui:
		if DASH_COOLDOWN > 0:
			dash_ui.progress = 1.0 - (dash_cooldown_left / DASH_COOLDOWN)
		else:
			dash_ui.progress = 1.0
			
	# Update Shoot UI
	var shoot_ui = get_node_or_null("PlayerCanvas/ShootUI")
	if shoot_ui:
		var effective_shoot_cd = shoot_cooldown
		var shoot_max_cd = 0.6
		if is_dashing and dash_time_left > shoot_cooldown:
			effective_shoot_cd = dash_time_left
			shoot_max_cd = DASH_DURATION
			
		if shoot_max_cd > 0:
			shoot_ui.progress = 1.0 - (effective_shoot_cd / shoot_max_cd)
		else:
			shoot_ui.progress = 1.0

	if not is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_dashing: 
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
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
		if Input.is_physical_key_pressed(KEY_SHIFT) and is_on_floor() and dash_cooldown_left <= 0:
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

	# Shoot Plunger
	if Input.is_action_just_pressed("ui_select") and shoot_cooldown <= 0 and not is_dashing:
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
			main_node.rpc("spawn_plunger", muzzle_pos, shoot_dir)

var health = 3

@rpc("any_peer", "call_local")
func take_damage(hit_pos: Vector3, hit_normal: Vector3):
	health -= 1
	
	# --- VISUAL STICKING PLUNGER ---
	# Create a purely visual "dummy" plunger to stick to the player
	var dummy_plunger = load("res://scenes/Plunger.tscn").instantiate()
	dummy_plunger.set_script(null) # Remove logic
	
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
		
	# --- FLASH RED ---
	# Ensure we aren't sharing the material across all players
	if not $MeshInstance3D.get_surface_override_material(0):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = team_color
		$MeshInstance3D.set_surface_override_material(0, mat)
		
	var unique_mat = $MeshInstance3D.get_surface_override_material(0)
	unique_mat.albedo_color = Color.RED
	await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		unique_mat.albedo_color = team_color
		
	# --- DEATH ---
	if health <= 0:
		die()

func die():
	health = 3
	
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

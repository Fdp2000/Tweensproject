extends "res://scripts/Player/player.gd"

@export var is_charging = false
var charge_time_left = 0.0
var charge_cooldown_left = 0.0
var total_captures = 0
var charge_direction = Vector3.ZERO
var charge_ui_ref: Control
@export var is_debuffed = false
var debuff_timer = 0.0
var camera_anim = null

func _ready():
	super._ready()
	if is_multiplayer_authority():
		# Cop uses first-person camera
		if spring_arm:
			spring_arm.spring_length = 0.0
		if camera:
			camera.fov = Balance.cop_fov_angle
			
		# ==========================================
		# --- FIRST PERSON HEAD HIDING ---
		# ==========================================
		# Find the head mesh using the exact path from your Cop scene
		var rhino_head = get_node_or_null("Næsehorn2/metarig/Skeleton3D/Rhino_Head")
		if rhino_head:
			# Hide the mesh from the camera, but keep casting a shadow!
			rhino_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			
		# Wait one frame for PlayerCanvas to be created by base class
		await get_tree().process_frame
		var canvas = get_node_or_null("PlayerCanvas")
		if canvas:
			var charge_ui = Control.new()
			charge_ui.set_script(preload("res://scripts/UI/dash_ui.gd"))
			charge_ui.ring_color = Color(0.2, 0.4, 1.0, 0.9)
			charge_ui.ready_color = Color(0.2, 0.4, 1.0, 0.9)
			charge_ui.custom_minimum_size = Vector2(40, 40)
			charge_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			charge_ui.position.x -= 60
			charge_ui.position.y -= 80
			charge_ui.name = "ChargeUI"
			charge_ui_ref = charge_ui
			canvas.add_child(charge_ui)

func _add_custom_mobile_ui(mobile_ui: Control, ui_scale: float):
	var charge_btn = load("res://scripts/UI/mobile_button.gd").new()
	charge_btn.action_name = "dash" # Map to dash action
	charge_btn.button_text = "CHARGE"
	charge_btn.radius = 60.0 * ui_scale
	charge_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	charge_btn.offset_left = - (130 * ui_scale)
	charge_btn.offset_top = - (300 * ui_scale)
	charge_btn.offset_right = - (30 * ui_scale)
	charge_btn.offset_bottom = - (200 * ui_scale)
	mobile_ui.add_child(charge_btn)
	
	if charge_ui_ref:
		charge_ui_ref.reparent(charge_btn, false)
		charge_ui_ref.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _custom_physics_process(delta, direction):
	# ==========================================
	# 1. THE BRAIN (Only Local Player)
	# ==========================================
	if is_multiplayer_authority():
		# Update Cooldown UI
		if charge_ui_ref and Balance.cop_charge_cooldown > 0:
			charge_ui_ref.progress = clamp(1.0 - (charge_cooldown_left / Balance.cop_charge_cooldown), 0.0, 1.0)
			
		# Countdowns
		if charge_cooldown_left > 0:
			charge_cooldown_left -= delta
			
		if is_debuffed:
			debuff_timer -= delta
			if debuff_timer <= 0:
				is_debuffed = false
				
		if is_charging:
			charge_time_left -= delta
			if charge_time_left <= 0 or is_on_wall():
				is_charging = false
				is_debuffed = true
				debuff_timer = Balance.cop_exhaustion_duration
				
		# Keyboard Input
		if (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("dash")) and charge_cooldown_left <= 0 and not is_debuffed and not is_charging:
			is_charging = true
			charge_time_left = Balance.cop_charge_duration
			charge_cooldown_left = Balance.cop_charge_cooldown
			
			if direction != Vector3.ZERO:
				charge_direction = direction
			else:
				charge_direction = -camera.global_transform.basis.z.normalized()
				charge_direction.y = 0
			charge_direction = charge_direction.normalized()

	# ==========================================
	# 2. THE MUSCLES (All Peers on Network)
	# ==========================================
	if is_charging:
		var current_charge_speed = Balance.cop_base_speed * Balance.cop_charge_speed_multiplier
		
		# Failsafe: if the remote player doesn't know the exact direction yet, charge straight ahead!
		if charge_direction == Vector3.ZERO:
			charge_direction = -global_transform.basis.z.normalized()
			
		velocity.x = charge_direction.x * current_charge_speed
		velocity.z = charge_direction.z * current_charge_speed
		
		if is_multiplayer_authority():
			_detect_capture()
			
	else:
		var active_speed = Balance.cop_base_speed
		if is_debuffed:
			active_speed *= Balance.cop_exhaustion_speed_multiplier
			
		if direction:
			velocity.x = direction.x * active_speed
			velocity.z = direction.z * active_speed
		else:
			velocity.x = move_toward(velocity.x, 0, Balance.cop_braking_friction)
			velocity.z = move_toward(velocity.z, 0, Balance.cop_braking_friction)
			
		if is_multiplayer_authority():
			_detect_capture()

	# ==========================================
	# 3. THE VISUALS (All Peers on Network)
	# ==========================================
	var current_vel = velocity
	if not is_multiplayer_authority():
		current_vel = sync_velocity

	var horizontal_speed_sq = Vector2(current_vel.x, current_vel.z).length_squared()
	
	var anim_tree = get_node_or_null("Næsehorn2/AnimationTree")
	if anim_tree:
		anim_tree.active = true
		
		# THE FIX: Dynamically track the max speed so the grid always scales to 1.0!
		var current_max_speed = Balance.cop_base_speed
		if is_debuffed:
			current_max_speed *= Balance.cop_exhaustion_speed_multiplier
		
		var local_velocity = current_vel.rotated(Vector3.UP, -global_rotation.y)
		var target_grid = Vector2(local_velocity.x, -local_velocity.z) / current_max_speed
		
		if horizontal_speed_sq < 0.1:
			target_grid = Vector2.ZERO
			
		# Smooth the dot movement and apply it to BOTH grids so they stay in sync
		var current_grid = anim_tree.get("parameters/Normal_Movement/blend_position")
		var smoothed_grid = current_grid.lerp(target_grid, 10.0 * delta)
		
		anim_tree.set("parameters/Normal_Movement/blend_position", smoothed_grid)
		anim_tree.set("parameters/Debuff_Movement/blend_position", smoothed_grid)
			
		if is_charging:
			anim_tree.get("parameters/playback").travel("Charge")
			if is_multiplayer_authority() and camera_anim and camera_anim.current_animation != "cam_charge":
				camera_anim.play("cam_charge")
				
		elif is_debuffed:
			anim_tree.get("parameters/playback").travel("Debuff_Movement")
			if is_multiplayer_authority() and camera_anim and camera_anim.current_animation == "cam_charge":
				camera_anim.play("cam_reset")
				
		else:
			anim_tree.get("parameters/playback").travel("Normal_Movement")
			if is_multiplayer_authority() and camera_anim and camera_anim.current_animation == "cam_charge":
				camera_anim.play("cam_reset")

func _detect_capture():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is CharacterBody3D and collider.has_method("on_captured") and collider.get("team_index") != team_index:
			if not collider.get("is_hypnotized") and not collider.get("is_jailed"):
				rpc_id(1, "request_capture", int(str(collider.name)))
				if is_charging:
					is_charging = false
					is_debuffed = true
					# FIXED: Use the new duration variable!
					debuff_timer = Balance.cop_exhaustion_duration
				return

@rpc("any_peer", "call_local")
func request_capture(thief_id: int):
	if not multiplayer.is_server(): return
	# Host validates: check if the thief exists and is not already hypnotized
	var spawned = get_node_or_null("/root/World/main/SpawnedObjects")
	if not spawned: return
	
	var thief = spawned.get_node_or_null(str(thief_id))
	if thief and thief.has_method("on_captured"):
		if not thief.get("is_hypnotized") and not thief.get("is_jailed"):
			# Validate distance to prevent latency cheating
			if global_position.distance_to(thief.global_position) < 4.0:
				total_captures += 1
				thief.rpc("on_captured")

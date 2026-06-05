extends "res://scripts/Player/player.gd"

@export var is_charging = false
var charge_time_left = 0.0
var charge_cooldown_left = 0.0
var total_captures = 0
var charge_direction = Vector3.ZERO
var charge_ui_ref: Control
@export var is_debuffed = false
var was_debuffed = false
@export var capture_distance_buffer: float = 1
var debuff_timer = 0.0
var capture_cooldowns: Dictionary = {}

@onready var camera_anim = $PitchPivot/SpringArm3D/Camera3D/CameraAnimator
@onready var smoke_particles = $smokeParticles
@onready var skeleton = $"Næsehorn2/metarig/Skeleton3D"

# ADDED: The Tween variable for the smooth camera FOV
var fov_tween: Tween 

var grunt_player: AudioStreamPlayer3D
var breath_player: AudioStreamPlayer3D
var breath_streams = [
	preload("res://Assets/Sound/SFX/Cops Breath/Breath1.wav"),
	preload("res://Assets/Sound/SFX/Cops Breath/Breath2.wav"),
	preload("res://Assets/Sound/SFX/Cops Breath/Breath3.wav")
]

var charge_footstep_timer: float = 0.0

func _ready():
	super._ready()
	
	# Programmatically create the dynamic 3D audio followers
	grunt_player = AudioStreamPlayer3D.new()
	grunt_player.stream = preload("res://Assets/Sound/SFX/RhinoCharge.mp3")
	grunt_player.bus = "Loud SFX"
	grunt_player.max_distance = 60.0
	add_child(grunt_player)
	
	breath_player = AudioStreamPlayer3D.new()
	breath_player.bus = "Quiet SFX"
	breath_player.max_distance = 20.0
	add_child(breath_player)
	
	if is_multiplayer_authority():
		if spring_arm:
			spring_arm.spring_length = 0.0
		if camera:
			camera.fov = Balance.cop_fov_angle
			
		# --- FIRST PERSON FIX ---
		# Force the camera to look dead straight, killing the 3rd-person shoulder offset!
		target_shoulder_x = 0.0
		# ------------------------
			
		var rhino_head = get_node_or_null("Næsehorn2/metarig/Skeleton3D/Rhino_Head")
		if rhino_head:
			rhino_head.layers = 512
			
		await get_tree().process_frame
		var canvas = get_node_or_null("PlayerCanvas")
		if canvas:
			var charge_ui = Control.new()
			charge_ui.set_script(preload("res://scripts/UI/dash_ui.gd"))
			charge_ui.ring_color = Color(0.2, 0.4, 1.0, 0.9)
			charge_ui.ready_color = Color(0.2, 0.4, 1.0, 0.9)
			charge_ui.custom_minimum_size = Vector2(40, 40)
			charge_ui.size = Vector2(40, 40)
			charge_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			charge_ui.position.x -= 60
			charge_ui.position.y -= 80
			charge_ui.name = "ChargeUI"
			charge_ui_ref = charge_ui
			canvas.add_child(charge_ui)

func _add_custom_mobile_ui(mobile_ui: Control, ui_scale: float):
	var charge_btn = load("res://scripts/UI/mobile_button.gd").new()
	charge_btn.action_name = "dash" 
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
	# --- FLAWLESS CHARGE FOOTSTEPS ---
	if is_charging:
		charge_footstep_timer -= delta
		if charge_footstep_timer <= 0.0:
			AudioManager.play_3d_sfx("footstep_cop_charge", global_position)
			charge_footstep_timer = 0.22 # Exactly 5 thunderous steps per 1.2s charge
	else:
		charge_footstep_timer = 0.0

	# --- BREATH AUDIO SYNC ---
	if is_debuffed and not was_debuffed:
		var config = AudioManager.SFX_CONFIG.get("cop_exhausted_breath", {})
		if not config.get("disabled", false):
			breath_player.stream = breath_streams.pick_random()
			breath_player.volume_db = config.get("volume", 0.0)
			breath_player.max_db = breath_player.volume_db
			breath_player.max_distance = config.get("max_distance", 20.0)
			if config.has("unit_size"): breath_player.unit_size = config["unit_size"]
			if config.has("attenuation_model"): breath_player.attenuation_model = config["attenuation_model"]
			breath_player.play()
	elif not is_debuffed and was_debuffed:
		if breath_player.playing:
			var t = create_tween()
			t.tween_property(breath_player, "volume_db", -40.0, 0.5)
			t.tween_callback(breath_player.stop)
	was_debuffed = is_debuffed
	# ==========================================
	# 1. THE BRAIN (Only Local Player)
	# ==========================================
	if is_multiplayer_authority():
		var keys = capture_cooldowns.keys()
		for k in keys:
			capture_cooldowns[k] -= delta
			if capture_cooldowns[k] <= 0:
				capture_cooldowns.erase(k)
				
		if charge_ui_ref and Balance.cop_charge_cooldown > 0:
			charge_ui_ref.progress = clamp(1.0 - (charge_cooldown_left / Balance.cop_charge_cooldown), 0.0, 1.0)
			
		if charge_cooldown_left > 0:
			charge_cooldown_left -= delta
			
		if is_debuffed:
			debuff_timer -= delta
			if debuff_timer <= 0:
				is_debuffed = false
				
		if is_charging:
			charge_time_left -= delta
			# IF THE CHARGE ENDS (Time out or hit a wall)
			if charge_time_left <= 0 or is_on_wall():
				if is_on_wall():
					rpc("play_wall_impact_rpc")
				is_charging = false
				charge_time_left = 0.0
				is_debuffed = true
				debuff_timer = Balance.cop_exhaustion_duration
				
				# --- SMOOTH FOV RECOVERY TWEEN ---
				if camera:
					if fov_tween: fov_tween.kill()
					fov_tween = create_tween()
					# Changed to 0.15s with an aggressive snap!
					fov_tween.tween_property(camera, "fov", Balance.cop_fov_angle, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				
		# IF THE PLAYER PRESSES DASH
		if (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("dash")) and charge_cooldown_left <= 0 and not is_debuffed and not is_charging:
			is_charging = true
			charge_time_left = Balance.cop_charge_duration
			charge_cooldown_left = Balance.cop_charge_cooldown
			
			rpc("play_grunt_rpc")
			
			if direction != Vector3.ZERO:
				charge_direction = direction
			else:
				charge_direction = -camera.global_transform.basis.z.normalized()
				charge_direction.y = 0
			charge_direction = charge_direction.normalized()

			# Inside the dash input block (Start Charge):
			if camera:
				if fov_tween: fov_tween.kill()
				fov_tween = create_tween()
				# Pushed to +25.0, using EXPO for a violently fast punch out!
				fov_tween.tween_property(camera, "fov", Balance.cop_fov_angle + 25.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# ==========================================
	# 2. THE MUSCLES (All Peers on Network)
	# ==========================================
	if is_charging:
		var current_charge_speed = Balance.cop_base_speed * Balance.cop_charge_speed_multiplier
		
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
			
		if is_on_floor():
			if direction:
				velocity.x = direction.x * active_speed
				velocity.z = direction.z * active_speed
			else:
				velocity.x = move_toward(velocity.x, 0, (Balance.cop_braking_friction * 60.0 * delta))
				velocity.z = move_toward(velocity.z, 0, (Balance.cop_braking_friction * 60.0 * delta))
		else:
			# IN THE AIR: 20% Air Control. Hard to steer mid-air, but allows some minor adjustments.
			if direction:
				velocity.x = lerp(velocity.x, direction.x * active_speed, 1.2 * delta)
				velocity.z = lerp(velocity.z, direction.z * active_speed, 1.2 * delta)
			
		if is_multiplayer_authority():
			_detect_capture()

	# ==========================================
	# 3. THE VISUALS (All Peers on Network)
	# ==========================================
	var current_vel = velocity
	if not is_multiplayer_authority():
		current_vel = sync_velocity

	var horizontal_speed = Vector2(current_vel.x, current_vel.z).length()
	var horizontal_speed_sq = horizontal_speed * horizontal_speed
	
	var anim_tree = get_node_or_null("Næsehorn2/AnimationTree")
	if anim_tree:
		anim_tree.active = true
		
		# --- THE GLOBAL TREADMILL (DUAL SPEED) ---
		var speed_ratio = 1.0
		
		# TWEAK THESE INDEPENDENTLY:
		var run_native_speed = 4.0   # The speed your normal run animation looks best at
		var walk_native_speed = 2.0  # The speed your exhausted walk looks best at
		
		# Automatically switch the math based on what state we are in!
		var current_native_speed = walk_native_speed if is_debuffed else run_native_speed
		
		if is_charging:
			speed_ratio = 1.0 
		elif horizontal_speed > 0.1:
			speed_ratio = horizontal_speed / current_native_speed
			# Fix the audio machine-gun bug: Clamp the timescale when exhausted 
			# so the walk animation doesn't play at 3x speed while physically braking!
			if is_debuffed:
				speed_ratio = min(speed_ratio, 1.25)
		else:
			speed_ratio = 1.0 
			
		anim_tree.set("parameters/Treadmill/scale", speed_ratio)
		# -----------------------------------------
		
		var current_max_speed = Balance.cop_base_speed
		if is_debuffed:
			current_max_speed *= Balance.cop_exhaustion_speed_multiplier
		
		var local_velocity = current_vel.rotated(Vector3.UP, -global_rotation.y)
		var target_grid = Vector2(local_velocity.x, -local_velocity.z) / current_max_speed
		
		if horizontal_speed_sq < 0.1:
			target_grid = Vector2.ZERO
			
		var current_grid = anim_tree.get("parameters/AnimationNodeStateMachine/Normal_Movement/blend_position")
		if current_grid == null:
			current_grid = Vector2.ZERO 
			
		var smoothed_grid = current_grid.lerp(target_grid, 10.0 * delta)
		
		anim_tree.set("parameters/AnimationNodeStateMachine/Normal_Movement/blend_position", smoothed_grid)
		anim_tree.set("parameters/AnimationNodeStateMachine/Debuff_Movement/blend_position", smoothed_grid)
			
		var grounded = true
		if is_multiplayer_authority():
			grounded = is_on_floor()
		else:
			grounded = abs(sync_velocity.y) < 1.0
			
		var playback = anim_tree.get("parameters/AnimationNodeStateMachine/playback")
		if playback:
			if not grounded:
				playback.travel("Fall")
			elif is_charging:
				playback.travel("Charge")
				smoke_particles.emitting = true 
				if is_multiplayer_authority() and camera_anim and camera_anim.current_animation != "cam_charge":
					camera_anim.play("cam_charge", 0.15)
					
			elif is_debuffed:
				playback.travel("Debuff_Movement")
				smoke_particles.emitting = false 
				if is_multiplayer_authority() and camera_anim and camera_anim.current_animation == "cam_charge":
					camera_anim.play("cam_reset", 0.15)
					
			else:
				playback.travel("Normal_Movement")
				if is_multiplayer_authority() and camera_anim and camera_anim.current_animation == "cam_charge":
					camera_anim.play("cam_reset", 0.15)
				
		# --- THE HEAD TRACKING OVERRIDE ---
		var pitch = pitch_pivot.rotation.x
		
		# Removed the minus sign so it accurately matches your camera!
		var clamped_pitch = clamp(pitch, -1.0, 1.0)
		anim_tree.set("parameters/HeadAim/blend_position", clamped_pitch)
		
		
		
@rpc("any_peer", "call_local", "reliable")
func apply_skin(skin_index: int) -> void:
	print("COP apply_skin called on: ", name, " index: ", skin_index)

	if skin_materials.is_empty():
		print("No rhino skin materials assigned on ", name)
		return

	skin_index = clampi(skin_index, 0, skin_materials.size() - 1)
	var selected_material := skin_materials[skin_index].duplicate()

	var body := get_node_or_null("Næsehorn2/metarig/Skeleton3D/Rhino_Body") as MeshInstance3D
	var head := get_node_or_null("Næsehorn2/metarig/Skeleton3D/Rhino_Head") as MeshInstance3D

	if body:
		body.material_override = selected_material
		print("Applied rhino skin to body")

	if head:
		head.material_override = selected_material
		print("Applied rhino skin to head")

func _detect_capture():
	# We are already a child of SpawnedObjects!
	var spawned = get_parent()
	if not spawned or spawned.name != "SpawnedObjects": return
	
	for collider in spawned.get_children():
		if collider is CharacterBody3D and collider.has_method("on_captured") and collider.get("team_index") != team_index:
			if not collider.get("is_hypnotized") and not collider.get("is_jailed"):
				
				# 1. Dynamically find the exact radius of the Cop and the Thief
				var my_radius = 0.52 
				var target_radius = 0.22 
				
				var my_col = get_node_or_null("CollisionShape3D")
				if my_col and my_col.shape and "radius" in my_col.shape:
					my_radius = my_col.shape.radius
					
				var target_col = collider.get_node_or_null("CollisionShape3D")
				if target_col and target_col.shape and "radius" in target_col.shape:
					target_radius = target_col.shape.radius
					
				# 2. Emulate a perfect collision check, plus a generous network/physics buffer
				# This extra padding is crucial because character models often extend past their actual capsule colliders!
				var capture_distance = my_radius + target_radius + capture_distance_buffer
				
				var h_dist = Vector2(global_position.x, global_position.z).distance_to(Vector2(collider.global_position.x, collider.global_position.z))
				var v_dist = abs(global_position.y - collider.global_position.y)
				
				if h_dist <= capture_distance and v_dist <= 1.5:
					var target_name = str(collider.name)
					if not capture_cooldowns.has(target_name):
						capture_cooldowns[target_name] = 2.0
						rpc_id(1, "request_capture", int(target_name))
						if is_charging:
							is_charging = false
							is_debuffed = true
							debuff_timer = Balance.cop_exhaustion_duration
					return

@rpc("any_peer", "call_local")
func request_capture(thief_id: int):
	if not multiplayer.is_server(): return
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if not spawned: return
	
	var thief = spawned.get_node_or_null(str(thief_id))
	if thief and thief.has_method("on_captured"):
		if not thief.get("is_hypnotized") and not thief.get("is_jailed"):
			if global_position.distance_to(thief.global_position) < 4.0:
				total_captures += 1
				thief.rpc("on_captured")
# Add this to the very bottom of cop.gd
func toggle_camera():
	pass

# --- FOOTSTEP AUDIO ---
var last_footstep_time: int = 0

func play_footstep_sound():
	# For the local player, check input to allow moonwalking. For networked players, check their network velocity!
	var is_moving = (has_movement_input or is_charging) if is_multiplayer_authority() else (sync_velocity.length_squared() > 0.1)
	var grounded = is_on_floor() if is_multiplayer_authority() else true
	
	if is_charging:
		grounded = true # Force grounded to true because the Rhino's massive speed makes it bounce off the floor slightly!
	
	if not grounded or not is_moving:
		return
		
	var current_time = Time.get_ticks_msec()
	var debounce_time = 40 if is_charging else 120
	if is_debuffed:
		debounce_time = 350 # Increase buffer to prevent double-trigger during the heavy blend transition!
	
	if current_time - last_footstep_time > debounce_time: 
		if is_debuffed:
			AudioManager.play_3d_sfx("footstep_cop_debuff", global_position)
		elif not is_charging:
			AudioManager.play_3d_sfx("footstep_cop", global_position)
		last_footstep_time = current_time

@rpc("any_peer", "call_local")
func play_grunt_rpc():
	if grunt_player:
		var config = AudioManager.SFX_CONFIG.get("cop_vocals_grunt", {})
		if config.get("disabled", false):
			return
		grunt_player.volume_db = config.get("volume", 0.0)
		grunt_player.max_db = grunt_player.volume_db
		grunt_player.max_distance = config.get("max_distance", 60.0)
		if config.has("unit_size"): grunt_player.unit_size = config["unit_size"]
		if config.has("attenuation_model"): grunt_player.attenuation_model = config["attenuation_model"]
		grunt_player.play()

@rpc("any_peer", "call_local")
func play_wall_impact_rpc():
	AudioManager.play_3d_sfx("charge_wall_impact", global_position)

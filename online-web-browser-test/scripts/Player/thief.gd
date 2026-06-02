extends "res://scripts/Player/player.gd"

const LOBBY_JOIN_SMOKE = preload("res://Assets/Particles/smoke_particles.tscn")
const CAPTURED_SMOKE = preload("res://Assets/Particles/smoke_particles_captured.tscn")

@export var camo_material: ShaderMaterial
@export var hypno_material: ShaderMaterial
@export var debug_disable_camo: bool = false
@export var debug_disable_movement: bool = false

@onready var anim_player = $Chameleon_Character/AnimationPlayer
@onready var anim_tree = $Chameleon_Character/AnimationTree # <--- ADDED ANIM TREE
@onready var visual_mesh = $Chameleon_Character

var favorite_runs = ["Run1", "Run3", "Run4", "Run5"]
var favorite_idles = ["Idle1"] 

var is_currently_moving = false
var is_camo_posing = false # <--- ADDED FOR STEALTH TOGGLE
var sync_mesh_rot_y: float = 0.0 # <--- ADDED FOR MULTIPLAYER CAMERA SYNC

var ui_manager: Node = null
var camera_manager: Node = null
var stealth_manager: Node = null
var world_ping_manager: Node = null

var cached_lobby_smoke = null
var cached_captured_smoke = null

var carried_artifact: Node3D = null
var drop_cooldown: float = 0.0

var cash_contributed: int = 0
var is_hypnotized: bool = false
var is_rescue_halted: bool = false
var is_jailed: bool = false
var jail_walk_target: Vector3 = Vector3.ZERO   
var jail_cell_target: Vector3 = Vector3.ZERO   
var jail_cell_rot_y: float = 0.0 

var is_highlighted: bool = false
var is_mobile_interact: bool = false
var last_pos: Vector3 = Vector3.ZERO
var nav_agent: NavigationAgent3D
var current_speed_mult: float = 1.0

var nearby_interactables: Array[Node3D] = []
var interaction_scanner: Area3D

# ==========================================
# --- MULTIPLAYER CAMERA SYNC ---
# ==========================================
@rpc("any_peer", "call_local", "unreliable")
func sync_mesh_rot(rot_y: float):
	sync_mesh_rot_y = rot_y

func get_carried_artifact():
	return carried_artifact

func on_artifact_pickup(artifact: Node3D):
	carried_artifact = artifact

func on_artifact_drop():
	carried_artifact = null
	# --- ADD THIS FIX ---
	# Wipe the memory so State B thinks we "just started" moving this exact frame!
	is_currently_moving = false
	
	drop_cooldown = 1.5

var has_played_lobby_smoke = false

func play_lobby_smoke():
	if has_played_lobby_smoke: return
	has_played_lobby_smoke = true
	
	if cached_lobby_smoke:
		cached_lobby_smoke.position = Vector3(0, 0.5, 0)
		get_tree().process_frame.connect(func():
			if is_instance_valid(cached_lobby_smoke):
				cached_lobby_smoke.emitting = true
		, CONNECT_ONE_SHOT)

func spawn_smoke():
	if cached_captured_smoke:
		cached_captured_smoke.position = Vector3(0, 0.5, 0) # Center on torso
		cached_captured_smoke.emitting = false # Force restart for one_shot
		cached_captured_smoke.emitting = true

var rescue_progress: float = 0.0
var active_rescuer_id: int = -1
var rescue_audio_player: AudioStreamPlayer
var is_rescuing: bool = false
var current_interact_target: Node3D = null
var outline_mat: StandardMaterial3D = null

var debug_path_mesh: MeshInstance3D
var debug_label: Label3D
var custom_path_index: int = 0

func _ready():
	super._ready()
	
	rescue_audio_player = AudioStreamPlayer.new()
	var rescue_config = AudioManager.SFX_CONFIG.get("rescue_progress", {})
	if rescue_config.has("path"):
		rescue_audio_player.stream = load(rescue_config["path"])
	rescue_audio_player.bus = rescue_config.get("bus", "SFX")
	rescue_audio_player.volume_db = rescue_config.get("volume", 0.0)
	add_child(rescue_audio_player)
	
	last_pos = global_position
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_changed.connect(_on_path_changed)
	add_child(nav_agent)
	
	cached_lobby_smoke = LOBBY_JOIN_SMOKE.instantiate()
	add_child(cached_lobby_smoke)
	
	cached_captured_smoke = CAPTURED_SMOKE.instantiate()
	add_child(cached_captured_smoke)
	
	if multiplayer.is_server():
		play_lobby_smoke()
	
	var random_idle = favorite_idles.pick_random()
	anim_player.play(random_idle, 0.0)
	
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
		var world = get_node_or_null("/root/World")
		if world:
			world.add_child(debug_path_mesh)
	else:
		# If we are a newly joining client, ask the SERVER how long this player has been standing still
		if get_tree().get_multiplayer().has_multiplayer_peer() and not multiplayer.is_server():
			rpc_id(1, "request_camo_state")
		
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
		# Initialize UI Manager
		ui_manager = ThiefUIManager.new()
		add_child(ui_manager)
		ui_manager.setup(self)
		
		# Initialize Camera Manager
		camera_manager = ThiefCameraManager.new()
		add_child(camera_manager)
		camera_manager.setup(self)
		
	stealth_manager = ThiefStealthManager.new()
	add_child(stealth_manager)
	stealth_manager.setup(self, camo_material, hypno_material)
	
	world_ping_manager = ThiefPingManager.new()
	add_child(world_ping_manager)
	world_ping_manager.setup(self)

	if is_multiplayer_authority():
		interaction_scanner = Area3D.new()
		interaction_scanner.name = "InteractionScanner"
		interaction_scanner.collision_layer = 0
		interaction_scanner.collision_mask = 10 
		add_child(interaction_scanner)
		
		var col = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = Balance.interact_shape_size
		col.shape = sphere
		interaction_scanner.add_child(col)
		
		interaction_scanner.body_entered.connect(_on_interactable_entered)
		interaction_scanner.body_exited.connect(_on_interactable_exited)
		interaction_scanner.area_entered.connect(_on_interactable_entered)
		interaction_scanner.area_exited.connect(_on_interactable_exited)
		
		await get_tree().process_frame


func _on_path_changed():
	custom_path_index = 0
	draw_debug_path()

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventKey and event.physical_keycode == KEY_H and event.pressed and not event.echo:
		rpc("dev_toggle_hypnotize")
		return
		
	super._unhandled_input(event)
	
	var is_interact = (event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_interact:
		if carried_artifact: 
			_try_drop()
		else:
			var target = get_closest_interactable()
			if target and not target.has_method("on_captured"): 
				target.rpc_id(1, "request_pickup", multiplayer.get_unique_id())

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
			
	if camera_manager and camera_manager.handle_input(event):
		get_viewport().set_input_as_handled()
		return
		
	super._input(event)

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
	var min_dist_thief: float = Balance.interact_shape_size
	var min_dist_art: float = Balance.interact_shape_size
	
	for i in range(nearby_interactables.size() - 1, -1, -1):
		if not is_instance_valid(nearby_interactables[i]):
			nearby_interactables.remove_at(i)
	
	for target in nearby_interactables:
		var dist = global_position.distance_to(target.global_position)
		
		if target.has_method("on_captured") and target != self and target.get("team_index") == 0 and target.get("is_hypnotized"):
			if dist < min_dist_thief:
				closest_thief = target
				min_dist_thief = dist
				
		elif drop_cooldown <= 0.0 and target.is_in_group("artifact") and not target.get("is_carried"):
			if dist < min_dist_art:
				closest_art = target
				min_dist_art = dist
				
	if closest_thief: return closest_thief
	return closest_art

func update_jail_targets(walk_pos: Vector3, cell_pos: Vector3):
	jail_walk_target = walk_pos
	jail_cell_target = cell_pos
	if nav_agent:
		nav_agent.target_position = jail_walk_target

func _custom_physics_process(delta, direction):
	# --- RESCUE AUDIO SYNC ---
	if active_rescuer_id != -1 and (multiplayer.get_unique_id() == active_rescuer_id or multiplayer.get_unique_id() == str(name).to_int()):
		if not rescue_audio_player.playing:
			rescue_audio_player.play()
		# Cranked base pitch to 3.0, and max pitch to 8.0 (3.0 + 5.0) for maximum tension!
		rescue_audio_player.pitch_scale = 3.0 + (rescue_progress / Balance.thief_rescue_time) * 5.0
	else:
		if rescue_audio_player.playing:
			rescue_audio_player.stop()

	if debug_disable_movement:
		direction = Vector3.ZERO
	
	# ==========================================
	# 1. MOVEMENT STATE MACHINE
	# ==========================================
	if is_jailed or (camera_manager and camera_manager.is_on_cameras):
		velocity.x = move_toward(velocity.x, 0, (Balance.thief_braking_friction * 60.0 * delta))
		velocity.z = move_toward(velocity.z, 0, (Balance.thief_braking_friction * 60.0 * delta))
		# (REMOVED 'return' HERE)
	
	elif is_hypnotized: # Changed 'if' to 'elif'
		if is_multiplayer_authority():
			if is_rescue_halted:
				velocity.x = move_toward(velocity.x, 0, (Balance.thief_braking_friction * 60.0 * delta))
				velocity.z = move_toward(velocity.z, 0, (Balance.thief_braking_friction * 60.0 * delta))
			else:
				var dist_to_target = global_position.distance_to(jail_walk_target)
				
				if dist_to_target < 1.0:
					rpc("on_jailed", jail_cell_target, jail_cell_rot_y)
					velocity.x = 0
					velocity.z = 0
					if camera_manager: camera_manager.access_cameras()
				elif nav_agent.is_navigation_finished():
					velocity.x = move_toward(velocity.x, 0, (Balance.thief_braking_friction * 60.0 * delta))
					velocity.z = move_toward(velocity.z, 0, (Balance.thief_braking_friction * 60.0 * delta))
				else:
					var _ignore = nav_agent.get_next_path_position() 
					var path = nav_agent.get_current_navigation_path()
					
					if path.size() == 0 or custom_path_index >= path.size():
						velocity.x = move_toward(velocity.x, 0, (Balance.thief_braking_friction * 60.0 * delta))
						velocity.z = move_toward(velocity.z, 0, (Balance.thief_braking_friction * 60.0 * delta))
						if debug_label: debug_label.text = "STOPPED (End of Path)\nVel: 0"
					else:
						var flat_global = Vector3(global_position.x, 0, global_position.z)
						var target_pt = path[custom_path_index]
						var flat_target = Vector3(target_pt.x, 0, target_pt.z)
						var dist = flat_global.distance_to(flat_target)
						
						while dist < 0.5 and custom_path_index < path.size():
							custom_path_index += 1
							if custom_path_index < path.size():
								target_pt = path[custom_path_index]
								flat_target = Vector3(target_pt.x, 0, target_pt.z)
								dist = flat_global.distance_to(flat_target)
								
						if custom_path_index >= path.size():
							velocity.x = move_toward(velocity.x, 0, (Balance.thief_braking_friction * 60.0 * delta))
							velocity.z = move_toward(velocity.z, 0, (Balance.thief_braking_friction * 60.0 * delta))
							if debug_label: debug_label.text = "STOPPED (Reached Target)\nVel: 0"
						else:
							var dir_to_next = flat_global.direction_to(flat_target)
							velocity.x = dir_to_next.x * Balance.hypno_thief_speed
							velocity.z = dir_to_next.z * Balance.hypno_thief_speed
							
							if debug_label: debug_label.text = "MOVING to WP " + str(custom_path_index) + "\nDist: " + str(dist).pad_decimals(2)
						
						if velocity.length_squared() > 0.01:
							var old_cam_basis = pitch_pivot.global_basis
							var target_transform = transform.looking_at(global_position + Vector3(velocity.x, 0, velocity.z).normalized(), Vector3.UP)
							transform = transform.interpolate_with(target_transform, 5.0 * delta)
							pitch_pivot.global_basis = old_cam_basis.orthonormalized()
						
		if multiplayer.is_server():
			if active_rescuer_id != -1:
				var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
				var rescuer = spawned.get_node_or_null(str(active_rescuer_id)) if spawned else null
				if rescuer and rescuer.global_position.distance_to(global_position) <= Balance.interact_shape_size:
					if not is_rescue_halted:
						is_rescue_halted = true
						rpc("sync_rescue_halt", true)
						
					rescue_progress += delta
					rpc("sync_rescue_progress", rescue_progress)
					
					if rescue_progress >= Balance.thief_rescue_time:
						active_rescuer_id = -1
						rpc("sync_active_rescuer", -1) 
						rescue_progress = 0.0
						rpc("sync_rescue_progress", 0.0)
						rpc("sync_rescue_halt", false)
						rpc("rescue_successful")
				else:
					active_rescuer_id = -1
					rpc("sync_active_rescuer", -1) 
					
					if is_rescue_halted:
						is_rescue_halted = false
						rpc("sync_rescue_halt", false)
			else:
				if is_rescue_halted:
					is_rescue_halted = false
					rpc("sync_rescue_halt", false)
		# (REMOVED 'return' HERE)
		
	else: # Changed 'if' to 'else'
		if carried_artifact:
			current_speed_mult = carried_artifact.weight_penalty
		else:
			current_speed_mult = 1.0
			
		var target_speed = Balance.base_thief_speed * current_speed_mult
		
		if is_on_floor():
			if direction:
				velocity.x = direction.x * target_speed
				velocity.z = direction.z * target_speed
			else:
				velocity.x = move_toward(velocity.x, 0, (Balance.thief_braking_friction * 60.0 * delta) * current_speed_mult)
				velocity.z = move_toward(velocity.z, 0, (Balance.thief_braking_friction * 60.0 * delta) * current_speed_mult)
		else:
			# IN THE AIR: 75% Air Control (Agile Thief). Use lerp to gently steer momentum instead of snapping!
			if direction:
				velocity.x = lerp(velocity.x, direction.x * target_speed, 3.5 * delta)
				velocity.z = lerp(velocity.z, direction.z * target_speed, 3.5 * delta)
			

	# ==========================================
	# 2. ANIMATION STATE MACHINE (NOW IT WILL RUN!)
	# ==========================================
	var current_vel = velocity
	var grounded = true
	
	if not is_multiplayer_authority():
		current_vel = sync_velocity
		grounded = abs(sync_velocity.y) < 1.0
	else:
		grounded = is_on_floor()

	var horizontal_speed_sq = Vector2(current_vel.x, current_vel.z).length_squared()

	if is_jailed:
		anim_tree.active = false
		if anim_player.current_animation != "Idle1":
			anim_player.play("Idle1", 0.2)
			
		# When jailed, the parent body faces outward (-Z). Since the mesh's native forward is +Z, we add PI.
		var target_angle = global_rotation.y + PI
		visual_mesh.global_rotation.y = lerp_angle(visual_mesh.global_rotation.y, target_angle, 10.0 * delta)
		
	elif is_hypnotized:
		anim_tree.active = false
		
		if is_rescue_halted:
			# STAND STILL: A teammate is currently rescuing me!
			if anim_player.current_animation != "Idle1":
				anim_player.play("Idle1", 0.2)
		else:
			# NO RESCUER: Zombie walk to the cell!
			if anim_player.current_animation != "Hypno_Walk":
				anim_player.play("Hypno_Walk", 0.2)
				
		# FIX: Ensure the visual mesh still rotates to face the direction of movement, exactly like normal running!
		if horizontal_speed_sq > 0.05:
			var target_angle = atan2(current_vel.x, current_vel.z) 
			visual_mesh.global_rotation.y = lerp_angle(visual_mesh.global_rotation.y, target_angle, 10.0 * delta)
			
	elif carried_artifact != null:
		# ----------------------------------------
		# STATE A: CARRYING AN ARTIFACT
		# ----------------------------------------
		
		if not anim_tree.active:
			anim_player.stop() # Force-kill the normal run animation so its tracks stop firing!
			anim_tree.active = true
			
		anim_tree.get("parameters/playback").travel("Holding_State")
		
		if carried_artifact:
			anim_tree.set("parameters/Holding_State/Pose_Selector/transition_request", "floor_prop")

		var target_rot = 0.0
		if pitch_pivot:
			target_rot = pitch_pivot.global_rotation.y + PI
			
		if is_multiplayer_authority() and pitch_pivot:
			visual_mesh.global_rotation.y = lerp_angle(visual_mesh.global_rotation.y, target_rot, 10.0 * delta)
			rpc("sync_mesh_rot", visual_mesh.global_rotation.y)
		else:
			visual_mesh.global_rotation.y = lerp_angle(visual_mesh.global_rotation.y, sync_mesh_rot_y, 10.0 * delta)

		var is_trying_to_move = false
		if is_multiplayer_authority():
			var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			is_trying_to_move = input_dir.length_squared() > 0.01
		else:
			is_trying_to_move = horizontal_speed_sq > 0.05
		
		if not grounded:
			is_currently_moving = false
			anim_tree.get("parameters/playback").travel("Fall")
		elif is_trying_to_move:
			is_camo_posing = false
			is_currently_moving = true 
			anim_tree.set("parameters/Holding_State/Camo_Transition/transition_request", "carrying")
			anim_tree.set("parameters/Holding_State/Blend2/blend_amount", 1.0)
			
			var local_velocity = current_vel.rotated(Vector3.UP, -pitch_pivot.global_rotation.y)
			var grid_position = Vector2(local_velocity.x, -local_velocity.z).normalized()
			anim_tree.set("parameters/Holding_State/CarryMovement/blend_position", grid_position)
			# AUTO-SYNC: Calculate exact speed based on actual velocity!
			var actual_speed = Vector2(current_vel.x, current_vel.z).length()
			var final_tree_speed = actual_speed / Balance.anim_native_speed
			
			anim_tree.set("parameters/Holding_State/TimeScale/scale", final_tree_speed)
			
		else:
			is_currently_moving = false 
			anim_tree.set("parameters/Holding_State/CarryMovement/blend_position", Vector2.ZERO)
			
			if stealth_manager and stealth_manager.stationary_time >= Balance.thief_camo_activation_time:
				if not is_camo_posing:
					is_camo_posing = true
				anim_tree.set("parameters/Holding_State/Camo_Transition/transition_request", "hiding")
			else:
				anim_tree.set("parameters/Holding_State/Camo_Transition/transition_request", "carrying")
				
	else:
		# ----------------------------------------
		# STATE B: NORMAL RUNNING (EMPTY HANDED)
		# ----------------------------------------
		if anim_tree.active:
			anim_tree.active = false
			anim_player.stop() # Force-kill the tree's ghost tracks!
		
		if not grounded:
			is_currently_moving = false
			if anim_player.current_animation != "Fall":
				anim_player.play("Fall", 0.2)
		elif horizontal_speed_sq > 0.05:
			if not is_currently_moving or anim_player.current_animation == "Fall":
				is_currently_moving = true
				var random_run = favorite_runs.pick_random()
				# AUTO-SYNC: Calculate exact speed based on actual velocity!
				var actual_speed = Vector2(current_vel.x, current_vel.z).length()
				var final_player_speed = actual_speed / Balance.anim_native_speed
				
				anim_player.play(random_run, 0.2, final_player_speed)
			
			var target_angle = atan2(current_vel.x, current_vel.z) 
			visual_mesh.global_rotation.y = lerp_angle(visual_mesh.global_rotation.y, target_angle, 10.0 * delta)
		else:
			if is_currently_moving or anim_player.current_animation == "Fall":
				is_currently_moving = false
				var random_idle = favorite_idles.pick_random()
				anim_player.play(random_idle, 0.3) 
				
			elif stealth_manager and stealth_manager.stationary_time >= Balance.thief_camo_activation_time:
				if anim_player.current_animation != "Camo_Pose":
					anim_player.play("Camo_Pose", Balance.thief_camo_fade_duration_sec)
			
func _process(delta):
	if drop_cooldown > 0.0:
		drop_cooldown -= delta
		if drop_cooldown < 0.0:
			drop_cooldown = 0.0
			
	super._process(delta) 
	
	if stealth_manager:
		var speed = 0.0
		if is_multiplayer_authority():
			speed = Vector3(velocity.x, 0, velocity.z).length()
		else:
			var dist = Vector3(global_position.x, 0, global_position.z).distance_to(Vector3(last_pos.x, 0, last_pos.z))
			if dist > 3.0:
				speed = 0.0 # Teleport or network snap, ignore for camo calculations
			else:
				speed = dist / delta
			last_pos = global_position
			
		if debug_disable_camo:
			speed = 999.0
			
		stealth_manager.process_stealth(delta, speed, is_hypnotized, is_jailed, is_highlighted)

	if not is_multiplayer_authority(): return
	
	if ui_manager:
		if drop_cooldown > 0.0:
			ui_manager.update_drop_cooldown_ring(drop_cooldown / 1.5, true)
		else:
			ui_manager.update_drop_cooldown_ring(0.0, false)
			
		if is_jailed:
			ui_manager.update_rescue_ring(0.0, false) 
		elif is_hypnotized:
			if active_rescuer_id != -1:
				ui_manager.update_rescue_ring(rescue_progress / Balance.thief_rescue_time, true)
			else:
				ui_manager.update_rescue_ring(0.0, false) 
		elif is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
			ui_manager.update_rescue_ring(current_interact_target.rescue_progress / Balance.thief_rescue_time, true)
		else:
			ui_manager.update_rescue_ring(0.0, false) 
			
	if is_hypnotized or is_jailed:
		if stealth_manager: stealth_manager.update_outlines(null)
		if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
			rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null
		return

	var target = null
	if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
		target = current_interact_target
	else:
		target = get_closest_interactable()
		
	if stealth_manager: stealth_manager.update_outlines(target)
	
	if camera_manager and camera_manager.is_on_cameras:
		if is_mobile_interact:
			is_mobile_interact = false
			camera_manager.fire_camera_ping()
		return
			
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
		if global_position.distance_to(current_interact_target.global_position) > Balance.interact_shape_size or not current_interact_target.get("is_hypnotized"):
			rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null

func force_camo():
	if stealth_manager:
		stealth_manager.stationary_time = 999.0
		stealth_manager.current_alpha = 0.0
		stealth_manager.current_eye_alpha = 0.0
		stealth_manager.target_alpha = 0.0
		stealth_manager._last_rendered_alpha = -1.0

@rpc("any_peer", "call_local")
func on_captured():
	if is_hypnotized: return
	
	# Play the global 3D capture bonk for everyone
	AudioManager.play_3d_sfx("capture", global_position)
	
	if multiplayer.get_unique_id() == str(name).to_int():
		AudioManager.set_hypnotized(true)
	
	is_hypnotized = true
	disable_body_rotation = true 
	spawn_smoke()
	
	randomize() 
		
	collision_layer = 8 
	collision_mask = 5  
	
	if carried_artifact:
		if multiplayer.is_server():
			carried_artifact.rpc("drop")
		carried_artifact = null
	
	var jails = get_tree().get_nodes_in_group("jail")
	if jails.size() > 0:
		var jail = jails.pick_random() 
		
		var possible_cells = [
			jail.get_node_or_null("CellTarget"),
			jail.get_node_or_null("CellTarget2"),
			jail.get_node_or_null("CellTarget3"),
			jail.get_node_or_null("CellTarget4")
		]
		
		possible_cells = possible_cells.filter(func(node): return node != null)
		var cell_target = possible_cells.pick_random()
		
		var walk_pos = jail.get_node("WalkTarget").global_position
		var cell_pos = cell_target.global_position
		
		jail_cell_rot_y = cell_target.global_rotation.y 
		update_jail_targets(walk_pos, cell_pos)
		
	if multiplayer.is_server():
		GameManager.rpc("thief_captured")

@rpc("any_peer", "call_local")
func dev_toggle_hypnotize():
	if not is_hypnotized:
		if multiplayer.get_unique_id() == str(name).to_int():
			AudioManager.set_hypnotized(true)
			
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
		if multiplayer.get_unique_id() == str(name).to_int():
			AudioManager.set_hypnotized(false)
			
		is_hypnotized = false
		disable_body_rotation = false
		collision_layer = 2
		collision_mask = 3
		
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
		im_mesh.surface_add_vertex(path[i] + Vector3(0, 0.5, 0))
		im_mesh.surface_add_vertex(path[i+1] + Vector3(0, 0.5, 0))
	im_mesh.surface_end()
	debug_path_mesh.mesh = im_mesh

@rpc("any_peer", "call_local")
func request_start_rescue(target_id: int):
	if not multiplayer.is_server(): return
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	var target = spawned.get_node_or_null(str(target_id)) if spawned else null
	if target and target.get("is_hypnotized"):
		target.active_rescuer_id = multiplayer.get_remote_sender_id()
		target.rpc("sync_active_rescuer", target.active_rescuer_id) 

@rpc("any_peer", "call_local")
func request_stop_rescue(target_id: int):
	if not multiplayer.is_server(): return
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	var target = spawned.get_node_or_null(str(target_id)) if spawned else null
	if target and target.active_rescuer_id == multiplayer.get_remote_sender_id():
		target.active_rescuer_id = -1
		target.rpc("sync_active_rescuer", -1) 

@rpc("any_peer", "call_local", "unreliable")
func sync_rescue_progress(prog: float):
	rescue_progress = prog

@rpc("any_peer", "call_local", "reliable")
func sync_rescue_halt(halted: bool):
	is_rescue_halted = halted
	
@rpc("any_peer", "call_local", "reliable")
func sync_active_rescuer(id: int):
	active_rescuer_id = id
	
@rpc("any_peer", "call_local")
func sync_world_ping(pos: Vector3):
	if world_ping_manager:
		world_ping_manager.trigger_ping(pos)

@rpc("any_peer", "call_local")
func rescue_successful():
	if not is_hypnotized: return
	
	if multiplayer.get_unique_id() == str(name).to_int():
		AudioManager.set_hypnotized(false)
	
	is_hypnotized = false
	disable_body_rotation = false 
	
	collision_layer = 4 
	collision_mask = 15 
	
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0 
		pitch_pivot.rotation.z = 0 
		
	if multiplayer.is_server():
		GameManager.rpc("thief_rescued")

@rpc("any_peer", "call_local")
func on_jailed(cell_pos: Vector3, cell_rot_y: float):
	if multiplayer.get_unique_id() == str(name).to_int() and is_hypnotized:
		# Remove the hypnosis audio effect once they are safely in jail!
		AudioManager.set_hypnotized(false)
		
	is_hypnotized = false
	is_jailed = true
	disable_body_rotation = true 
	
	collision_layer = 4 
	collision_mask = 15 
	is_rescue_halted = false
	
	global_position = cell_pos
	rotation.y = cell_rot_y + PI
	
	# Play the global 3D jail slam sound so everyone hears the door shut
	AudioManager.play_3d_sfx("jailed", global_position)
	
	if pitch_pivot:
		pitch_pivot.rotation.y = 0
		pitch_pivot.rotation.z = 0
		
func handle_mobile_interact_press():
	if not carried_artifact:
		var target = get_closest_interactable()
		if target and not target.has_method("on_captured"):
			target.rpc_id(1, "request_pickup", multiplayer.get_unique_id())
	else:
		_try_drop()

# --- CAMO STATE SYNC FOR LATE JOINERS ---
@rpc("any_peer", "call_remote")
func request_camo_state():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "receive_camo_state", stealth_manager.stationary_time if stealth_manager else 0.0)

@rpc("any_peer", "call_local")
func receive_camo_state(auth_time: float):
	if stealth_manager:
		stealth_manager.stationary_time = auth_time
		if auth_time >= Balance.thief_camo_activation_time:
			stealth_manager.current_alpha = 0.0
			is_camo_posing = true
			anim_player.play("Camo_Pose", 0.0)

# --- FOOTSTEP AUDIO ---
var last_footstep_time: int = 0

func play_footstep_sound():
	# For the local player, check input to allow moonwalking. For networked players, check their network velocity!
	var is_moving = has_movement_input if is_multiplayer_authority() else (sync_velocity.length_squared() > 0.1)
	var grounded = is_on_floor() if is_multiplayer_authority() else true
	
	if not grounded or not is_moving:
		return
		
	var current_time = Time.get_ticks_msec()
	# 120ms debounce: Short enough to catch fast footsteps, long enough to kill most transition doubles.
	if current_time - last_footstep_time > 120: 
		AudioManager.play_3d_sfx("footstep_thief", global_position)
		last_footstep_time = current_time

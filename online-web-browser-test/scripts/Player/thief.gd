extends "res://scripts/Player/player.gd"

const SMOKE_PARTICLES = preload("uid://bnktbuy2m80lu")

@export var camo_material: ShaderMaterial
@export var hypno_material: ShaderMaterial
var ui_manager: Node = null
var camera_manager: Node = null
var stealth_manager: Node = null
var world_ping_manager: Node = null

var carried_artifact: Node3D = null
var cash_contributed: int = 0
var is_hypnotized: bool = false
var is_rescue_halted: bool = false
var is_jailed: bool = false
var jail_walk_target: Vector3 = Vector3.ZERO   # Where the thief walks to (outside jail door)
var jail_cell_target: Vector3 = Vector3.ZERO   # Where the thief gets teleported (inside cell)
var jail_cell_rot_y: float = 0.0 # <--- ADD THIS

var is_highlighted: bool = false
var is_mobile_interact: bool = false
var last_pos: Vector3 = Vector3.ZERO
var nav_agent: NavigationAgent3D
var current_speed_mult: float = 1.0

var nearby_interactables: Array[Node3D] = []
var interaction_scanner: Area3D

func get_carried_artifact():
	return carried_artifact

func on_artifact_pickup(artifact: Node3D):
	carried_artifact = artifact

func on_artifact_drop():
	carried_artifact = null

func spawn_smoke():
	var smoke_intance = SMOKE_PARTICLES.instantiate()
	self.add_child(smoke_intance)
	smoke_intance.emitting = true
	smoke_intance.one_shot = true
	get_tree().create_timer(2.0).timeout
	smoke_intance.queue_free()

var rescue_progress: float = 0.0
var active_rescuer_id: int = -1
var is_rescuing: bool = false
var current_interact_target: Node3D = null
var outline_mat: StandardMaterial3D = null
const RESCUE_TIME_REQUIRED = 2.0

var debug_path_mesh: MeshInstance3D
var debug_label: Label3D

var custom_path_index: int = 0

func _ready():
	super._ready()
	nav_agent = NavigationAgent3D.new()
	# We use nav_agent ONLY to generate the path. We will handle following it manually to avoid 3D distance bugs!
	nav_agent.path_changed.connect(_on_path_changed)
	add_child(nav_agent)
	
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
		get_tree().root.call_deferred("add_child", debug_path_mesh)
		
		# Setup Debug Text Label
		debug_label = Label3D.new()
		debug_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		debug_label.position = Vector3(0, 2.5, 0)
		debug_label.pixel_size = 0.005
		debug_label.modulate = Color.GREEN
		debug_label.outline_modulate = Color.BLACK
		debug_label.no_depth_test = true
		add_child(debug_label)
		
		# Initialize UI Manager
		ui_manager = ThiefUIManager.new()
		add_child(ui_manager)
		ui_manager.setup(self)
		# Initialize Camera Manager
		camera_manager = ThiefCameraManager.new()
		add_child(camera_manager)
		camera_manager.setup(self)
# =====================================================================
	# --- MOVE THESE OUTSIDE! (Everyone needs to see visuals and pings) ---
	# =====================================================================
	
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
		interaction_scanner.collision_mask = 10 # Layer 2 (Players) + Layer 4 (Artifacts)
		add_child(interaction_scanner)
		
		var col = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 3.0
		col.shape = sphere
		interaction_scanner.add_child(col)
		
		interaction_scanner.body_entered.connect(_on_interactable_entered)
		interaction_scanner.body_exited.connect(_on_interactable_exited)
		interaction_scanner.area_entered.connect(_on_interactable_entered)
		interaction_scanner.area_exited.connect(_on_interactable_exited)
		
		await get_tree().process_frame


func _on_path_changed():
	custom_path_index = 0

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	# --- DEV TOOL: Toggle Hypnotized ---
	if event is InputEventKey and event.physical_keycode == KEY_H and event.pressed and not event.echo:
		rpc("dev_toggle_hypnotize")
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
			
	# --- LET THE MANAGER HANDLE CAMERA INPUTS ---
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
	var min_dist_thief: float = 3.0
	var min_dist_art: float = 3.0
	
	nearby_interactables = nearby_interactables.filter(func(n): return is_instance_valid(n))
	
	for target in nearby_interactables:
		var dist = global_position.distance_to(target.global_position)
		
		if target.has_method("on_captured") and target != self and target.get("team_index") == 0 and target.get("is_hypnotized"):
			if dist < min_dist_thief:
				closest_thief = target
				min_dist_thief = dist
				
		elif target.is_in_group("artifact") and not target.get("is_carried"):
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
	if is_jailed or (camera_manager and camera_manager.is_on_cameras):
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		return
	
	if is_hypnotized:
		if is_multiplayer_authority():
			if is_rescue_halted:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			else:
				var dist_to_target = global_position.distance_to(jail_walk_target)
				
				if dist_to_target < 1.0:
					# --- PASS THE ROTATION IN THE RPC ---
					rpc("on_jailed", jail_cell_target, jail_cell_rot_y)
					velocity.x = 0
					velocity.z = 0
					if camera_manager: camera_manager.access_cameras()
				elif nav_agent.is_navigation_finished():
					# The path is finished, but we haven't reached the jail!
					# This means the NavMesh is severed/broken and the jail is unreachable.
					velocity.x = move_toward(velocity.x, 0, SPEED)
					velocity.z = move_toward(velocity.z, 0, SPEED)
					draw_debug_path()
				else:
					# --- CUSTOM 2D PATH FOLLOWER ---
					var _ignore = nav_agent.get_next_path_position() # Keep agent internal state happy so it repaths if needed
					draw_debug_path()
					
					var path = nav_agent.get_current_navigation_path()
					
					if path.size() == 0 or custom_path_index >= path.size():
						velocity.x = move_toward(velocity.x, 0, SPEED)
						velocity.z = move_toward(velocity.z, 0, SPEED)
						if debug_label: debug_label.text = "STOPPED (End of Path)\nVel: 0"
					else:
						var flat_global = Vector3(global_position.x, 0, global_position.z)
						var target_pt = path[custom_path_index]
						var flat_target = Vector3(target_pt.x, 0, target_pt.z)
						var dist = flat_global.distance_to(flat_target)
						
						# Fast-forward through waypoints we are horizontally close to (Pure 2D check!)
						while dist < 0.5 and custom_path_index < path.size():
							custom_path_index += 1
							if custom_path_index < path.size():
								target_pt = path[custom_path_index]
								flat_target = Vector3(target_pt.x, 0, target_pt.z)
								dist = flat_global.distance_to(flat_target)
								
						if custom_path_index >= path.size():
							# Reached the very end
							velocity.x = move_toward(velocity.x, 0, SPEED)
							velocity.z = move_toward(velocity.z, 0, SPEED)
							if debug_label: debug_label.text = "STOPPED (Reached Target)\nVel: 0"
						else:
							# Move towards current target
							var dir_to_next = flat_global.direction_to(flat_target)
							velocity.x = dir_to_next.x * (SPEED * 0.4)
							velocity.z = dir_to_next.z * (SPEED * 0.4)
							
							if debug_label: debug_label.text = "MOVING to WP " + str(custom_path_index) + "\nDist: " + str(dist).pad_decimals(2)
						
						# --- CAMERA FIX: DECOUPLE FROM BODY ROTATION ---
						if velocity.length_squared() > 0.01:
							var old_cam_basis = pitch_pivot.global_basis
							var target_transform = transform.looking_at(global_position + Vector3(velocity.x, 0, velocity.z).normalized(), Vector3.UP)
							transform = transform.interpolate_with(target_transform, 5.0 * delta)
							pitch_pivot.global_basis = old_cam_basis.orthonormalized()
						# -----------------------------------------------
						
		if multiplayer.is_server():
			if active_rescuer_id != -1:
				var rescuer = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(active_rescuer_id))
				if rescuer and rescuer.global_position.distance_to(global_position) <= 4.0:
					if not is_rescue_halted:
						is_rescue_halted = true
						rpc("sync_rescue_halt", true)
						
					rescue_progress += delta
					rpc("sync_rescue_progress", rescue_progress)
					
					if rescue_progress >= RESCUE_TIME_REQUIRED:
						active_rescuer_id = -1
						rpc("sync_active_rescuer", -1) # <-- ADD THIS
						rescue_progress = 0.0
						rpc("sync_rescue_progress", 0.0)
						rpc("sync_rescue_halt", false)
						rpc("rescue_successful")
				else:
					active_rescuer_id = -1
					rpc("sync_active_rescuer", -1) # <-- ADD THIS
					
					rescue_progress = 0.0 # <-- FIX: Reset progress if they walk away!
					rpc("sync_rescue_progress", 0.0) 
					
					if is_rescue_halted:
						is_rescue_halted = false
						rpc("sync_rescue_halt", false)
			else:
				if is_rescue_halted:
					is_rescue_halted = false
					rpc("sync_rescue_halt", false)
		return
		
	if carried_artifact:
		# Apply weight penalty instantly when holding an item
		current_speed_mult = carried_artifact.weight_penalty
	else:
		# If NOT holding an item, smoothly recover back to 1.0 (normal speed)
		# delta * 0.3 means it recovers 30% speed per second. 
		# (e.g., A 60% slow from a Large artifact will take 2 seconds to wear off)
		current_speed_mult = move_toward(current_speed_mult, 1.0, delta * 0.3)
		
	if direction:
		velocity.x = direction.x * (SPEED * current_speed_mult)
		velocity.z = direction.z * (SPEED * current_speed_mult)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * current_speed_mult)
		velocity.z = move_toward(velocity.z, 0, SPEED * current_speed_mult)
	
func _process(delta):
		# --- ADD THIS LINE RIGHT HERE! ---
	# This tells Godot to run the network smoothing math from Player.gd!
	super._process(delta) 
	# ---------------------------------
	# --- STEALTH & VISUALS ---
	if stealth_manager:
		var speed = 0.0
		if is_multiplayer_authority():
			speed = Vector3(velocity.x, 0, velocity.z).length()
		else:
			var dist = Vector3(global_position.x, 0, global_position.z).distance_to(Vector3(last_pos.x, 0, last_pos.z))
			speed = dist / delta
			last_pos = global_position
			
		stealth_manager.process_stealth(delta, speed, is_hypnotized, is_jailed, is_highlighted)

	# HIGHLIGHT & INTERACTION LOGIC (Runs ONLY for the local player)
	if not is_multiplayer_authority(): return
	
	## ---  RESCUE UI LOGIC ---
	if ui_manager:
		if is_jailed:
			ui_manager.update_rescue_ring(0.0, false) # Hide in jail
		elif is_hypnotized:
			# Feature: See your OWN rescue progress, but ONLY if someone is rescuing you!
			if active_rescuer_id != -1:
				ui_manager.update_rescue_ring(rescue_progress / RESCUE_TIME_REQUIRED, true)
			else:
				ui_manager.update_rescue_ring(0.0, false) # Hide if nobody is rescuing
		elif is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
			# Normal: See the progress of the person you are saving
			ui_manager.update_rescue_ring(current_interact_target.rescue_progress / RESCUE_TIME_REQUIRED, true)
		else:
			ui_manager.update_rescue_ring(0.0, false) # Default hide ring when empty
			
	
	# FIX: If hypnotized or jailed, immediately clear highlights and stop rescuing!
	if is_hypnotized or is_jailed:
		if stealth_manager: stealth_manager.update_outlines(null)
		if is_rescuing and current_interact_target and is_instance_valid(current_interact_target):
			rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null
		return

	# Scan for targets
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
		if global_position.distance_to(current_interact_target.global_position) > 3.0 or not current_interact_target.get("is_hypnotized"):
			rpc_id(1, "request_stop_rescue", int(str(current_interact_target.name)))
			is_rescuing = false
			current_interact_target = null


@rpc("any_peer", "call_local")
func on_captured():
	if is_hypnotized: return
	is_hypnotized = true
	disable_body_rotation = true 
	spawn_smoke()
	
	# --- 1. FORCE GODOT TO SCRAMBLE ITS RANDOM NUMBERS ---
	randomize() 
	# -----------------------------------------------------
	

		
	collision_layer = 8 
	collision_mask = 5  
	
	if carried_artifact:
		if multiplayer.is_server():
			carried_artifact.rpc("drop")
		carried_artifact = null
	
	var jails = get_tree().get_nodes_in_group("jail")
	if jails.size() > 0:
		var jail = jails.pick_random() 
		
		# --- 2. FOOLPROOF EXPLICIT ARRAY ---
		var possible_cells = [
			jail.get_node_or_null("CellTarget"),
			jail.get_node_or_null("CellTarget2"),
			jail.get_node_or_null("CellTarget3"),
			jail.get_node_or_null("CellTarget4")
		]
		
		# Filter out any nulls (just in case you ever delete one of the cells in the editor!)
		possible_cells = possible_cells.filter(func(node): return node != null)
		
		var cell_target = possible_cells.pick_random()
		# -----------------------------------
		
		var walk_pos = jail.get_node("WalkTarget").global_position
		var cell_pos = cell_target.global_position
		
		jail_cell_rot_y = cell_target.global_rotation.y 
		update_jail_targets(walk_pos, cell_pos)
		
	if multiplayer.is_server():
		GameManager.rpc("thief_captured")

@rpc("any_peer", "call_local")
func dev_toggle_hypnotize():
	if not is_hypnotized:
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
		is_hypnotized = false
		disable_body_rotation = false
		collision_layer = 2
		collision_mask = 3
		
		# Reset camera to look forward again
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
		# Draw a bright line 0.5m above the ground
		im_mesh.surface_add_vertex(path[i] + Vector3(0, 0.5, 0))
		im_mesh.surface_add_vertex(path[i+1] + Vector3(0, 0.5, 0))
	im_mesh.surface_end()
	debug_path_mesh.mesh = im_mesh

@rpc("any_peer", "call_local")
func request_start_rescue(target_id: int):
	if not multiplayer.is_server(): return
	var target = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(target_id))
	if target and target.get("is_hypnotized"):
		target.active_rescuer_id = multiplayer.get_remote_sender_id()
		target.rpc("sync_active_rescuer", target.active_rescuer_id) # <-- ADD THIS

@rpc("any_peer", "call_local")
func request_stop_rescue(target_id: int):
	if not multiplayer.is_server(): return
	var target = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects/" + str(target_id))
	if target and target.active_rescuer_id == multiplayer.get_remote_sender_id():
		target.active_rescuer_id = -1
		target.rpc("sync_active_rescuer", -1) # <-- ADD THIS

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
	
	is_hypnotized = false
	disable_body_rotation = false # Turn off free-look
	
	collision_layer = 4 
	collision_mask = 15 
	
	is_rescue_halted = false
	if pitch_pivot:
		pitch_pivot.rotation.y = 0 # Snap camera back to body's forward direction
		pitch_pivot.rotation.z = 0 # Fix any dutch-angle tilt introduced by the global_basis override
		
	if multiplayer.is_server():
		GameManager.rpc("thief_rescued")

# --- ADD cell_rot_y TO THE ARGUMENTS ---
@rpc("any_peer", "call_local")
func on_jailed(cell_pos: Vector3, cell_rot_y: float):
	is_hypnotized = false
	is_jailed = true
	disable_body_rotation = true 
	
	collision_layer = 4 
	collision_mask = 15 
	is_rescue_halted = false
	
	# --- ADD '+ PI' TO FLIP THEM 180 DEGREES ---
	global_position = cell_pos
	rotation.y = cell_rot_y + PI
	# -------------------------------------------
	
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

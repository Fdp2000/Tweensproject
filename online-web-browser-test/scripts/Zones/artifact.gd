extends Node3D

const ARTIFACT_PARTICLES = preload("uid://b4hha0q7y1chb")



enum Size { SMALL, MEDIUM, LARGE, CUSTOM }
@export var artifact_size: Size = Size.SMALL

@export_group("Custom Settings")
@export var custom_cash_value: int = 100
@export var custom_weight_penalty: float = 1.0

# --- NEW: CUSTOM HAND OFFSETS ---
# Tweak these in the editor so large paintings don't clip through the head!
@export var hand_position_offset: Vector3 = Vector3.ZERO
@export var hand_rotation_offset: Vector3 = Vector3.ZERO
@export var drop_height_offset: float = 0.0
@export var use_custom_camo_pose: bool = false
@export var camo_position_offset: Vector3 = Vector3.ZERO
@export var camo_rotation_offset: Vector3 = Vector3.ZERO
@export var pose_transition_duration: float = 0.5 # Tune this to perfectly match the AnimationTree transition time! 

var initial_scale: Vector3 = Vector3.ONE # We need this to prevent the bone from stretching the artifact

var cash_value: int = 100
var weight_penalty: float = 1.0
var is_carried: bool = false
var carrier_id: int = -1
var is_highlighted: bool = false:
	set(value):
		if is_highlighted != value:
			is_highlighted = value
			set_highlight(value)

var sync_target_position: Vector3 = Vector3.ZERO
var sync_target_rotation: Vector3 = Vector3.ZERO
var initial_position: Vector3 = Vector3.ZERO
var initial_rotation: Vector3 = Vector3.ZERO
var cached_attachment: Node3D = null
var camo_blend: float = 0.0
var locked_camo_basis_local: Basis = Basis()
var was_camo: bool = false

var debug_ui: CanvasLayer = null

var _last_rendered_highlight: bool = false
var _has_rendered_once: bool = false

var area: Area3D
var col: CollisionShape3D
var synchronizer: MultiplayerSynchronizer

func _ready():
	
	# Make sure this node is in the artifact group
	if not is_in_group("artifact"):
		add_to_group("artifact")
		
	# Programmatically create the interaction Area3D if it doesn't exist
	area = get_node_or_null("InteractionArea")
	if not area:
		area = Area3D.new()
		area.name = "InteractionArea"
		add_child(area)
	
	# Artifacts are on Layer 4, and only check for Players (Layer 2)
	area.collision_layer = 8 # Layer 4 (1 << 3)
	area.collision_mask = 2  # Layer 2 (Players)
	
	# Programmatically create the CollisionShape3D if it doesn't exist
	col = area.get_node_or_null("CollisionShape3D")
	if not col:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		
		# Try to auto-calculate size from meshes
		var aabb = _calculate_meshes_aabb(self)
		if aabb.size.length() > 0:
			box.size = aabb.size * 1.2 # Give it some padding
			col.position = aabb.position + aabb.size / 2.0
		else:
			box.size = Vector3(1, 1, 1)
			
		col.shape = box
		area.add_child(col)
	
	# Programmatically create the MultiplayerSynchronizer if it doesn't exist
	synchronizer = get_node_or_null("MultiplayerSynchronizer")
	if not synchronizer:
		synchronizer = MultiplayerSynchronizer.new()
		synchronizer.name = "MultiplayerSynchronizer"
		var config = SceneReplicationConfig.new()
		
		# Properties to sync
		var properties = [
			":artifact_size",
			":is_carried",
			":carrier_id",
			":sync_target_position",
			":sync_target_rotation"
		]
		
		for prop in properties:
			config.add_property(NodePath(prop))
			config.property_set_spawn(NodePath(prop), true)
			config.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		
		synchronizer.replication_config = config
		add_child(synchronizer)
	
	# Configure based on size using the Balance Autoload
	match artifact_size:
		Size.SMALL:
			cash_value = Balance.cash_small
			weight_penalty = Balance.artifact_small_speed_multiplier
		Size.MEDIUM:
			cash_value = Balance.cash_medium
			weight_penalty = Balance.artifact_medium_speed_multiplier
		Size.LARGE:
			cash_value = Balance.cash_large
			weight_penalty = Balance.artifact_large_speed_multiplier
		Size.CUSTOM:
			cash_value = custom_cash_value
			weight_penalty = custom_weight_penalty
	
	# Add Particles
	var particles_instance = get_node_or_null("artifactParticles")
	
	if particles_instance != null:
		# The user manually added the 'artifact_particles.tscn' to the artifact scene in the editor!
		# We don't need to dynamically scale or move it, because the user placed it perfectly themselves.
		particles_instance.emitting = true
	else:
		# Dynamic generation for artifacts that don't have it manually placed
		particles_instance = ARTIFACT_PARTICLES.instantiate()
		self.add_child(particles_instance)
		
		var final_radius = 1.0
		var final_pos = Vector3.ZERO
		
		# Calculate the size of the artifact meshes to dynamically scale the particles
		var mesh_aabb = _calculate_meshes_aabb(self)
		var max_size = max(mesh_aabb.size.x, max(mesh_aabb.size.y, mesh_aabb.size.z))
		final_pos = mesh_aabb.get_center()
		
		# If the mesh AABB is broken (e.g. bad 3D data) and max_size is tiny, fallback to the CollisionShape3D!
		if max_size <= 0.01 and is_instance_valid(col) and col.shape:
			if col.shape is BoxShape3D:
				max_size = max(col.shape.size.x, max(col.shape.size.y, col.shape.size.z))
			elif col.shape is SphereShape3D:
				max_size = col.shape.radius * 2.0
			elif col.shape is CapsuleShape3D or col.shape is CylinderShape3D:
				max_size = max(col.shape.radius * 2.0, col.shape.height)
			else:
				max_size = 2.0 # Ultimate fallback
				
			final_pos = self.to_local(col.global_position)
		
		# Calculate radius from size plus buffer
		final_radius = (max_size / 2.0) + 0.2

		# Set the particle's emission sphere radius
		particles_instance.emission_sphere_radius = final_radius
		particles_instance.position = final_pos
		particles_instance.emitting = true

	initial_position = global_position
	initial_rotation = rotation
	sync_target_position = global_position
	sync_target_rotation = rotation
	initial_scale = scale

func _calculate_meshes_aabb(node: Node) -> AABB:
	var total_aabb = AABB()
	var found_mesh = false
	
	for child in node.get_children():
		# Include this node's mesh if it has one
		if child is MeshInstance3D and child.get_mesh():
			var mesh_aabb = child.get_mesh().get_aabb()
			# Transform mesh AABB to parent space
			var local_aabb = child.transform * mesh_aabb
			if not found_mesh:
				total_aabb = local_aabb
				found_mesh = true
			else:
				total_aabb = total_aabb.merge(local_aabb)
		
		# Recurse down to children
		var sub_aabb = _calculate_meshes_aabb(child)
		if sub_aabb.size.length() > 0:
			# If the child is a Node3D, transform its accumulated children's AABB into our space!
			if child is Node3D:
				sub_aabb = child.transform * sub_aabb
				
			if not found_mesh:
				total_aabb = sub_aabb
				found_mesh = true
			else:
				total_aabb = total_aabb.merge(sub_aabb)
				
	return total_aabb

@rpc("any_peer", "call_local")
func request_pickup(player_id: int):
	if not multiplayer.is_server(): return
	if is_carried: return
	
	# Server validates and grants pickup
	rpc("confirm_pickup", player_id)

@rpc("any_peer", "call_local")
func confirm_pickup(player_id: int):
	AudioManager.play_3d_sfx("artifact_pickup", global_position)
	var particles = get_node("artifactParticles")
	particles.emitting = false
	is_carried = true
	carrier_id = player_id
	is_highlighted = false # FIX: Force highlight off when picked up
	set_multiplayer_authority(player_id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(player_id)
	
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if spawned:
		var carrier = spawned.get_node_or_null(str(carrier_id))
		if carrier and carrier.has_method("on_artifact_pickup"):
			carrier.on_artifact_pickup(self)
			cached_attachment = carrier.get_node_or_null("Chameleon_Character/Chameleon_Character/metarig/Skeleton3D/ArtifactAttachment")

static var outline_mat: ShaderMaterial = null

func _process(delta):
	if is_carried:
		if is_multiplayer_authority():
			# I am carrying it, so I control it
			if cached_attachment:
				var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
				var carrier = spawned.get_node_or_null(str(carrier_id)) if spawned else null
				
				# --- CAMO BLEND CALCULATION ---
				var is_camo = false
				var is_tuning_drop = Input.is_key_pressed(KEY_B) or Input.is_key_pressed(KEY_N)
				var preview_camo = Input.is_key_pressed(KEY_C)
				if carrier and carrier.get("stealth_manager"):
					if carrier.stealth_manager.stationary_time >= Balance.thief_camo_activation_time:
						is_camo = true
						
				if is_tuning_drop or preview_camo:
					is_camo = true
						
				var visual_base: Node3D = carrier
				if carrier:
					if carrier.get("visual_mesh"):
						visual_base = carrier.visual_mesh
					elif carrier.has_node("Chameleon_Character"):
						visual_base = carrier.get_node("Chameleon_Character")
						
				if is_camo and not was_camo:
					if carrier:
						locked_camo_basis_local = (visual_base.global_transform.basis.inverse() * global_transform.basis).orthonormalized()
					else:
						locked_camo_basis_local = global_transform.basis.orthonormalized()
				was_camo = is_camo
						
				if is_camo:
					camo_blend = move_toward(camo_blend, 1.0, delta / pose_transition_duration)
				else:
					camo_blend = move_toward(camo_blend, 0.0, delta / pose_transition_duration)
				
				# --- 1. HAND TRANSFORM (Normal Carry) ---
				var hand_transform = cached_attachment.global_transform
				if carrier:
					hand_transform.origin += carrier.global_transform.basis * hand_position_offset
					
				# Apply local rotation offsets
				var hand_basis = hand_transform.basis
				hand_basis = hand_basis.rotated(hand_basis.x.normalized(), deg_to_rad(hand_rotation_offset.x))
				hand_basis = hand_basis.rotated(hand_basis.y.normalized(), deg_to_rad(hand_rotation_offset.y))
				hand_basis = hand_basis.rotated(hand_basis.z.normalized(), deg_to_rad(hand_rotation_offset.z))
				hand_transform.basis = hand_basis
				
				# --- 2. TARGET TRANSFORM (Floor or Custom Pose) ---
				var floor_transform = Transform3D()
				if use_custom_camo_pose:
					floor_transform = cached_attachment.global_transform
					if carrier:
						floor_transform.origin += carrier.global_transform.basis * camo_position_offset
					var c_basis = floor_transform.basis
					c_basis = c_basis.rotated(c_basis.x.normalized(), deg_to_rad(camo_rotation_offset.x))
					c_basis = c_basis.rotated(c_basis.y.normalized(), deg_to_rad(camo_rotation_offset.y))
					c_basis = c_basis.rotated(c_basis.z.normalized(), deg_to_rad(camo_rotation_offset.z))
					floor_transform.basis = c_basis
				elif carrier:
					# Raycast straight down from the hand, exactly like drop()
					var drop_origin = hand_transform.origin
					var space_state = get_world_3d().direct_space_state
					var query = PhysicsRayQueryParameters3D.create(drop_origin + Vector3(0, 1, 0), drop_origin + Vector3(0, -10, 0))
					query.collision_mask = 1
					var result = space_state.intersect_ray(query)
					
					if result:
						floor_transform.origin = result.position + Vector3(0, drop_height_offset, 0)
					else:
						floor_transform.origin = drop_origin
				else:
					floor_transform = hand_transform
					
				# --- 3. BLEND AND APPLY ---
				global_position = hand_transform.origin.lerp(floor_transform.origin, camo_blend)
				
				if use_custom_camo_pose:
					global_transform.basis = hand_transform.basis.orthonormalized().slerp(floor_transform.basis.orthonormalized(), camo_blend)
				else:
					if is_camo:
						# Lock rotation immediately to prevent bone twisting during the camo transition
						if carrier:
							global_transform.basis = visual_base.global_transform.basis * locked_camo_basis_local
						else:
							global_transform.basis = locked_camo_basis_local
					else:
						# Blend back to the hand bone if camo breaks while blending
						if camo_blend > 0.0 and carrier:
							var locked_basis = (visual_base.global_transform.basis * locked_camo_basis_local).orthonormalized()
							global_transform.basis = hand_transform.basis.orthonormalized().slerp(locked_basis, camo_blend)
						else:
							global_transform.basis = hand_transform.basis
				
				# 4. Lock the scale so the bone animations don't warp the mesh
				scale = initial_scale 
				
				# 5. Developer In-Game Tuning Tool
				# Keyboard Controls for live tuning!
				var tune_pos_y = 0.0
				var tune_pos_x = 0.0
				var tune_pos_z = 0.0
				var tune_rot_x = 0.0
				var tune_rot_y = 0.0
				var tune_rot_z = 0.0
				
				if Input.is_key_pressed(KEY_PAGEUP): tune_pos_y += delta * 0.5
				if Input.is_key_pressed(KEY_PAGEDOWN): tune_pos_y -= delta * 0.5
				if Input.is_key_pressed(KEY_LEFT): tune_pos_x -= delta * 0.5
				if Input.is_key_pressed(KEY_RIGHT): tune_pos_x += delta * 0.5
				if Input.is_key_pressed(KEY_UP): tune_pos_z -= delta * 0.5
				if Input.is_key_pressed(KEY_DOWN): tune_pos_z += delta * 0.5
				
				if Input.is_key_pressed(KEY_U): tune_rot_x += delta * 45.0
				if Input.is_key_pressed(KEY_J): tune_rot_x -= delta * 45.0
				if Input.is_key_pressed(KEY_I): tune_rot_y += delta * 45.0
				if Input.is_key_pressed(KEY_K): tune_rot_y -= delta * 45.0
				if Input.is_key_pressed(KEY_O): tune_rot_z += delta * 45.0
				if Input.is_key_pressed(KEY_L): tune_rot_z -= delta * 45.0
				
				if preview_camo and use_custom_camo_pose:
					camo_position_offset += Vector3(tune_pos_x, tune_pos_y, tune_pos_z)
					camo_rotation_offset += Vector3(tune_rot_x, tune_rot_y, tune_rot_z)
				else:
					hand_position_offset += Vector3(tune_pos_x, tune_pos_y, tune_pos_z)
					hand_rotation_offset += Vector3(tune_rot_x, tune_rot_y, tune_rot_z)
				
				if Input.is_key_pressed(KEY_B): drop_height_offset += delta * 0.5
				if Input.is_key_pressed(KEY_N): drop_height_offset -= delta * 0.5
				
				if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_P): 
					print("--- ARTIFACT TUNED ---")
					print("Pos Offset: ", hand_position_offset)
					print("Rot Offset: ", hand_rotation_offset)
					print("Drop Offset: ", drop_height_offset)
					if use_custom_camo_pose:
						print("Camo Pos Offset: ", camo_position_offset)
						print("Camo Rot Offset: ", camo_rotation_offset)
				
				if not debug_ui:
					_create_debug_ui()
			
			# Relay position to others by keeping sync targets updated
			sync_target_position = global_position
			sync_target_rotation = rotation
		else:
			# I am observing someone else carry it
			if debug_ui:
				debug_ui.queue_free()
				debug_ui = null
			global_position = global_position.lerp(sync_target_position, 15.0 * delta)
			var current_quat = transform.basis.get_rotation_quaternion()
			var target_quat = Quaternion.from_euler(sync_target_rotation)
			transform.basis = Basis(current_quat.slerp(target_quat, 15.0 * delta)).scaled(initial_scale)
	else:
		if debug_ui:
			debug_ui.queue_free()
			debug_ui = null
		# It's not carried, so smoothly lerp to wherever the authority (usually server) says it should be
		global_position = global_position.lerp(sync_target_position, 15.0 * delta)
		
		# Slerp the rotation for smoothness
		var current_quat = transform.basis.get_rotation_quaternion()
		var target_quat = Quaternion.from_euler(sync_target_rotation)
		transform.basis = Basis(current_quat.slerp(target_quat, 15.0 * delta)).scaled(initial_scale)

func set_highlight(highlighted: bool):
	if highlighted and is_carried: return
	
	# Find the mesh and update materials
	for child in get_children():
		if child.name == "InteractionArea": continue
		_apply_visuals(child, highlighted)

func _apply_visuals(node: Node, highlighted: bool):
	if not outline_mat:
		outline_mat = ShaderMaterial.new()
		outline_mat.shader = preload("res://Assets/Shaders/HighlightShader/newOutline.gdshader")
		outline_mat.set_shader_parameter("outline_color", Color(1, 1, 1, 1))
		outline_mat.set_shader_parameter("outline_width", 4.0)
			
	if node is MeshInstance3D:
		if highlighted:
			node.material_overlay = outline_mat
		else:
			if node.material_overlay == outline_mat:
				node.material_overlay = null
					
	for child in node.get_children():
		if child.name == "InteractionArea": continue
		_apply_visuals(child, highlighted)

@rpc("any_peer", "call_local")
func drop():
	AudioManager.play_3d_sfx("artifact_drop", global_position)
	if carrier_id != -1:
		var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
		var carrier = spawned.get_node_or_null(str(carrier_id)) if spawned else null
		if carrier and carrier.has_method("on_artifact_drop"):
			carrier.on_artifact_drop()
			
	is_carried = false
	cached_attachment = null
	var particles = get_node("artifactParticles")
	particles.emitting = true
	carrier_id = -1
	
	# All peers must agree the server has taken back control!
	set_multiplayer_authority(1)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
		
	is_highlighted = false # FIX: Force highlight off when dropped
	
	# Snap to the ground perfectly
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), global_position + Vector3(0, -10, 0))
	query.collision_mask = 1 # Environment layer
	var result = space_state.intersect_ray(query)
	
	if result:
		sync_target_position = result.position + Vector3(0, drop_height_offset, 0)

@rpc("any_peer", "call_local")
func destroy_artifact():
	AudioManager.play_3d_sfx("artifact_delivery", global_position)
	if carrier_id != -1:
		var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
		var carrier = spawned.get_node_or_null(str(carrier_id)) if spawned else null
		if carrier and carrier.has_method("on_artifact_drop"):
			carrier.on_artifact_drop()
			
	is_carried = false
	cached_attachment = null
	carrier_id = -1
	
	# All peers must agree the server has taken back control!
	set_multiplayer_authority(1)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
	
	is_highlighted = false # FIX: Force highlight off when destroyed
	hide()
	var area = col.get_parent()
	if area is Area3D:
		area.collision_layer = 0
		area.collision_mask = 0

@rpc("any_peer", "call_local")
func reset_artifact():
	is_carried = false
	cached_attachment = null
	carrier_id = -1
	
	# All peers must agree the server has taken back control!
	set_multiplayer_authority(1)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
	
	is_highlighted = false # FIX: Force highlight off for the next round
	show()
	var area = col.get_parent()
	if area is Area3D:
		area.collision_layer = 8
		area.collision_mask = 2
	global_position = initial_position
	rotation = initial_rotation
	sync_target_position = initial_position
	sync_target_rotation = initial_rotation
	
func _exit_tree() -> void:
	if synchronizer:
		synchronizer.public_visibility = false

func _create_debug_ui():
	debug_ui = CanvasLayer.new()
	debug_ui.layer = 100
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(800, 50)
	debug_ui.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "--- ARTIFACT OFFSET TUNER ---"
	vbox.add_child(title)
	
	var lbl = Label.new()
	vbox.add_child(lbl)
	
	var update_lbl = func():
		if is_instance_valid(lbl):
			var camo_str = ""
			var camo_keys = ""
			if use_custom_camo_pose:
				camo_str = "\nCamo Pos: " + str(camo_position_offset) + "\nCamo Rot: " + str(camo_rotation_offset)
				camo_keys = "\nHold C + move/rotate to tune Camo Pose."
			lbl.text = "Pos Offset: " + str(hand_position_offset) + "\nRot Offset: " + str(hand_rotation_offset) + "\nDrop Offset: " + str(drop_height_offset) + camo_str + "\n\nUse PageUp/PageDown (Y), Left/Right (X), Up/Down (Z) to move.\nUse U/J (X), I/K (Y), O/L (Z) to rotate.\nUse B/N to adjust Drop Height." + camo_keys + "\nPress P to print to console."
	update_lbl.call()
	
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(update_lbl)
	debug_ui.add_child(timer)
	
	get_tree().root.add_child(debug_ui)

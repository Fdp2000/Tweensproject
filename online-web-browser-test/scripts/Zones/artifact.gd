extends Node3D

const ARTIFACT_PARTICLES = preload("uid://b4hha0q7y1chb")



enum Size { SMALL, MEDIUM, LARGE }
@export var artifact_size: Size = Size.SMALL

# --- NEW: ARTIFACT CATEGORIZATION ---
enum Category { SMALL_PROP, FLOOR_PROP, WALL_PROP }
@export var artifact_category: Category = Category.SMALL_PROP

# --- NEW: CUSTOM HAND OFFSETS ---
# Tweak these in the editor so large paintings don't clip through the head!
@export var hand_position_offset: Vector3 = Vector3.ZERO
@export var hand_rotation_offset: Vector3 = Vector3.ZERO 

var initial_scale: Vector3 = Vector3.ONE # We need this to prevent the bone from stretching the artifact

var cash_value: int = 100
var weight_penalty: float = 1.0
var is_carried: bool = false
var carrier_id: int = -1
var is_highlighted: bool = false

var sync_target_position: Vector3 = Vector3.ZERO
var sync_target_rotation: Vector3 = Vector3.ZERO
var initial_position: Vector3 = Vector3.ZERO
var initial_rotation: Vector3 = Vector3.ZERO
var cached_attachment: Node3D = null

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
	
	# Add Particles
	var particles_instance = ARTIFACT_PARTICLES.instantiate()
	self.add_child(particles_instance)
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
		if child is MeshInstance3D:
			var mesh_aabb = child.get_mesh().get_aabb()
			# Transform mesh AABB to parent space
			var local_aabb = child.transform * mesh_aabb
			if not found_mesh:
				total_aabb = local_aabb
				found_mesh = true
			else:
				total_aabb = total_aabb.merge(local_aabb)
		
		# Recurse
		var sub_aabb = _calculate_meshes_aabb(child)
		if sub_aabb.size.length() > 0:
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
	var particles = get_node("artifactParticles")
	particles.emitting = false
	is_carried = true
	carrier_id = player_id
	is_highlighted = false # FIX: Force highlight off when picked up
	set_multiplayer_authority(player_id)
	
	var carrier = get_node_or_null("/root/World/main/SpawnedObjects/" + str(carrier_id))
	if carrier and carrier.has_method("on_artifact_pickup"):
		carrier.on_artifact_pickup(self)
		cached_attachment = carrier.get_node_or_null("Chameleon_Character/Chameleon_Character/metarig/Skeleton3D/ArtifactAttachment")

var outline_mat: ShaderMaterial = null

func _process(delta):
	if is_carried:
		if is_multiplayer_authority():
			# I am carrying it, so I control it
			if cached_attachment:
				# 1. Snap perfectly to the Chameleon's hand bone
				global_transform = cached_attachment.global_transform
				
				# 2. Apply your custom position offset (Relative to the hand's rotation)
				translate_object_local(hand_position_offset)
					
				# 3. Apply your custom rotation offset (Converted to standard degrees!)
				var rot_rad = Vector3(
					deg_to_rad(hand_rotation_offset.x), 
					deg_to_rad(hand_rotation_offset.y), 
					deg_to_rad(hand_rotation_offset.z)
				)
				var rot_basis = Basis.from_euler(rot_rad)
				global_transform.basis = global_transform.basis * rot_basis
				
				# 4. Lock the scale so the bone animations don't warp the mesh
				scale = initial_scale 
			
			# Relay position to others by keeping sync targets updated
			sync_target_position = global_position
			sync_target_rotation = rotation
		else:
			# I am observing someone else carry it
			global_position = global_position.lerp(sync_target_position, 15.0 * delta)
			var current_quat = transform.basis.get_rotation_quaternion()
			var target_quat = Quaternion(Basis.from_euler(sync_target_rotation))
			transform.basis = Basis(current_quat.slerp(target_quat, 15.0 * delta)).scaled(initial_scale)
	
	# Update visual highlights
	if is_highlighted != _last_rendered_highlight or not _has_rendered_once:
		_apply_visuals(self, is_highlighted)
		_last_rendered_highlight = is_highlighted
		_has_rendered_once = true

func _apply_visuals(node: Node, highlighted: bool):
	if not outline_mat:
		outline_mat = ShaderMaterial.new()
		var shader = preload("res://Assets/Shaders/HighlightShader/OutlineShader.tres")
		if shader:
			outline_mat.shader = shader
			
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_surface_override_material(i)
			if not mat:
				mat = node.mesh.surface_get_material(i)
				
			if mat:
				var unique_mat = null
				if node.has_meta("unique_mat_" + str(i)):
					unique_mat = node.get_meta("unique_mat_" + str(i))
				else:
					unique_mat = mat.duplicate()
					node.set_meta("unique_mat_" + str(i), unique_mat)
					node.set_surface_override_material(i, unique_mat)
				
				if highlighted:
					unique_mat.next_pass = outline_mat
				else:
					unique_mat.next_pass = null
					
	for child in node.get_children():
		if child.name == "InteractionArea": continue
		_apply_visuals(child, highlighted)

@rpc("any_peer", "call_local")
func drop():
	if carrier_id != -1:
		var carrier = get_node_or_null("/root/World/main/SpawnedObjects/" + str(carrier_id))
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

	# ==========================================
	# --- NEW: RAYCAST FLOOR SNAP ---
	# ==========================================
	var space_state = get_world_3d().direct_space_state
	
	# Shoot a laser 10 meters straight down from the artifact's current center
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 10.0)
	
	# IMPORTANT: We only want to hit the Floor/Walls (Assuming your environment is on Collision Layer 1)
	# This prevents the artifact from accidentally snapping to the top of the Thief's head!
	query.collision_mask = 1 
	
	# Ignore the artifact's entire physics body so the laser doesn't hit itself
	if col:
		query.exclude = [col.get_parent().get_rid()]
		
	var result = space_state.intersect_ray(query)
	
	if result:
		# We found the floor! Snap the position down.
		global_position = result.position
		
		# Update the network sync targets so it doesn't try to lerp back up into the air
		sync_target_position = result.position
		initial_position = result.position
		initial_rotation = rotation

@rpc("any_peer", "call_local")
func destroy_artifact():
	if carrier_id != -1:
		var carrier = get_node_or_null("/root/World/main/SpawnedObjects/" + str(carrier_id))
		if carrier and carrier.has_method("on_artifact_drop"):
			carrier.on_artifact_drop()
			
	is_carried = false
	cached_attachment = null
	carrier_id = -1
	is_highlighted = false # FIX: Force highlight off when destroyed
	hide()
	col.set_deferred("disabled", true)

@rpc("any_peer", "call_local")
func reset_artifact():
	is_carried = false
	cached_attachment = null
	carrier_id = -1
	is_highlighted = false # FIX: Force highlight off for the next round
	show()
	col.set_deferred("disabled", false)
	global_position = initial_position
	rotation = initial_rotation
	sync_target_position = initial_position
	sync_target_rotation = initial_rotation
	
func _exit_tree() -> void:
	if synchronizer:
		synchronizer.public_visibility = false

extends Node3D
class_name DottedRing

@export var radius: float = 4.0:
	set(val):
		radius = val
		_request_update_dots()

@export var dot_density: float = 25.0:
	set(val):
		dot_density = val
		_request_update_dots()

@export var custom_dot_count: int = 0:
	set(val):
		custom_dot_count = val
		_request_update_dots()

@export var sync_with_balance: bool = true
@export var fade_in_on_start: bool = true

@export_group("Raycast Settings")
@export var raycast_height: float = 2.0
@export var raycast_depth: float = 10.0

@export var dot_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(val):
		dot_color = val
		if _material:
			_material.albedo_color = dot_color

@export var dot_size: float = 0.075:
	set(val):
		dot_size = val
		_request_update_dots()

var multimesh_instance: MultiMeshInstance3D
var _material: StandardMaterial3D
var _current_rotation: float = 0.0
var max_alpha: float = 0.25
var _dots_need_update: bool = false

func _request_update_dots():
	if not is_inside_tree(): return
	_dots_need_update = true
	set_physics_process(true)

func _ready():
	if fade_in_on_start:
		add_to_group("dotted_rings")

	if not multimesh_instance:
		multimesh_instance = MultiMeshInstance3D.new()
		add_child(multimesh_instance)
		
		var mesh = SphereMesh.new()
		mesh.radius = dot_size / 2.0
		mesh.height = dot_size
		
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = dot_color
		
		multimesh_instance.material_override = _material
		multimesh_instance.multimesh = MultiMesh.new()
		multimesh_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh_instance.multimesh.mesh = mesh

	if not Engine.is_editor_hint():
		if fade_in_on_start:
			add_to_group("dotted_rings")
	
	# The instance_count is updated inside _update_dots


	# Sync radius with Balance singleton
	if sync_with_balance and Balance:
		radius = Balance.delivery_zone_radius
		Balance.balance_updated.connect(_on_balance_updated)
		
	# Handle visibility based on GameManager state
	if fade_in_on_start and GameManager:
		GameManager.game_started.connect(_on_game_started)
		GameManager.game_ended.connect(_on_game_ended)
		
		if GameManager.current_state == GameManager.GameState.LOBBY:
			hide()
			set_process(false)
			
	_request_update_dots()

func _physics_process(delta):
	if _dots_need_update:
		_update_dots()
		_dots_need_update = false
		set_physics_process(false)

func _update_dots():
	var actual_dot_count = custom_dot_count
	if actual_dot_count <= 0:
		actual_dot_count = int(radius * dot_density)
		
	if actual_dot_count <= 0: return
	
	multimesh_instance.multimesh.instance_count = actual_dot_count
	var space_state = get_world_3d().direct_space_state
	
	for i in range(actual_dot_count):
		var angle = (float(i) / actual_dot_count) * TAU
		var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		
		# Start raycast slightly above the center point to avoid hitting the ceiling
		var start_pos = global_position + offset + Vector3(0, raycast_height, 0)
		var end_pos = global_position + offset - Vector3(0, raycast_depth, 0)
		
		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.collision_mask = 1 # Only hit world geometry (Layer 1)
		
		var result = space_state.intersect_ray(query)
		
		var final_pos = global_position + offset
		if result:
			# Place slightly above the hit point along the normal
			final_pos = result.position + result.normal * 0.05
			
		# Convert to local position for the multimesh
		var local_pos = to_local(final_pos)
		var t = Transform3D(Basis(), local_pos)
		multimesh_instance.multimesh.set_instance_transform(i, t)

func _on_balance_updated():
	radius = Balance.delivery_zone_radius

func _on_game_started():
	show()
	set_process(true)
	# We start with 0 alpha, it will be faded in by CutsceneManager!
	set_alpha(0.0)
	_request_update_dots()

func _on_game_ended():
	hide()
	set_process(false)
	set_alpha(0.0)

func set_alpha(a: float):
	var c = dot_color
	c.a = a
	dot_color = c
	if _material:
		_material.albedo_color = dot_color

func fade_in(duration: float):
	var tween = create_tween()
	tween.tween_method(set_alpha, dot_color.a, max_alpha, duration)

func show_immediately():
	set_alpha(max_alpha)

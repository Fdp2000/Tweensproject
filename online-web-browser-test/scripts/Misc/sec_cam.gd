@tool
extends Node3D

@export_category("Camera Limits")
@export_range(-360, 360, 0.1, "radians_as_degrees") var max_yaw: float = deg_to_rad(60.0)
@export_range(-360, 360, 0.1, "radians_as_degrees") var min_yaw: float = deg_to_rad(-60.0)
@export_range(-360, 360, 0.1, "radians_as_degrees") var max_pitch: float = deg_to_rad(30.0)
@export_range(-360, 360, 0.1, "radians_as_degrees") var min_pitch: float = deg_to_rad(-30.0)

@export_category("Audio Settings")
@export_enum("base_tension", "biome_forest", "biome_egypt", "biome_island", "biome_antarctica", "biome_asia") var camera_biome: String = "base_tension"

@export_category("Starting Position")
@export_range(-360, 360, 0.1, "radians_as_degrees") var start_yaw: float = 0.0:
	set(value):
		start_yaw = value
		_update_editor_rotation()
		
@export_range(-360, 360, 0.1, "radians_as_degrees") var start_pitch: float = 0.0:
	set(value):
		start_pitch = value
		_update_editor_rotation()

@export_category("Quick Set Limits")
@export var Set_Max_Yaw_To_Current: bool = false:
	set(value):
		if is_node_ready() and pivot:
			max_yaw = pivot.rotation.y
		notify_property_list_changed()
@export var Set_Min_Yaw_To_Current: bool = false:
	set(value):
		if is_node_ready() and pivot:
			min_yaw = pivot.rotation.y
		notify_property_list_changed()
@export var Set_Max_Pitch_To_Current: bool = false:
	set(value):
		if is_node_ready() and pivot:
			max_pitch = pivot.rotation.x
		notify_property_list_changed()
@export var Set_Min_Pitch_To_Current: bool = false:
	set(value):
		if is_node_ready() and pivot:
			min_pitch = pivot.rotation.x
		notify_property_list_changed()

@export_category("Preview Tool")
@export var enable_preview_sliders: bool = false:
	set(value):
		enable_preview_sliders = value
		if not value:
			_update_editor_rotation()
		else:
			_update_preview_slider()

@export_range(0, 100, 1) var preview_yaw_slider: float = 50.0:
	set(value):
		preview_yaw_slider = value
		if enable_preview_sliders:
			_update_preview_slider()

@export_range(0, 100, 1) var preview_pitch_slider: float = 50.0:
	set(value):
		preview_pitch_slider = value
		if enable_preview_sliders:
			_update_preview_slider()

@onready var pivot = $pivotPoint
@onready var cam = find_child("Camera3D", true, false)
@onready var red_light = $pivotPoint/Camera_2/Object_9

# The Queue: First person in this list is the primary controller
var viewers: Array[int] = []
var primary_controller_id: int = 0
var target_rotation: Vector3 = Vector3.ZERO

func _ready():
	if Engine.is_editor_hint():
		_update_editor_rotation()
		return
		
	# Game logic only
	add_to_group("SecurityCameras")
	pivot.rotation.y = start_yaw
	pivot.rotation.x = -start_pitch
	target_rotation = Vector3(-start_pitch, start_yaw, 0)
	_update_red_light()

func _update_editor_rotation():
	if is_node_ready() and pivot and not enable_preview_sliders:
		pivot.rotation.y = start_yaw
		pivot.rotation.x = -start_pitch
		if cam:
			cam.rotation.y = start_yaw
			cam.rotation.x = start_pitch

func _update_preview_slider():
	if is_node_ready() and pivot and enable_preview_sliders:
		var actual_min_y = min(min_yaw, max_yaw)
		var actual_max_y = max(min_yaw, max_yaw)
		var actual_min_p = min(min_pitch, max_pitch)
		var actual_max_p = max(min_pitch, max_pitch)
		
		var current_yaw = lerp(actual_min_y, actual_max_y, preview_yaw_slider / 100.0)
		var current_pitch = lerp(actual_min_p, actual_max_p, preview_pitch_slider / 100.0)
		
		pivot.rotation.y = current_yaw
		pivot.rotation.x = -current_pitch
		
		if cam:
			cam.rotation.y = current_yaw
			cam.rotation.x = current_pitch

func _process(delta):
	if Engine.is_editor_hint():
		return
		
	# SMOOTH LERP FOR EVERYONE!
	# This ensures that when control is handed over, the camera 
	# smoothly travels from the old rotation to the new rotation.
	if primary_controller_id != 0:
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_rotation.y, 5.0 * delta)
		pivot.rotation.x = lerp_angle(pivot.rotation.x, target_rotation.x, 5.0 * delta)

@rpc("any_peer", "call_local")
func request_control(peer_id: int):
	if not viewers.has(peer_id):
		viewers.append(peer_id)
	_evaluate_primary()

@rpc("any_peer", "call_local")
func release_control(peer_id: int):
	if viewers.has(peer_id):
		viewers.erase(peer_id)
	_evaluate_primary()

func _evaluate_primary():
	if viewers.size() > 0:
		primary_controller_id = viewers[0]
	else:
		primary_controller_id = 0
	_update_red_light()

@rpc("unreliable", "any_peer")
func sync_rotation(yaw: float, pitch: float, peer_id: int):
	# Only listen to the person at the front of the queue
	if primary_controller_id == peer_id:
		target_rotation.y = yaw
		target_rotation.x = -pitch

func _update_red_light():
	if not red_light: return
	if red_light.mesh and red_light.mesh.get_surface_count() > 0:
		var mat = red_light.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate() 
			if primary_controller_id != 0:
				mat.albedo_color = Color(1.0, 0.0, 0.0)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.0, 0.0)
				# --- ADD THIS: Overdrive the brightness ---
				mat.emission_energy_multiplier = 8.0 
			else:
				mat.albedo_color = Color(0.2, 0.2, 0.2) 
				mat.emission_enabled = false
			red_light.set_surface_override_material(0, mat)

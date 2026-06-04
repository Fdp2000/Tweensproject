@tool
extends Node3D

@export_category("Camera Limits")
@export_range(-360, 360, 0.1, "radians_as_degrees") var max_yaw: float = deg_to_rad(60.0)
@export_range(-360, 360, 0.1, "radians_as_degrees") var min_yaw: float = deg_to_rad(-60.0)
@export_range(-360, 360, 0.1, "radians_as_degrees") var max_pitch: float = deg_to_rad(30.0)
@export_range(-360, 360, 0.1, "radians_as_degrees") var min_pitch: float = deg_to_rad(-30.0)

@export_category("Starting Position")
@export_range(-360, 360, 0.1, "radians_as_degrees") var start_yaw: float = 0.0:
	set(value):
		start_yaw = value
		_update_editor_rotation()
		
@export_range(-360, 360, 0.1, "radians_as_degrees") var start_pitch: float = 0.0:
	set(value):
		start_pitch = value
		_update_editor_rotation()

@export_category("Preview Tool")
@export var preview_camera_sweep: bool = false

@onready var pivot = $pivotPoint
# UPDATE PATH: Camera is no longer inside pivotPoint!
@onready var cam = $CameraMount/Camera3D
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
	pivot.rotation.y = start_yaw
	pivot.rotation.x = start_pitch
	target_rotation = Vector3(start_pitch, start_yaw, 0)
	_update_red_light()

func _update_editor_rotation():
	if is_node_ready() and pivot and not preview_camera_sweep:
		pivot.rotation.y = start_yaw
		pivot.rotation.x = start_pitch

func _process(delta):
	if Engine.is_editor_hint():
		if preview_camera_sweep and is_node_ready() and pivot:
			var time = Time.get_ticks_msec() / 1000.0
			# Sine wave from -1 to 1 for sweeping left/right
			var sweep_y = sin(time * 1.5)
			# Cosine wave for sweeping up/down (slightly different frequency so it hits all corners)
			var sweep_x = cos(time * 2.1)
			
			var center_y = (min_yaw + max_yaw) / 2.0
			var range_y = (max_yaw - min_yaw) / 2.0
			var center_x = (min_pitch + max_pitch) / 2.0
			var range_x = (max_pitch - min_pitch) / 2.0
			
			pivot.rotation.y = center_y + sweep_y * range_y
			pivot.rotation.x = center_x + sweep_x * range_x
		elif is_node_ready() and pivot:
			# Snap back to the starting position when disabled
			pivot.rotation.y = start_yaw
			pivot.rotation.x = start_pitch
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

extends Node3D

@export var max_yaw: float = 60.0
@export var min_yaw: float = -60.0
@export var max_pitch: float = 30.0
@export var min_pitch: float = -30.0

@onready var pivot = $pivotPoint
# UPDATE PATH: Camera is no longer inside pivotPoint!
@onready var cam = $Camera3D 
@onready var red_light = $pivotPoint/Camera_2/Object_9

# The Queue: First person in this list is the primary controller
var viewers: Array[int] = []
var primary_controller_id: int = 0
var target_rotation: Vector3 = Vector3.ZERO

func _ready():
	_update_red_light()

func _process(delta):
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
		target_rotation.x = pitch

func _update_red_light():
	if not red_light: return
	if red_light.mesh and red_light.mesh.get_surface_count() > 0:
		var mat = red_light.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate() 
			if primary_controller_id != 0:
				mat.emission_enabled = true
				mat.albedo_color = Color(1.0, 0.0, 0.0) 
			else:
				mat.emission_enabled = false
				mat.albedo_color = Color(0.2, 0.2, 0.2) 
			red_light.set_surface_override_material(0, mat)

extends Area3D

enum Size { SMALL, MEDIUM, LARGE }
@export var artifact_size: Size = Size.SMALL

var cash_value: int = 100
var weight_penalty: float = 1.0
var is_carried: bool = false
var carrier_id: int = -1

# For syncing transform across peers
var sync_target_position: Vector3 = Vector3.ZERO
var sync_target_rotation: Vector3 = Vector3.ZERO

func _ready():
	# Configure based on size
	match artifact_size:
		Size.SMALL:
			cash_value = 500
			weight_penalty = 0.9 # 10% slow
		Size.MEDIUM:
			cash_value = 1500
			weight_penalty = 0.7 # 30% slow
		Size.LARGE:
			cash_value = 5000
			weight_penalty = 0.4 # 60% slow

	sync_target_position = global_position
	sync_target_rotation = rotation

@rpc("any_peer", "call_local")
func request_pickup(player_id: int):
	if not multiplayer.is_server(): return
	if is_carried: return
	
	# Server validates and grants pickup
	rpc("confirm_pickup", player_id)

@rpc("any_peer", "call_local")
func confirm_pickup(player_id: int):
	is_carried = true
	carrier_id = player_id
	set_multiplayer_authority(player_id)
	
	var carrier = get_node_or_null("/root/World/main/SpawnedObjects/" + str(carrier_id))
	if carrier and carrier.has_method("on_artifact_pickup"):
		carrier.on_artifact_pickup(self)

func _process(delta):
	if is_carried:
		if is_multiplayer_authority():
			# I am carrying it, so I control it
			var carrier = get_node_or_null("/root/World/main/SpawnedObjects/" + str(carrier_id))
			if carrier:
				var cam = carrier.get_node_or_null("PitchPivot/SpringArm3D/Camera3D")
				if cam:
					# Position it at the chest of the Thief
					var chest_pos = carrier.global_position + Vector3(0, 1.0, 0)
					# Push it slightly forward relative to the Thief's body so it stays in their hands
					global_position = chest_pos + (-carrier.global_transform.basis.z * 0.8)
					# Keep the rotation anchored to the camera
					global_transform.basis = cam.global_transform.basis
			
			# Relay position to others
			rpc("relay_artifact_transform", global_position, rotation)
		else:
			# I am observing someone else carry it
			global_position = global_position.lerp(sync_target_position, 15.0 * delta)
			var current_quat = Quaternion(transform.basis)
			var target_quat = Quaternion(Basis.from_euler(sync_target_rotation))
			transform.basis = Basis(current_quat.slerp(target_quat, 15.0 * delta))

@rpc("any_peer", "unreliable", "call_local")
func relay_artifact_transform(pos: Vector3, rot: Vector3):
	if is_multiplayer_authority(): return
	sync_target_position = pos
	sync_target_rotation = rot

@rpc("any_peer", "call_local")
func drop():
	is_carried = false
	carrier_id = -1
	if multiplayer.is_server():
		set_multiplayer_authority(1)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(1)

@rpc("any_peer", "call_local")
func destroy_artifact():
	is_carried = false
	carrier_id = -1
	hide()
	$CollisionShape3D.set_deferred("disabled", true)

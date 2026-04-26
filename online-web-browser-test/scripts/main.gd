extends Control

@export var plunger_scene: PackedScene

@rpc("any_peer", "call_local")
func spawn_plunger(muzzle_pos: Vector3, shoot_dir: Vector3, shooter_id: int): # <-- Removed color and team args
	if not multiplayer.is_server():
		return
		
	# Security: Look up the REAL team data on the server!
	var real_shooter = $SpawnedObjects.get_node_or_null(str(shooter_id))
	if not real_shooter: return
	
	var p = plunger_scene.instantiate()
	p.team_color = real_shooter.plunger_color
	p.shooter_team_index = real_shooter.team_index
	p.shooter_id = shooter_id
	
	$SpawnedObjects.add_child(p, true) 
	p.global_position = muzzle_pos
	
	if abs(shoot_dir.dot(Vector3.UP)) < 0.999:
		p.look_at(muzzle_pos + shoot_dir, Vector3.UP)
	else:
		p.look_at(muzzle_pos + shoot_dir, Vector3.RIGHT)
		
	p.velocity = shoot_dir * p.speed

func _ready() -> void:
	if OS.get_name() == "Web":
		$VBoxContainer/Signaling.hide()


func _on_listen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		$Server.listen(int($VBoxContainer/Signaling/Port.value))
	else:
		$Server.stop()


func _on_LinkButton_pressed() -> void:
	OS.shell_open("https://github.com/godotengine/webrtc-native/releases")

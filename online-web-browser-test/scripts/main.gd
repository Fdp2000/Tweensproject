extends Control

@export var plunger_scene: PackedScene

@rpc("any_peer", "call_local")
func spawn_plunger(muzzle_pos: Vector3, shoot_dir: Vector3, team_color: Color, shooter_team_index: int, shooter_id: int):
	if not multiplayer.is_server():
		return
	var p = plunger_scene.instantiate()
	p.team_color = team_color
	p.shooter_team_index = shooter_team_index
	p.shooter_id = shooter_id
	
	# 1. Add it to the tree FIRST
	$SpawnedObjects.add_child(p, true) 
	
	# 2. Now you can set the global position without errors
	p.global_position = muzzle_pos
	
	# Point the plunger in the shoot direction. We use Vector3.RIGHT as a fallback up vector if shooting straight up/down
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

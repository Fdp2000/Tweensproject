extends Control

@export var plunger_scene: PackedScene

func _ready() -> void:
	if OS.get_name() == "Web":
		$VBoxContainer/Signaling.hide()
		
	var spawner = $MultiplayerSpawner
	if spawner:
		spawner.add_spawnable_scene("res://scenes/PlayerScenes/Cop.tscn")
		spawner.add_spawnable_scene("res://scenes/PlayerScenes/Thief.tscn")
		spawner.add_spawnable_scene("res://scenes/MiscScenes/Artifact.tscn")


func _on_listen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		$Server.listen(int($VBoxContainer/Signaling/Port.value))
	else:
		$Server.stop()


func _on_LinkButton_pressed() -> void:
	OS.shell_open("https://github.com/godotengine/webrtc-native/releases")

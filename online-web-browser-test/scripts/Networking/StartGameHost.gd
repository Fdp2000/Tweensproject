extends Label

@export var update_interval: float = 0.2

var timer := 0.0


func _ready() -> void:
	_update_visibility()


func _process(delta: float) -> void:
	timer -= delta

	if timer <= 0.0:
		timer = update_interval
		_update_visibility()


func _update_visibility() -> void:
	visible = multiplayer.has_multiplayer_peer() and multiplayer.is_server()

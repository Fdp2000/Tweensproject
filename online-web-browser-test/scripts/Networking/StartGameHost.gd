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
	var is_host = multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	visible = is_host
	
	var parent = get_parent()
	if parent and parent is Control:
		parent.visible = is_host

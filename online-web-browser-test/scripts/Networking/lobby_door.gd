extends Area3D

var artifact_category = 0 # To prevent errors from interact logic
var is_carried = false

func _ready():
	add_to_group("artifact")
	
@rpc("any_peer", "call_local")
func request_pickup(requester_id: int):
	if multiplayer.is_server():
		rpc_id(requester_id, "execute_leave")

@rpc("any_peer", "call_local")
func drop():
	pass

@rpc("authority", "call_local")
func execute_leave():
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui:
		if client_ui.client.rtc_mp:
			client_ui.client.rtc_mp.close()
		client_ui.client.stop()
		client_ui._disconnected()

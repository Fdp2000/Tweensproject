extends Control

@onready var client: Node = $Client
@onready var host: LineEdit = $VBoxContainer/Connect/Host
@onready var room: LineEdit = $VBoxContainer/Connect/RoomSecret
@onready var mesh: CheckBox = $VBoxContainer/Connect/Mesh

func _ready() -> void:
	client.lobby_joined.connect(_lobby_joined)
	client.lobby_sealed.connect(_lobby_sealed)
	client.connected.connect(_connected)
	client.disconnected.connect(_disconnected)

	multiplayer.connected_to_server.connect(_mp_server_connected)
	multiplayer.connection_failed.connect(_mp_server_disconnect)
	multiplayer.server_disconnected.connect(_mp_server_disconnect)
	multiplayer.peer_connected.connect(_mp_peer_connected)
	multiplayer.peer_disconnected.connect(_mp_peer_disconnected)
	host.text = "wss://online-web-browser-test.onrender.com"


@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	_log("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])


func _mp_server_connected() -> void:
	_log("[Multiplayer] Server connected (I am %d)" % client.rtc_mp.get_unique_id())


func _mp_server_disconnect() -> void:
	_log("[Multiplayer] Server disconnected (I am %d)" % client.rtc_mp.get_unique_id())


@export var player_scene: PackedScene

func _mp_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var pf = player_scene.instantiate()
		pf.name = str(id)
		get_node("/root/World/main/SpawnedObjects").call_deferred("add_child", pf)
		


func _mp_peer_disconnected(id: int) -> void:
	_log("[Multiplayer] Peer %d disconnected" % id)


func _connected(id: int, use_mesh: bool) -> void:
	_log("[Signaling] Server connected with ID: %d. Mesh: %s" % [id, use_mesh])
	
	# If I am the host (ID 1), I spawn my own character immediately
	if id == 1:
		_mp_peer_connected(1)


func _disconnected() -> void:
	_log("[Signaling] Server disconnected: %d - %s" % [client.code, client.reason])


func _lobby_joined(lobby_id: String) -> void:
	_log("[Signaling] Joined lobby %s" % lobby_id)
	
	# Hides the entire connection UI so you can see the 3D world
	get_parent().get_parent().hide() 
	# Also capture the mouse so you can start looking around immediately
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func _lobby_sealed() -> void:
	_log("[Signaling] Lobby has been sealed")


func _log(msg: String) -> void:
	print(msg)
	$VBoxContainer/TextEdit.text += str(msg) + "\n"


func _on_peers_pressed() -> void:
	_log(str(multiplayer.get_peers()))


func _on_ping_pressed() -> void:
	ping.rpc(randf())

func _on_seal_pressed() -> void:
	client.seal_lobby()


func _on_start_pressed() -> void:
	client.start(host.text, room.text, mesh.button_pressed)


func _on_stop_pressed() -> void:
	client.stop()

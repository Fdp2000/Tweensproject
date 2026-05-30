extends Control

@onready var client: Node = $Client

# Hidden old/debug UI from the WebRTC demo
@onready var debug_vbox: VBoxContainer = $VBoxContainer

@onready var main_menu_panel = $MainMenuCanvas/Root/MainMenuPanel
@onready var host_button = $MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/HostButton
@onready var tutorial_button = $MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/TutorialButton
@onready var quit_button = $MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/QuitButton


@onready var join_panel = $MainMenuCanvas/Root/JoinPanel
@onready var name_input = $MainMenuCanvas/Root/JoinPanel/VBoxContainer/NameInput
@onready var room_input = $MainMenuCanvas/Root/JoinPanel/VBoxContainer/JoinRow/RoomInput
@onready var join_button = $MainMenuCanvas/Root/JoinPanel/VBoxContainer/JoinRow/JoinButton
@onready var back_button = $MainMenuCanvas/Root/JoinPanel/VBoxContainer/BackButton
# Tutorial UI
@onready var tutorial_panel: Control = $MainMenuCanvas/TutorialPanel
@onready var tutorial_back_button: Button = $MainMenuCanvas/TutorialPanel/BackButton

# Lobby UI
@onready var lobby_canvas: CanvasLayer = $LobbyCanvas
@onready var room_label: Label = $LobbyCanvas/LobbyPanel/VBoxContainer/RoomLabel
@onready var player_list: VBoxContainer = $LobbyCanvas/LobbyPanel/VBoxContainer/PlayerList
@onready var start_button: Button = $LobbyCanvas/LobbyPanel/VBoxContainer/ButtonRow/StartButton
@onready var leave_button: Button = $LobbyCanvas/LobbyPanel/VBoxContainer/ButtonRow/LeaveButton

var local_player_name: String = ""
var current_room_code: String = ""
var current_hud: Node = null

const SIGNALING_URL := "wss://online-web-browser-test.onrender.com"


func _ready() -> void:
	if debug_vbox:
		debug_vbox.hide()

	client.lobby_joined.connect(_lobby_joined)
	client.lobby_sealed.connect(_lobby_sealed)
	client.connected.connect(_connected)
	client.disconnected.connect(_disconnected)

	multiplayer.connected_to_server.connect(_mp_server_connected)
	multiplayer.connection_failed.connect(_mp_server_disconnect)
	multiplayer.server_disconnected.connect(_mp_server_disconnect)
	multiplayer.peer_connected.connect(_mp_peer_connected)
	multiplayer.peer_disconnected.connect(_mp_peer_disconnected)

	GameManager.lobby_updated.connect(update_lobby_ui)
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(_on_game_ended)

	if GameManager.has_signal("player_joined"):
		GameManager.player_joined.connect(_on_player_joined)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)

	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	show_main_menu()


func show_main_menu() -> void:
	main_menu_canvas.show()
	main_menu_panel.show()
	tutorial_panel.hide()
	lobby_canvas.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_tutorial() -> void:
	main_menu_panel.hide()
	tutorial_panel.show()


func show_lobby() -> void:
	main_menu_canvas.hide()
	lobby_canvas.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		start_button.show()
	else:
		start_button.hide()

	update_lobby_ui()


func _on_host_pressed() -> void:
	local_player_name = name_input.text.strip_edges()
	current_room_code = ""

	if local_player_name == "":
		local_player_name = "Player"

	client.start(SIGNALING_URL, "", false)


func _on_join_pressed() -> void:
	local_player_name = name_input.text.strip_edges()
	var code := room_input.text.strip_edges().to_upper()

	if local_player_name == "":
		local_player_name = "Player"

	if code == "":
		print("No room code entered.")
		return

	current_room_code = code
	client.start(SIGNALING_URL, code, false)


func _on_tutorial_pressed() -> void:
	show_tutorial()


func _on_tutorial_back_pressed() -> void:
	main_menu_panel.show()
	tutorial_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_leave_pressed() -> void:
	if client.rtc_mp:
		client.rtc_mp.close()

	client.stop()
	GameManager.client_return_to_lobby()
	GameManager.players.clear()

	lobby_canvas.hide()
	main_menu_canvas.show()
	main_menu_panel.show()


func _on_start_pressed() -> void:
	if local_player_name == "":
		local_player_name = "Player"

	GameManager.sync_player_data(multiplayer.get_unique_id(), local_player_name)
	GameManager.host_start_game()


func update_lobby_ui() -> void:
	if not lobby_canvas.visible:
		return

	for child in player_list.get_children():
		child.queue_free()

	for id in GameManager.players:
		var data = GameManager.players[id]

		var lbl := Label.new()
		lbl.text = data["name"]
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 24)
		player_list.add_child(lbl)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		start_button.show()
		start_button.disabled = GameManager.players.size() < 2
	else:
		start_button.hide()

	if current_room_code != "":
		room_label.text = "Room Secret: " + current_room_code
	else:
		room_label.text = "Room: Server Hosted"


func _lobby_joined(lobby_id: String) -> void:
	print("[Signaling] Joined lobby ", lobby_id)

	current_room_code = lobby_id
	DisplayServer.clipboard_set(lobby_id)

	if not GameManager.players.is_empty():
		show_lobby()
	else:
		if not GameManager.lobby_updated.is_connected(show_lobby):
			GameManager.lobby_updated.connect(show_lobby, CONNECT_ONE_SHOT)


func _lobby_sealed() -> void:
	print("[Signaling] Lobby has been sealed")


func _connected(id: int, _use_mesh: bool) -> void:
	print("[Signaling] Connected with ID: ", id)

	if id == 1:
		GameManager.add_player(1, local_player_name)


func _disconnected() -> void:
	print("[Signaling] Disconnected")

	GameManager.client_return_to_lobby()
	GameManager.players.clear()

	show_main_menu()


func _mp_server_connected() -> void:
	var my_id = client.rtc_mp.get_unique_id()
	print("[Multiplayer] Server connected. I am ", my_id)

	if my_id != 1:
		GameManager.rpc_id(1, "sync_player_data", my_id, local_player_name)


func _mp_server_disconnect() -> void:
	print("[Multiplayer] Server disconnected")


func _mp_peer_connected(_id: int) -> void:
	pass


func _mp_peer_disconnected(id: int) -> void:
	print("[Multiplayer] Peer disconnected: ", id)
	GameManager.remove_player(id)


func _on_game_started() -> void:
	if multiplayer.is_server():
		var spawned = get_node("/root/World/main/SpawnedObjects")

		for i in 3:
			await get_tree().physics_frame

		var cop_spawns = get_tree().get_nodes_in_group("cop_spawn")
		var thief_spawns = get_tree().get_nodes_in_group("thief_spawn")

		cop_spawns.shuffle()
		thief_spawns.shuffle()

		for id in GameManager.players.keys():
			var role = GameManager.players[id]["role"]
			var pf = spawned.get_node_or_null(str(id))
			
			if pf:
				pf.name += "_deleted"
				pf.queue_free()

			var new_pf
			var spawn_trans = Transform3D(Basis(), Vector3(0, 3, 0))

			if role == GameManager.PlayerRole.COP:
				new_pf = load("res://scenes/PlayerScenes/Cop.tscn").instantiate()
				if cop_spawns.size() > 0:
					spawn_trans = cop_spawns.pop_back().global_transform.orthonormalized()
			else:
				new_pf = load("res://scenes/PlayerScenes/Thief.tscn").instantiate()
				if thief_spawns.size() > 0:
					spawn_trans = thief_spawns.pop_back().global_transform.orthonormalized()

			new_pf.name = str(id)
			new_pf.team_index = role
			new_pf.global_transform = spawn_trans

			spawned.add_child(new_pf, true)
			new_pf._set_spawn_transform.rpc(spawn_trans)

	main_menu_canvas.hide()
	lobby_canvas.hide()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if current_hud:
		current_hud.queue_free()

	current_hud = load("res://scenes/UIScenes/HUD.tscn").instantiate()
	add_child(current_hud)


func _on_game_ended() -> void:
	if current_hud:
		current_hud.queue_free()
		current_hud = null

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_lobby()


@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	print("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])

func get_unoccupied_spawn(group_name: String, fallback_pos: Vector3 = Vector3(0, 1000, 0)) -> Transform3D:
	var spawns = get_tree().get_nodes_in_group(group_name)
	if spawns.size() == 0: return Transform3D(Basis(), fallback_pos)
	
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if not spawned: return spawns.pick_random().global_transform.orthonormalized()
	
	var available_spawns = []
	for spawn_marker in spawns:
		var is_occupied = false
		for child in spawned.get_children():
			if child.global_position.distance_to(spawn_marker.global_position) < 1.0:
				is_occupied = true
				break
		if not is_occupied:
			available_spawns.append(spawn_marker)
			
	if available_spawns.size() > 0:
		return available_spawns.pick_random().global_transform.orthonormalized()
	else:
		return spawns.pick_random().global_transform.orthonormalized()

func _on_player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return

	var spawned = get_node_or_null("/root/World/main/SpawnedObjects")
	if not spawned:
		return

	await get_tree().process_frame

	var spawn_trans = get_unoccupied_spawn("lobby_spawn", Vector3(0, 1000, 0))

	var pf = load("res://scenes/PlayerScenes/Thief.tscn").instantiate()
	pf.name = str(id)
	pf.team_index = GameManager.PlayerRole.THIEF
	pf.global_transform = spawn_trans
	pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
	spawned.add_child(pf, true)
	var skin_index = GameManager.players[id].get("chameleon_skin", 0)
	if pf.has_method("apply_skin"):
		pf.rpc("apply_skin", skin_index)

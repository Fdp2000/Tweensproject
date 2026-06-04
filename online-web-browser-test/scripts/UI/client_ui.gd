extends Node

@onready var client: Node = $Client
@onready var menu_root: Node = get_tree().get_root().find_child("MainMenuUI", true, false)

@onready var main_menu_viewport: SubViewport = menu_root.get_node("MainMenuScreen3D/MainMenuViewport")
@onready var play_viewport: SubViewport = menu_root.get_node("PlayScreen3D/PlayViewport")
@onready var skins_viewport: SubViewport = menu_root.get_node("SkinsScreen3D/SkinsViewport")

@onready var main_menu_panel: Control = menu_root.get_node("MainMenuScreen3D/MainMenuViewport/Root/MainMenuPanel")
@onready var play_panel: Control = menu_root.get_node("PlayScreen3D/PlayViewport/Root/PlayPanel")
@onready var skins_panel: Control = menu_root.get_node("SkinsScreen3D/SkinsViewport/Root/SkinsPanel")

@onready var play_button: Button = menu_root.get_node("MainMenuScreen3D/MainMenuViewport/Root/MainMenuPanel/MarginContainer/VBoxContainer/PlayButton")
@onready var tutorial_button: Button = menu_root.get_node("MainMenuScreen3D/MainMenuViewport/Root/MainMenuPanel/MarginContainer/VBoxContainer/TutorialButton")
@onready var skins_button: Button = menu_root.get_node("MainMenuScreen3D/MainMenuViewport/Root/MainMenuPanel/MarginContainer/VBoxContainer/SkinsButton")

@onready var name_input: LineEdit = menu_root.get_node("PlayScreen3D/PlayViewport/Root/PlayPanel/MarginContainer/VBoxContainer/NameInput")
@onready var room_input: LineEdit = menu_root.get_node("PlayScreen3D/PlayViewport/Root/PlayPanel/MarginContainer/VBoxContainer/JoinRow/RoomInput")
@onready var join_button: Button = menu_root.get_node("PlayScreen3D/PlayViewport/Root/PlayPanel/MarginContainer/VBoxContainer/JoinRow/JoinButton")
@onready var host_button: Button = menu_root.get_node("PlayScreen3D/PlayViewport/Root/PlayPanel/MarginContainer/VBoxContainer/HostButton")
@onready var play_back_button: Button = menu_root.get_node("PlayScreen3D/PlayViewport/Root/PlayPanel/MarginContainer/VBoxContainer/BackButton")

@onready var skins_back_button: Button = menu_root.get_node("SkinsScreen3D/SkinsViewport/Root/SkinsPanel/BackButton")

@onready var tutorial_canvas: CanvasLayer = menu_root.get_node("Tutorial/TutorialCanvas")
@onready var tutorial_cop_canvas: CanvasLayer = menu_root.get_node("TutorialCop/TutorialCopCanvas")
@onready var tutorial_next_button: Button = menu_root.get_node("Tutorial/TutorialCanvas/Control/Panel/NextButton")
@onready var cop_back_button: Button = menu_root.get_node("TutorialCop/TutorialCopCanvas/Control/Panel/BackButton")
@onready var cop_next_button: Button = menu_root.get_node("TutorialCop/TutorialCopCanvas/Control/Panel/NextButton")

@export var chameleon_skin_materials: Array[Material]
@export var rhino_skin_materials: Array[Material]

@onready var chameleon_spawn: Node3D = menu_root.get_node_or_null(
	"SkinsScreen3D/SkinsViewport/Root/SkinsPanel/HBoxContainer/MarginContainer2/ChameleonSkinPanel/PreviewSpawn"
) as Node3D
@onready var rhino_spawn: Node3D = menu_root.get_node_or_null(
	"SkinsScreen3D/SkinsViewport/Root/SkinsPanel/HBoxContainer/MarginContainer/RhinoSkinPanel/PreviewSpawn"
) as Node3D

@onready var chameleon_prev: Button = menu_root.get_node("SkinsScreen3D/SkinsViewport/Root/SkinsPanel/HBoxContainer/MarginContainer2/ChameleonSkinPanel/PreviousButton")
@onready var chameleon_next: Button = menu_root.get_node("SkinsScreen3D/SkinsViewport/Root/SkinsPanel/HBoxContainer/MarginContainer2/ChameleonSkinPanel/NextButton")
@onready var rhino_prev: Button = menu_root.get_node("SkinsScreen3D/SkinsViewport/Root/SkinsPanel/HBoxContainer/MarginContainer/RhinoSkinPanel/PreviousButton")
@onready var rhino_next: Button = menu_root.get_node("SkinsScreen3D/SkinsViewport/Root/SkinsPanel/HBoxContainer/MarginContainer/RhinoSkinPanel/NextButton")


var menu_camera: Camera3D
var menu_camera_spot: Marker3D
var skins_camera_spot: Marker3D
var play_camera_spot: Marker3D

const COP_SCENE = preload("res://scenes/PlayerScenes/Cop.tscn")
const THIEF_SCENE = preload("res://scenes/PlayerScenes/Thief.tscn")
const HUD_SCENE = preload("res://scenes/UIScenes/HUD.tscn")

const SIGNALING_URL := "wss://online-web-browser-test.onrender.com"

var local_player_name: String = ""
var current_room_code: String = ""
var current_hud: Node = null
var lobby_ui: Node = null
var tutorial_intro_cancelled := false
var has_requested_lobby := false
var tutorial_intro_tweens: Array[Tween] = []
var camera_is_on_skins := false

var selected_chameleon_skin := 0
var selected_rhino_skin := 0
var chameleon_preview: Node3D
var rhino_preview: Node3D
var host_button_original_text := ""
var host_loading_tween: Tween
var is_host_loading := false
var join_button_original_text := ""
var join_feedback_tween: Tween
var is_join_loading := false
var is_joining_room := false
var is_hosting_room := false



func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# --- RENDER KEEPALIVE HEARTBEAT ---
	# Render shuts down free servers after 15 mins of no inbound HTTP traffic.
	# We ping it every 5 minutes (300 seconds) to keep it awake while the game is running!
	var keepalive_timer = Timer.new()
	keepalive_timer.wait_time = 300.0
	keepalive_timer.autostart = true
	add_child(keepalive_timer)
	
	var http_req = HTTPRequest.new()
	add_child(http_req)
	
	keepalive_timer.timeout.connect(func():
		var ping_url = SIGNALING_URL.replace("wss://", "https://").replace("ws://", "http://")
		http_req.request(ping_url)
	)

	menu_camera = get_tree().get_first_node_in_group("menu_camera") as Camera3D
	menu_camera_spot = menu_root.get_node_or_null("MenuCameraSpot") as Marker3D
	skins_camera_spot = menu_root.get_node_or_null("SkinsCameraSpot") as Marker3D
	play_camera_spot = menu_root.get_node_or_null("PlayCameraSpot") as Marker3D

	if menu_camera and menu_camera_spot:
		menu_camera.global_position = menu_camera_spot.global_position
		menu_camera.global_rotation = menu_camera_spot.global_rotation
	if menu_camera:
		menu_camera.make_current()
		print("Found camera: ", menu_camera.get_path())
	
	client.lobby_joined.connect(_lobby_joined)
	client.lobby_sealed.connect(_lobby_sealed)
	client.connected.connect(_connected)
	client.disconnected.connect(_disconnected)

	multiplayer.connected_to_server.connect(_mp_server_connected)
	multiplayer.connection_failed.connect(_mp_server_disconnect)
	multiplayer.server_disconnected.connect(_mp_server_disconnect)
	multiplayer.peer_connected.connect(_mp_peer_connected)
	multiplayer.peer_disconnected.connect(_mp_peer_disconnected)

	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(_on_game_ended)

	if GameManager.has_signal("player_joined"):
		GameManager.player_joined.connect(_on_player_joined)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)

	play_button.pressed.connect(_on_play_pressed)
	play_back_button.pressed.connect(_on_play_back_pressed)

	skins_button.pressed.connect(_on_skins_pressed)
	skins_back_button.pressed.connect(_on_skins_back_pressed)

	tutorial_next_button.pressed.connect(_on_tutorial_next_pressed)
	cop_back_button.pressed.connect(_on_cop_back_pressed)
	cop_next_button.pressed.connect(_on_cop_next_pressed)

	chameleon_prev.pressed.connect(_on_chameleon_prev)
	chameleon_next.pressed.connect(_on_chameleon_next)
	rhino_prev.pressed.connect(_on_rhino_prev)
	rhino_next.pressed.connect(_on_rhino_next)
	
	host_button_original_text = host_button.text
	join_button_original_text = join_button.text
	
	_update_chameleon_preview()
	_update_rhino_preview()


	show_main_menu()
	animate_glow(tutorial_next_button)
	animate_glow(cop_next_button)
	
	# Load or create settings to check if the user has seen the tutorial
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	var has_seen_tutorial = false
	if err == OK:
		has_seen_tutorial = config.get_value("tutorial", "has_seen", false)
		
	if not has_seen_tutorial:
		config.set_value("tutorial", "has_seen", true)
		config.save("user://settings.cfg")
		_play_tutorial_intro()


func show_main_menu() -> void:
	AudioManager.play_music("main_menu", 1.0, 0.0)
	reset_tutorial_button()

	main_menu_panel.show()
	play_panel.show()
	skins_panel.show()

	tutorial_canvas.hide()
	tutorial_cop_canvas.hide()

	if lobby_ui:
		lobby_ui.hide()

	move_camera_to(menu_camera_spot)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_pressed() -> void:
	print("PLAY BUTTON PRESSED")
	AudioManager.play_2d_sfx("ui_click")
	cancel_tutorial_intro()
	move_camera_to(play_camera_spot)


func _on_play_back_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	move_camera_to(menu_camera_spot)

func cancel_tutorial_intro() -> void:
	tutorial_intro_cancelled = true

	for tween in tutorial_intro_tweens:
		if tween and tween.is_valid():
			tween.kill()

	tutorial_intro_tweens.clear()
	reset_tutorial_button()

func _on_skins_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	cancel_tutorial_intro()
	set_skin_viewports_active(true)
	move_camera_to(skins_camera_spot)


func _on_skins_back_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	set_skin_viewports_active(false)
	move_camera_to(menu_camera_spot)

func _animate_skins_panel_in() -> void:
	await get_tree().create_timer(0.7).timeout

	var original_pos := skins_panel.position

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(skins_panel, "modulate:a", 1.0, 0.9)
	tween.tween_property(skins_panel, "position", original_pos - Vector2(80, 0), 0.9)

func _rotate_camera_to_skins() -> void:
	print("Skins button pressed, moving camera")

	if menu_camera == null:
		print("MenuCamera not found!")
		return

	if skins_camera_spot == null:
		print("SkinsCameraSpot not found!")
		return

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		menu_camera,
		"global_position",
		skins_camera_spot.global_position,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		menu_camera,
		"global_rotation",
		skins_camera_spot.global_rotation,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _rotate_camera_to_menu() -> void:
	if menu_camera == null:
		print("MenuCamera not found!")
		return

	if menu_camera_spot == null:
		print("MenuCameraSpot not found!")
		return

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		menu_camera,
		"global_position",
		menu_camera_spot.global_position,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		menu_camera,
		"global_rotation",
		menu_camera_spot.global_rotation,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func animate_glow(button: Button) -> void:
	button.pivot_offset = button.size / 2.0

	while is_inside_tree():
		var glow := create_tween()
		glow.set_parallel(true)

		glow.tween_property(button, "scale", Vector2(1.08, 1.08), 0.8)
		glow.tween_property(button, "modulate", Color(1.8, 1.35, 0.35, 1.0), 0.8)

		await glow.finished

		var normal := create_tween()
		normal.set_parallel(true)

		normal.tween_property(button, "scale", Vector2.ONE, 0.8)
		normal.tween_property(button, "modulate", Color.WHITE, 0.8)

		await normal.finished


func _play_tutorial_intro() -> void:
	await get_tree().create_timer(0.8).timeout
	if tutorial_intro_cancelled:
		return

	tutorial_button.pivot_offset = tutorial_button.size / 2.0
	tutorial_button.text = "Tutorial"

	for i in 3:
		if tutorial_intro_cancelled:
			return

		var flash := create_tween()
		tutorial_intro_tweens.append(flash)
		flash.set_parallel(true)
		flash.tween_property(tutorial_button, "scale", Vector2(1.12, 1.12), 0.45)
		flash.tween_property(tutorial_button, "modulate", Color(2.0, 1.35, 0.25, 1.0), 0.45)
		await flash.finished

		if tutorial_intro_cancelled:
			return

		var unflash := create_tween()
		tutorial_intro_tweens.append(unflash)
		unflash.set_parallel(true)
		unflash.tween_property(tutorial_button, "scale", Vector2.ONE, 0.45)
		unflash.tween_property(tutorial_button, "modulate", Color.WHITE, 0.45)
		await unflash.finished

	if tutorial_intro_cancelled:
		return

	await get_tree().create_timer(0.35).timeout
	if tutorial_intro_cancelled:
		return

	var grow := create_tween()
	tutorial_intro_tweens.append(grow)
	grow.set_parallel(true)
	grow.tween_property(tutorial_button, "scale", Vector2(24.0, 24.0), 1.6)
	grow.tween_property(tutorial_button, "modulate", Color(2.0, 1.5, 0.5, 0.0), 1.6)
	await grow.finished

	if tutorial_intro_cancelled:
		return

	tutorial_intro_tweens.clear()
	reset_tutorial_button()
	_on_tutorial_pressed()


func reset_tutorial_button() -> void:
	tutorial_button.scale = Vector2.ONE
	tutorial_button.modulate = Color.WHITE
	tutorial_button.text = "Tutorial"

func move_camera_to(target_spot: Node3D) -> void:
	if menu_camera == null:
		print("Menu camera missing.")
		return

	if target_spot == null:
		print("Camera target spot missing.")
		return

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		menu_camera,
		"global_position",
		target_spot.global_position,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		menu_camera,
		"global_rotation",
		target_spot.global_rotation,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func show_lobby() -> void:
	if not has_requested_lobby:
		return
	# Duck the volume slightly (-4 decibels) so players can chat in the lobby!
	AudioManager.play_music("main_menu", 1.0, -6.0)
	set_skin_viewports_active(false)
	tutorial_canvas.hide()
	tutorial_cop_canvas.hide()
	skins_panel.hide()

	if lobby_ui == null:
		lobby_ui = preload("res://scripts/UI/lobby_ui.gd").new()
		add_child(lobby_ui)

	lobby_ui.show_lobby()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_host_pressed() -> void:
	if is_host_loading:
		return

	AudioManager.play_2d_sfx("ui_click")
	cancel_tutorial_intro()
	save_selected_skins()

	has_requested_lobby = true
	is_hosting_room = true
	is_joining_room = false

	local_player_name = name_input.text.strip_edges()
	if local_player_name == "":
		local_player_name = "Player"

	current_room_code = ""

	show_host_loading()

	client.start(SIGNALING_URL, "", false)


func _on_join_pressed() -> void:
	if is_join_loading:
		return

	AudioManager.play_2d_sfx("ui_click")
	cancel_tutorial_intro()
	save_selected_skins()

	local_player_name = name_input.text.strip_edges()
	current_room_code = room_input.text.strip_edges().to_upper()

	if local_player_name == "":
		local_player_name = "Player"

	if current_room_code == "":
		show_join_wrong_code()
		return

	GameManager.full_teardown()
	
	has_requested_lobby = true
	is_joining_room = true
	is_hosting_room = false

	show_join_loading()

	client.start(SIGNALING_URL, current_room_code, false)
	_check_join_timeout()

func _on_tutorial_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	cancel_tutorial_intro()

	tutorial_canvas.show()
	tutorial_cop_canvas.hide()
	skins_panel.hide()


func _on_tutorial_next_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	tutorial_canvas.hide()
	tutorial_cop_canvas.show()


func _on_cop_back_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	tutorial_cop_canvas.hide()
	tutorial_canvas.show()


func _on_cop_next_pressed() -> void:
	AudioManager.play_2d_sfx("ui_click")
	show_main_menu()

func show_play_panel() -> void:
	main_menu_panel.hide()
	play_panel.show()
	skins_panel.hide()
	tutorial_canvas.hide()
	tutorial_cop_canvas.hide()

	if lobby_ui:
		lobby_ui.hide()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _check_join_timeout() -> void:
	await get_tree().create_timer(2.5).timeout

	if not is_joining_room:
		return

	if GameManager.players.size() < 2:
		print("Join timeout: no valid host found.")

		GameManager.full_teardown()

		has_requested_lobby = false
		is_joining_room = false
		is_hosting_room = false

		show_play_panel()
		show_join_wrong_code()


func _connected(id: int, _use_mesh: bool) -> void:
	print("[Signaling] Connected with ID: ", id)

	# If we tried to JOIN a room, but got ID 1,
	# that means we became the first player in that room.
	# For joining, that usually means the room code was wrong/empty.
	if is_joining_room and id == 1:
		print("Wrong room code: joined as host/first player instead of client.")

		GameManager.full_teardown()
		has_requested_lobby = false
		is_joining_room = false
		is_hosting_room = false

		show_join_wrong_code()

		# Stop the client connection so it does not continue into an empty room.
		if client:
			client.stop()

		return

	# Only real hosting should add player 1.
	if is_hosting_room and id == 1:
		GameManager.add_player(
			1,
			local_player_name,
			selected_chameleon_skin,
			selected_rhino_skin
		)


func _disconnected() -> void:
	hide_host_loading()

	if is_joining_room or is_join_loading:
		print("[Signaling] Disconnected / Wrong code")

		GameManager.full_teardown()

		has_requested_lobby = false
		is_joining_room = false
		is_hosting_room = false

		show_play_panel()
		show_join_wrong_code()
		return

	hide_join_feedback()

	print("[Signaling] Disconnected")

	GameManager.full_teardown()
	has_requested_lobby = false
	is_joining_room = false
	is_hosting_room = false

	if lobby_ui:
		lobby_ui.hide()

	show_main_menu()


func _lobby_joined(lobby_id: String) -> void:
	if not has_requested_lobby:
		return

	hide_host_loading()

	print("[Signaling] Joined lobby: ", lobby_id)

	current_room_code = lobby_id

	if is_hosting_room:
		hide_join_feedback()
		DisplayServer.clipboard_set(lobby_id)

		if not GameManager.players.is_empty():
			show_lobby()
		else:
			if not GameManager.lobby_updated.is_connected(show_lobby):
				GameManager.lobby_updated.connect(show_lobby, CONNECT_ONE_SHOT)

		return

	if is_joining_room:
		print("Joined signaling lobby, waiting for multiplayer host...")
		return

func _lobby_sealed() -> void:
	print("[Signaling] Lobby sealed")


func _mp_server_connected() -> void:
	var my_id = client.rtc_mp.get_unique_id()
	print("[Multiplayer] Connected. My ID: ", my_id)

	if my_id != 1:
		GameManager.rpc_id(
			1,
			"sync_player_data",
			my_id,
			local_player_name,
			selected_chameleon_skin,
			selected_rhino_skin
		)

	if is_joining_room:
		print("Connected to multiplayer. Waiting for real lobby data...")

		if not GameManager.lobby_updated.is_connected(_show_join_lobby_after_sync):
			GameManager.lobby_updated.connect(_show_join_lobby_after_sync, CONNECT_ONE_SHOT)


func _show_join_lobby_after_sync() -> void:
	if not is_joining_room:
		return

	print("Join sync received. Players: ", GameManager.players)

	# When JOINING, a valid lobby should already have at least:
	# 1 host + 1 joining player
	if GameManager.players.size() < 2:
		print("Wrong code: lobby has less than 2 players.")

		GameManager.full_teardown()
		has_requested_lobby = false
		is_joining_room = false
		is_hosting_room = false

		show_join_wrong_code()
		return

	hide_join_feedback()
	show_lobby()

func _mp_server_disconnect() -> void:
	hide_host_loading()

	if is_join_loading:
		show_join_wrong_code()
	else:
		hide_join_feedback()

	print("[Multiplayer] Server disconnected")


func _mp_peer_connected(_id: int) -> void:
	pass


func _mp_peer_disconnected(id: int) -> void:
	print("[Multiplayer] Peer disconnected: ", id)
	GameManager.remove_player(id)

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

	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if not spawned:
		return

	await get_tree().process_frame

	var spawn_trans = get_unoccupied_spawn("lobby_spawn", Vector3(0, 1000, 0))

	var pf = THIEF_SCENE.instantiate()
	pf.name = str(id)
	pf.team_index = GameManager.PlayerRole.THIEF
	pf.global_transform = spawn_trans
	pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
	spawned.add_child(pf, true)
	var skin_index = GameManager.players[id].get("chameleon_skin", 0)
	pf.rpc("apply_skin", skin_index)
	
	# Wait for the node to fully initialize in the tree before triggering the RPCs
	await get_tree().process_frame
	if is_instance_valid(pf):
		pf.rpc("_set_spawn_transform", spawn_trans, true, true)

func _on_game_started() -> void:
	if multiplayer.is_server():
		var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)

		if spawned:
			for i in 3:
				await get_tree().physics_frame

			var assigned_spawns = {}
			var roles_to_spawn = [] # Queue for new nodes to prevent MultiplayerSpawner name collisions!
			
			for id in GameManager.players.keys():
				var role = GameManager.players[id]["role"]
				var spawn_trans = Transform3D()

				if role == GameManager.PlayerRole.COP:
					spawn_trans = get_unoccupied_spawn("cop_spawn", Vector3(0, 3, 0))
				else:
					spawn_trans = get_unoccupied_spawn("thief_spawn", Vector3(0, 3, 0))

				assigned_spawns[id] = spawn_trans
				var pf = spawned.get_node_or_null(str(id))

				var target_scene_path = ""
				if role == GameManager.PlayerRole.COP:
					target_scene_path = COP_SCENE.resource_path
				else:
					target_scene_path = THIEF_SCENE.resource_path

				if pf and pf.scene_file_path == target_scene_path:
					# Smart Teleport: Re-use the existing node for performance
					pf.team_index = role
					pf.global_transform = spawn_trans
				else:
					# Role changed (e.g. Thief -> Cop). We MUST instantiate to get the correct scripts/abilities!
					if pf:
						spawned.remove_child(pf)
						pf.queue_free()

					# Queue this spawn for NEXT frame so the client has time to delete the old node!
					roles_to_spawn.append({"id": id, "role": role, "trans": spawn_trans})
						
			# FIX: Wait 1 frame so the clients process the despawn packet and fully delete the old nodes!
			# If we don't do this, the new node gets renamed to @Node@... on the client and breaks all RPCs!
			await get_tree().process_frame
			
			for data in roles_to_spawn:
				var new_pf
				if data["role"] == GameManager.PlayerRole.COP:
					new_pf = COP_SCENE.instantiate()
				else:
					new_pf = THIEF_SCENE.instantiate()
					
				new_pf.name = str(data["id"])
				new_pf.team_index = data["role"]
				new_pf.global_transform = data["trans"]
				spawned.add_child(new_pf, true)
				
			# Wait for Godot to fully process the NEW spawn queue
			# Since RPCs and MultiplayerSpawner use the same reliable network channel, 
			# they are guaranteed to arrive in order on the clients!
			await get_tree().process_frame
			
			for id in GameManager.players.keys():
				var pf = spawned.get_node_or_null(str(id))
				if pf:
					var role = GameManager.players[id]["role"]
					var spawn_trans = assigned_spawns.get(id, pf.global_transform)
					pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
					
					# Don't play smoke or sound when teleporting into the match! Do force camo!
					pf.rpc("_set_spawn_transform", spawn_trans, false, false, true)
					pf.rpc("sync_team", role)
					pf.rpc("_sync_name", pf.player_name)
					
					var skin_index = 0
					if role == GameManager.PlayerRole.COP:
						skin_index = GameManager.players[id].get("rhino_skin", 0)
					else:
						skin_index = GameManager.players[id].get("chameleon_skin", 0)
					pf.rpc("apply_skin", skin_index)

	tutorial_canvas.hide()
	tutorial_cop_canvas.hide()
	skins_panel.hide()

	if lobby_ui:
		lobby_ui.hide()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if current_hud:
		current_hud.queue_free()

	current_hud = HUD_SCENE.instantiate()
	add_child(current_hud)


func set_skin_viewports_active(active: bool) -> void:
	if chameleon_spawn:
		chameleon_spawn.visible = active

	if rhino_spawn:
		rhino_spawn.visible = active

func _unhandled_input(event: InputEvent) -> void:
	# Secret Developer Tool: Press 'T' to reset tutorial save.
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		var config = ConfigFile.new()
		config.set_value("tutorial", "has_seen", false)
		config.save("user://settings.cfg")
		print("DEV TOOL: Tutorial save reset! The tutorial intro will play on the next launch.")

var lobby_fade_canvas: CanvasLayer
var lobby_fade_rect: ColorRect

func play_lobby_fade_out():
	if not lobby_fade_canvas:
		lobby_fade_rect = ColorRect.new()
		lobby_fade_rect.color = Color.BLACK
		lobby_fade_rect.modulate.a = 0.0
		lobby_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lobby_fade_canvas = CanvasLayer.new()
		lobby_fade_canvas.layer = 128
		lobby_fade_canvas.add_child(lobby_fade_rect)
		add_child(lobby_fade_canvas)
		
	var fade_out = create_tween()
	fade_out.tween_property(lobby_fade_rect, "modulate:a", 1.0, 1.0)

func _on_game_ended() -> void:
	if current_hud:
		current_hud.queue_free()
		current_hud = null

	show_lobby()
	
	if lobby_fade_rect:
		var fade_in = create_tween()
		fade_in.tween_property(lobby_fade_rect, "modulate:a", 0.0, 0.5)
		await fade_in.finished
		lobby_fade_canvas.queue_free()
		lobby_fade_canvas = null
		lobby_fade_rect = null

func _update_chameleon_preview() -> void:
	if chameleon_skin_materials.is_empty():
		print("No chameleon materials assigned.")
		return

	if chameleon_spawn == null:
		print("ERROR: chameleon_spawn is null. Check the node path.")
		return

	var mesh := chameleon_spawn.find_child("Chameleon", true, false) as MeshInstance3D

	if mesh == null:
		print("ERROR: Could not find Chameleon mesh under PreviewSpawn.")
		return

	mesh.set_surface_override_material(
		0,
		chameleon_skin_materials[selected_chameleon_skin]
	)

func _update_rhino_preview() -> void:
	if rhino_skin_materials.is_empty():
		print("No rhino materials assigned.")
		return

	if rhino_spawn == null:
		print("ERROR: rhino_spawn is null. Check the node path.")
		return

	var body := rhino_spawn.find_child("Rhino_Body", true, false) as MeshInstance3D
	var head := rhino_spawn.find_child("Rhino_Head", true, false) as MeshInstance3D

	if body:
		body.set_surface_override_material(
			0,
			rhino_skin_materials[selected_rhino_skin]
		)
	else:
		print("ERROR: Could not find Rhino_Body under PreviewSpawn.")

	if head:
		head.set_surface_override_material(
			0,
			rhino_skin_materials[selected_rhino_skin]
		)
	else:
		print("ERROR: Could not find Rhino_Head under PreviewSpawn.")

func _on_chameleon_next() -> void:
	if chameleon_skin_materials.is_empty():
		return

	selected_chameleon_skin = wrapi(selected_chameleon_skin + 1, 0, chameleon_skin_materials.size())
	_update_chameleon_preview()


func _on_chameleon_prev() -> void:
	if chameleon_skin_materials.is_empty():
		return

	selected_chameleon_skin = wrapi(selected_chameleon_skin - 1, 0, chameleon_skin_materials.size())
	_update_chameleon_preview()


func _on_rhino_next() -> void:
	print("Rhino next pressed")

	if rhino_skin_materials.is_empty():
		print("Rhino materials empty")
		return

	selected_rhino_skin = wrapi(selected_rhino_skin + 1, 0, rhino_skin_materials.size())
	print("Rhino skin index: ", selected_rhino_skin)
	_update_rhino_preview()


func _on_rhino_prev() -> void:
	if rhino_skin_materials.is_empty():
		return

	selected_rhino_skin = wrapi(selected_rhino_skin - 1, 0, rhino_skin_materials.size())
	_update_rhino_preview()

func save_selected_skins() -> void:
	GameManager.selected_chameleon_skin = selected_chameleon_skin
	GameManager.selected_rhino_skin = selected_rhino_skin


func show_host_loading() -> void:
	is_host_loading = true

	host_button.text = "⏳ SERVER WAKING UP..."
	host_button.disabled = true
	join_button.disabled = true
	play_back_button.disabled = true

	host_button.pivot_offset = host_button.size / 2.0

	if host_loading_tween and host_loading_tween.is_valid():
		host_loading_tween.kill()

	host_loading_tween = create_tween()
	host_loading_tween.set_loops()
	host_loading_tween.set_parallel(true)

	host_loading_tween.tween_property(
		host_button,
		"scale",
		Vector2(1.04, 1.04),
		0.45
	)

	host_loading_tween.tween_property(
		host_button,
		"modulate",
		Color(1.4, 1.2, 0.55, 1.0),
		0.45
	)

	host_loading_tween.chain().tween_property(
		host_button,
		"scale",
		Vector2.ONE,
		0.45
	)

	host_loading_tween.tween_property(
		host_button,
		"modulate",
		Color.WHITE,
		0.45
	)


func hide_host_loading() -> void:
	is_host_loading = false

	if host_loading_tween and host_loading_tween.is_valid():
		host_loading_tween.kill()

	host_button.text = host_button_original_text
	host_button.scale = Vector2.ONE
	host_button.modulate = Color.WHITE

	host_button.disabled = false
	join_button.disabled = false
	play_back_button.disabled = false
	
	
func show_join_loading() -> void:
	is_join_loading = true

	join_button.text = "🔍 FINDING ROOM..."
	join_button.disabled = true
	host_button.disabled = true
	play_back_button.disabled = true

	join_button.pivot_offset = join_button.size / 2.0

	if join_feedback_tween and join_feedback_tween.is_valid():
		join_feedback_tween.kill()

	join_feedback_tween = create_tween()
	join_feedback_tween.set_loops()
	join_feedback_tween.set_parallel(true)

	join_feedback_tween.tween_property(
		join_button,
		"scale",
		Vector2(1.04, 1.04),
		0.45
	)

	join_feedback_tween.tween_property(
		join_button,
		"modulate",
		Color(0.6, 1.2, 1.8, 1.0),
		0.45
	)

	join_feedback_tween.chain().tween_property(
		join_button,
		"scale",
		Vector2.ONE,
		0.45
	)

	join_feedback_tween.tween_property(
		join_button,
		"modulate",
		Color.WHITE,
		0.45
	)


func show_join_wrong_code() -> void:
	is_join_loading = false

	if join_feedback_tween and join_feedback_tween.is_valid():
		join_feedback_tween.kill()

	join_button.disabled = true
	host_button.disabled = false
	play_back_button.disabled = false

	join_button.text = "❌ WRONG CODE!"
	join_button.scale = Vector2.ONE
	join_button.modulate = Color(1.6, 0.35, 0.35, 1.0)

	var shake := create_tween()
	shake.tween_property(join_button, "position:x", join_button.position.x + 10, 0.06)
	shake.tween_property(join_button, "position:x", join_button.position.x - 10, 0.06)
	shake.tween_property(join_button, "position:x", join_button.position.x + 6, 0.06)
	shake.tween_property(join_button, "position:x", join_button.position.x, 0.06)

	await get_tree().create_timer(1.2).timeout

	hide_join_feedback()


func hide_join_feedback() -> void:
	is_join_loading = false

	if join_feedback_tween and join_feedback_tween.is_valid():
		join_feedback_tween.kill()

	join_button.text = join_button_original_text
	join_button.scale = Vector2.ONE
	join_button.modulate = Color.WHITE

	join_button.disabled = false
	host_button.disabled = false
	play_back_button.disabled = false

@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	print("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])

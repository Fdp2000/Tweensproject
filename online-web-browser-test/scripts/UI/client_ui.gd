extends Node

@onready var client: Node = $Client
@onready var menu_root: Node = get_tree().get_root().find_child("MainMenuUI", true, false)

@onready var main_menu_canvas: CanvasLayer = menu_root.get_node("MainMenuCanvas")
@onready var main_menu_panel: Control = menu_root.get_node("MainMenuCanvas/Root/MainMenuPanel")
@onready var play_panel: Control = menu_root.get_node("MainMenuCanvas/Root/PlayPanel")
@onready var skins_panel: Control = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel")

@onready var play_button: Button = menu_root.get_node("MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/PlayButton")
@onready var tutorial_button: Button = menu_root.get_node("MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/TutorialButton")
@onready var skins_button: Button = menu_root.get_node("MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/SkinsButton")
@onready var quit_button: Button = menu_root.get_node("MainMenuCanvas/Root/MainMenuPanel/MarginContainer/VBoxContainer/QuitButton")

@onready var name_input: LineEdit = menu_root.get_node("MainMenuCanvas/Root/PlayPanel/MarginContainer/VBoxContainer/NameInput")
@onready var room_input: LineEdit = menu_root.get_node("MainMenuCanvas/Root/PlayPanel/MarginContainer/VBoxContainer/JoinRow/RoomInput")
@onready var join_button: Button = menu_root.get_node("MainMenuCanvas/Root/PlayPanel/MarginContainer/VBoxContainer/JoinRow/JoinButton")
@onready var host_button: Button = menu_root.get_node("MainMenuCanvas/Root/PlayPanel/MarginContainer/VBoxContainer/HostButton")
@onready var play_back_button: Button = menu_root.get_node("MainMenuCanvas/Root/PlayPanel/MarginContainer/VBoxContainer/BackButton")

@onready var skins_back_button: Button = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/BackButton")

@onready var tutorial_canvas: CanvasLayer = menu_root.get_node("Tutorial/TutorialCanvas")
@onready var tutorial_cop_canvas: CanvasLayer = menu_root.get_node("TutorialCop/TutorialCopCanvas")
@onready var tutorial_next_button: Button = menu_root.get_node("Tutorial/TutorialCanvas/Control/Panel/NextButton")
@onready var cop_back_button: Button = menu_root.get_node("TutorialCop/TutorialCopCanvas/Control/Panel/BackButton")
@onready var cop_next_button: Button = menu_root.get_node("TutorialCop/TutorialCopCanvas/Control/Panel/NextButton")

@export var chameleon_skin_materials: Array[Material]
@export var rhino_skin_materials: Array[Material]

@onready var chameleon_spawn: Node3D = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/ChameleonSkinPanel/SubViewportContainer/SubViewport/PreviewSpawn")
@onready var rhino_spawn: Node3D = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/RhinoSkinPanel/SubViewportContainer/SubViewport/PreviewSpawn")

@onready var chameleon_prev: Button = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/ChameleonSkinPanel/PreviousButton")
@onready var chameleon_next: Button = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/ChameleonSkinPanel/NextButton")
@onready var rhino_prev: Button = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/RhinoSkinPanel/PreviousButton")
@onready var rhino_next: Button = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/RhinoSkinPanel/NextButton")


var menu_camera: Camera3D

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
var menu_camera_start_rotation: Vector3
var camera_is_on_skins := false

var selected_chameleon_skin := 0
var selected_rhino_skin := 0
var chameleon_preview: Node3D
var rhino_preview: Node3D

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	menu_camera = get_tree().get_first_node_in_group("menu_camera") as Camera3D

	if menu_camera:
		menu_camera.make_current()
		menu_camera_start_rotation = menu_camera.rotation_degrees
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
	quit_button.pressed.connect(_on_quit_pressed)

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
	reset_tutorial_button()

	main_menu_canvas.show()
	main_menu_panel.show()
	play_panel.hide()
	skins_panel.hide()
	tutorial_canvas.hide()
	tutorial_cop_canvas.hide()

	if lobby_ui:
		lobby_ui.hide()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_pressed() -> void:
	cancel_tutorial_intro()

	main_menu_panel.hide()
	play_panel.show()


func _on_play_back_pressed() -> void:
	play_panel.hide()
	main_menu_panel.show()

func cancel_tutorial_intro() -> void:
	tutorial_intro_cancelled = true

	for tween in tutorial_intro_tweens:
		if tween and tween.is_valid():
			tween.kill()

	tutorial_intro_tweens.clear()
	reset_tutorial_button()

func _on_skins_pressed() -> void:
	cancel_tutorial_intro()
	set_skin_viewports_active(true)

	main_menu_panel.hide()
	play_panel.hide()

	skins_panel.modulate.a = 0.0
	skins_panel.position.x += 80
	skins_panel.show()

	_rotate_camera_to_skins()
	_animate_skins_panel_in()


func _on_skins_back_pressed() -> void:
	set_skin_viewports_active(false)
	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		skins_panel,
		"modulate:a",
		0.0,
		0.5
	)

	tween.tween_property(
		menu_camera,
		"rotation_degrees",
		menu_camera_start_rotation,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	skins_panel.hide()
	skins_panel.modulate.a = 1.0

	main_menu_panel.show()

func _animate_skins_panel_in() -> void:
	await get_tree().create_timer(0.35).timeout

	var original_pos := skins_panel.position

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(skins_panel, "modulate:a", 1.0, 0.9)
	tween.tween_property(skins_panel, "position", original_pos - Vector2(80, 0), 0.9)

func _rotate_camera_to_skins() -> void:
	print("Skins button pressed, rotating camera")

	if menu_camera == null:
		print("MenuCamera not found!")
		return

	var target_rotation := menu_camera_start_rotation
	target_rotation.y += 90.0

	var tween := create_tween()
	tween.tween_property(
		menu_camera,
		"rotation_degrees",
		target_rotation,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _rotate_camera_to_menu() -> void:
	if menu_camera == null:
		print("MenuCamera not found!")
		return

	var tween := create_tween()

	tween.tween_property(
		menu_camera,
		"rotation_degrees",
		menu_camera_start_rotation,
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


func show_lobby() -> void:
	if not has_requested_lobby:
		return

	main_menu_canvas.hide()
	tutorial_canvas.hide()
	tutorial_cop_canvas.hide()
	skins_panel.hide()

	if lobby_ui == null:
		lobby_ui = preload("res://scripts/UI/lobby_ui.gd").new()
		add_child(lobby_ui)

	lobby_ui.show_lobby()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_host_pressed() -> void:
	cancel_tutorial_intro()
	save_selected_skins()

	has_requested_lobby = true

	local_player_name = name_input.text.strip_edges()
	if local_player_name == "":
		local_player_name = "Player"

	current_room_code = ""
	client.start(SIGNALING_URL, "", false)


func _on_join_pressed() -> void:
	cancel_tutorial_intro()
	save_selected_skins()

	has_requested_lobby = true

	local_player_name = name_input.text.strip_edges()
	current_room_code = room_input.text.strip_edges().to_upper()

	if local_player_name == "":
		local_player_name = "Player"

	if current_room_code == "":
		print("No room code entered.")
		return	

	client.start(SIGNALING_URL, current_room_code, false)


func _on_tutorial_pressed() -> void:
	cancel_tutorial_intro()

	main_menu_canvas.hide()
	tutorial_canvas.show()
	tutorial_cop_canvas.hide()
	skins_panel.hide()


func _on_tutorial_next_pressed() -> void:
	tutorial_canvas.hide()
	tutorial_cop_canvas.show()


func _on_cop_back_pressed() -> void:
	tutorial_cop_canvas.hide()
	tutorial_canvas.show()


func _on_cop_next_pressed() -> void:
	show_main_menu()


func _on_quit_pressed() -> void:
	tutorial_intro_cancelled = true
	get_tree().quit()


func _connected(id: int, _use_mesh: bool) -> void:
	print("[Signaling] Connected with ID: ", id)

	if id == 1:
		GameManager.add_player(
			1,
			local_player_name,
			selected_chameleon_skin,
			selected_rhino_skin
		)


func _disconnected() -> void:
	print("[Signaling] Disconnected")

	GameManager.full_teardown()
	has_requested_lobby = false

	if lobby_ui:
		lobby_ui.hide()

	show_main_menu()


func _lobby_joined(lobby_id: String) -> void:
	if not has_requested_lobby:
		return

	print("[Signaling] Joined lobby: ", lobby_id)

	current_room_code = lobby_id
	DisplayServer.clipboard_set(lobby_id)

	if not GameManager.players.is_empty():
		show_lobby()
	else:
		if not GameManager.lobby_updated.is_connected(show_lobby):
			GameManager.lobby_updated.connect(show_lobby, CONNECT_ONE_SHOT)


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


func _mp_server_disconnect() -> void:
	print("[Multiplayer] Server disconnected")


func _mp_peer_connected(_id: int) -> void:
	pass


func _mp_peer_disconnected(id: int) -> void:
	print("[Multiplayer] Peer disconnected: ", id)
	GameManager.remove_player(id)


func _on_player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return

	var spawned = get_node_or_null("/root/World/main/SpawnedObjects")
	if not spawned:
		return

	await get_tree().process_frame

	var lobby_spawns = get_tree().get_nodes_in_group("lobby_spawn")
	var spawn_pos = Vector3(0, 1000, 0)

	if lobby_spawns.size() > 0:
		spawn_pos = lobby_spawns[randi() % lobby_spawns.size()].global_position

	var pf = THIEF_SCENE.instantiate()
	pf.name = str(id)
	pf.team_index = GameManager.PlayerRole.THIEF
	pf.position = spawn_pos
	pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
	spawned.add_child(pf, true)
	var skin_index = GameManager.players[id].get("chameleon_skin", 0)
	pf.rpc("apply_skin", skin_index)

func _on_game_started() -> void:
	if multiplayer.is_server():
		var spawned = get_node_or_null("/root/World/main/SpawnedObjects")

		if spawned:
			for i in 3:
				await get_tree().physics_frame

			var cop_spawns = get_tree().get_nodes_in_group("cop_spawn")
			var thief_spawns = get_tree().get_nodes_in_group("thief_spawn")

			cop_spawns.shuffle()
			thief_spawns.shuffle()

			for id in GameManager.players.keys():
				var role = GameManager.players[id]["role"]
				var spawn_pos = Vector3(0, 3, 0)

				if role == GameManager.PlayerRole.COP:
					if cop_spawns.size() > 0:
						spawn_pos = cop_spawns.pop_back().global_position
				else:
					if thief_spawns.size() > 0:
						spawn_pos = thief_spawns.pop_back().global_position

				var pf = spawned.get_node_or_null(str(id))

				if role == GameManager.PlayerRole.COP:
					if pf:
						pf.name = pf.name + "_deleted"
						spawned.remove_child(pf)
						pf.queue_free()

					pf = COP_SCENE.instantiate()
					pf.name = str(id)
					pf.team_index = role
					pf.position = spawn_pos
					pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
					spawned.add_child(pf, true)
					var skin_index = GameManager.players[id].get("rhino_skin", 0)
					pf.rpc("apply_skin", skin_index)
				else:
					if pf:
						pf.position = spawn_pos
						pf.team_index = role
						pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
						pf.rpc("_set_spawn_position", spawn_pos)
						pf.rpc("sync_team", role)
						pf.rpc("_sync_name", pf.player_name)
						var skin_index = GameManager.players[id].get("chameleon_skin", 0)
						pf.rpc("apply_skin", skin_index)
					else:
						pf = THIEF_SCENE.instantiate()
						pf.name = str(id)
						pf.team_index = role
						pf.position = spawn_pos
						pf.player_name = GameManager.players.get(id, {}).get("name", "Player " + str(id))
						spawned.add_child(pf, true)
						var skin_index = GameManager.players[id].get("chameleon_skin", 0)
						pf.rpc("apply_skin", skin_index)

	main_menu_canvas.hide()
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
	# Enable/Disable processing of viewports to save performance when not visible
	var chameleon_vp = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/ChameleonSkinPanel/SubViewportContainer/SubViewport")
	var rhino_vp = menu_root.get_node("MainMenuCanvas/Root/SkinsPanel/HBoxContainer/RhinoSkinPanel/SubViewportContainer/SubViewport")
	
	if chameleon_vp:
		chameleon_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if rhino_vp:
		rhino_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	# Secret Developer Tool: Press 'T' on the main menu to instantly wipe the tutorial save!
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if main_menu_canvas.visible:
			var config = ConfigFile.new()
			config.set_value("tutorial", "has_seen", false)
			config.save("user://settings.cfg")
			print("DEV TOOL: Tutorial save reset! The tutorial intro will play on the next launch.")

func _on_game_ended() -> void:
	if current_hud:
		current_hud.queue_free()
		current_hud = null

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_lobby()

func _update_chameleon_preview() -> void:
	if chameleon_skin_materials.is_empty():
		print("No chameleon materials assigned.")
		return

	var mesh := chameleon_spawn.find_child("Chameleon", true, false) as MeshInstance3D
	if mesh:
		mesh.set_surface_override_material(0, chameleon_skin_materials[selected_chameleon_skin])


func _update_rhino_preview() -> void:
	if rhino_skin_materials.is_empty():
		print("No rhino materials assigned.")
		return

	var body := rhino_spawn.find_child("Rhino_Body", true, false) as MeshInstance3D
	var head := rhino_spawn.find_child("Rhino_Head", true, false) as MeshInstance3D

	if body:
		body.set_surface_override_material(
			0,
			rhino_skin_materials[selected_rhino_skin]
		)

	if head:
		head.set_surface_override_material(
			0,
			rhino_skin_materials[selected_rhino_skin]
		)

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


@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	print("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])

extends Control

@onready var client: Node = $Client
@onready var host: LineEdit = $VBoxContainer/Connect/Host
@onready var room: LineEdit = $VBoxContainer/Connect/RoomSecret
@onready var mesh: CheckBox = $VBoxContainer/Connect/Mesh

var local_player_name: String = ""
var lobby_ui: Node
var current_hud: Node = null
var current_room_code: String = ""

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
	
	lobby_ui = preload("res://scripts/UI/lobby_ui.gd").new()
	add_child(lobby_ui)
	
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(_on_game_ended)
	
	# Hide the old debug menu and header from main.tscn

	# Hide the old debug menu and header from main.tscn
	$VBoxContainer.hide()
	var signaling_header = get_node_or_null("../../Signaling")
	if signaling_header: signaling_header.hide()
	
	# Web Clipboard Workaround for Pasting (Bypasses iframe security)
	if OS.has_feature("web"):
		var js = """
			window.godot_pasted_text = '';
			document.addEventListener('paste', function(e) {
				var text = (e.originalEvent || e).clipboardData.getData('text/plain');
				if (text) {
					window.godot_pasted_text = text;
				}
			});
		"""
		JavaScriptBridge.eval(js)
		
		# iOS Fullscreen Workaround: Inject CSS and viewport fixes
		var ios_css = """
			(function() {
				// Fix viewport for iOS
				var meta = document.querySelector('meta[name="viewport"]');
				if (!meta) {
					meta = document.createElement('meta');
					meta.name = 'viewport';
					meta.head.appendChild(meta);
				}
				meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
				
				// Add apple-mobile-web-app meta tags
				var awc = document.createElement('meta');
				awc.name = 'apple-mobile-web-app-capable';
				awc.content = 'yes';
				document.head.appendChild(awc);
				
				var aws = document.createElement('meta');
				aws.name = 'apple-mobile-web-app-status-bar-style';
				aws.content = 'black-translucent';
				document.head.appendChild(aws);
				
				// CSS to use full dynamic viewport height (iOS Safari)
				var style = document.createElement('style');
				style.textContent = `
					html, body {
						height: 100dvh !important;
						width: 100dvw !important;
						overflow: hidden !important;
						margin: 0 !important;
						padding: 0 !important;
						touch-action: none;
					}
					canvas#canvas {
						height: 100dvh !important;
						width: 100dvw !important;
					}
				`;
				document.head.appendChild(style);
				
				// Scroll to hide address bar
				setTimeout(function() { window.scrollTo(0, 1); }, 100);
			})();
		"""
		JavaScriptBridge.eval(ios_css)
	
	_build_main_menu()

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		var pasted = JavaScriptBridge.eval("window.godot_pasted_text")
		if typeof(pasted) == TYPE_STRING and pasted != "":
			JavaScriptBridge.eval("window.godot_pasted_text = ''")
			var join_input = get_node_or_null("MainMenuCanvas/MainMenu/VBoxContainer/HBoxContainer/LineEdit")
			if join_input:
				var code = pasted.strip_edges().to_upper()
				join_input.text = code
				client.start(host.text, code, true)

func _build_main_menu():
	var canvas = CanvasLayer.new()
	canvas.name = "MainMenuCanvas"
	add_child(canvas)
	
	var menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.name = "MainMenu"
	canvas.add_child(menu)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 20)
	menu.add_child(vbox)
	
	var title = Label.new()
	title.text = "    PLUNGER    "
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Enter Name"
	name_input.max_length = 16
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.add_theme_font_size_override("font_size", 24)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_mobile_device() and OS.has_feature("web"):
		# Use HTML prompt for iOS compatibility (bypasses WebKit keyboard restrictions)
		name_input.editable = false
		name_input.gui_input.connect(func(event):
			if event is InputEventScreenTouch and event.pressed:
				var result = JavaScriptBridge.eval("prompt('Enter your name:', '')")
				if result != null and str(result).strip_edges() != "":
					name_input.text = str(result).strip_edges().substr(0, 16)
		)
	else:
		name_input.focus_entered.connect(func(): if is_mobile_device(): DisplayServer.virtual_keyboard_show(""))
	vbox.add_child(name_input)
	
	var host_btn = Button.new()
	host_btn.text = "Host Game"
	host_btn.add_theme_font_size_override("font_size", 32)
	host_btn.pressed.connect(func():
		local_player_name = name_input.text.strip_edges()
		current_room_code = ""
		client.start(host.text, "", false)
	)
	vbox.add_child(host_btn)
	
	var join_hbox = HBoxContainer.new()
	vbox.add_child(join_hbox)
	
	var join_input = LineEdit.new()
	join_input.placeholder_text = "Paste Room Key Here"
	join_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_input.add_theme_font_size_override("font_size", 24)
	if is_mobile_device() and OS.has_feature("web"):
		# Use HTML prompt for iOS compatibility (bypasses WebKit keyboard restrictions)
		join_input.editable = false
		join_input.gui_input.connect(func(event):
			if event is InputEventScreenTouch and event.pressed:
				var result = JavaScriptBridge.eval("prompt('Enter Room Code:', '')")
				if result != null and str(result).strip_edges() != "":
					var code = str(result).strip_edges().to_upper()
					join_input.text = code
		)
	else:
		join_input.virtual_keyboard_enabled = true
	join_hbox.add_child(join_input)
	
	var join_btn = Button.new()
	join_btn.text = "Join Game"
	join_btn.add_theme_font_size_override("font_size", 24)
	join_btn.pressed.connect(func():
		local_player_name = name_input.text.strip_edges()
		var code = join_input.text.strip_edges().to_upper()
		if code != "":
			current_room_code = code
			client.start(host.text, code, false)
	)
	join_hbox.add_child(join_btn)
	
	# Mobile scaling adjust
	if is_mobile_device():
		vbox.scale = Vector2(1.4, 1.4)
		vbox.pivot_offset = vbox.size / 2.0
		# Scale the whole menu
		menu.scale = Vector2(1.2, 1.2)
		menu.pivot_offset = Vector2(DisplayServer.window_get_size()) / 2.0
	
	# Controls Info (Top Left)
	var controls_vbox = VBoxContainer.new()
	controls_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls_vbox.position = Vector2(20, 20)
	menu.add_child(controls_vbox)
	
	if is_mobile_device():
		controls_vbox.scale = Vector2(1.2, 1.2)
		controls_vbox.hide() 
	else:
		controls_vbox.show() 

	var controls_title = Label.new()
	controls_title.text = "Controls"
	controls_title.add_theme_font_size_override("font_size", 24)
	controls_vbox.add_child(controls_title)
	
	var controls_list = Label.new()
	controls_list.text = "WASD = Movement\nLeft Click = Shoot\nSpace = Jump\nShift = Dash\nAlt = Switch Camera Side\nTab = Scoreboard"
	controls_list.add_theme_font_size_override("font_size", 18)
	controls_list.modulate = Color(0.8, 0.8, 0.8) # Slightly grey
	controls_vbox.add_child(controls_list)


@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	_log("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])


func _mp_server_connected() -> void:
	var my_id = client.rtc_mp.get_unique_id()
	_log("[Multiplayer] Server connected (I am %d)" % my_id)
	if my_id != 1:
		# Send my name to the host
		GameManager.rpc_id(1, "sync_player_data", my_id, local_player_name)


func _mp_server_disconnect() -> void:
	_log("[Multiplayer] Server disconnected (I am %d)" % client.rtc_mp.get_unique_id())


@export var player_scene: PackedScene

func _mp_peer_connected(id: int) -> void:
	# Handled completely by the server syncing the full lobby state
	pass

func _on_game_started() -> void:
	if multiplayer.is_server():
		var spawned = get_node("/root/World/main/SpawnedObjects")
		
		# Wait for physics to register collision shapes from the level
		for i in 3:
			await get_tree().physics_frame
		
		var cop_spawns = get_tree().get_nodes_in_group("cop_spawn")
		var thief_spawns = get_tree().get_nodes_in_group("thief_spawn")
		
		print("[Spawn] Found ", cop_spawns.size(), " cop spawns, ", thief_spawns.size(), " thief spawns")
		
		# Shuffle so spawns are random each round
		cop_spawns.shuffle()
		thief_spawns.shuffle()
		
		for id in GameManager.players.keys():
			var role = GameManager.players[id]["role"]
			
			var pf
			var spawn_pos = Vector3(0, 3, 0)
			
			if role == GameManager.PlayerRole.COP:
				pf = load("res://scenes/PlayerScenes/Cop.tscn").instantiate()
				if cop_spawns.size() > 0:
					var sp = cop_spawns.pop_back()
					spawn_pos = sp.global_position
					print("[Spawn] Cop ", id, " -> ", spawn_pos)
			else:
				pf = load("res://scenes/PlayerScenes/Thief.tscn").instantiate()
				if thief_spawns.size() > 0:
					var sp = thief_spawns.pop_back()
					spawn_pos = sp.global_position
					print("[Spawn] Thief ", id, " -> ", spawn_pos)
				
			pf.name = str(id)
			pf.team_index = role
			
			# Set position on the server's copy before adding to the tree
			pf.position = spawn_pos
			spawned.add_child(pf, true)
			
			# RPC the spawn position to the owning client.
			# This is necessary because:
			# 1. MultiplayerSpawner doesn't transmit initial position
			# 2. relay_position is rejected by the authority player (line: if is_multiplayer_authority(): return)
			# So without this, every non-host client's local player starts at (0,0,0).
			pf._set_spawn_position.rpc(spawn_pos)
			
	# Capture mouse when game starts
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

func _mp_peer_disconnected(id: int) -> void:
	_log("[Multiplayer] Peer %d disconnected" % id)
	GameManager.remove_player(id)


func _connected(id: int, _use_mesh: bool) -> void:
	_log("[Signaling] Server connected with ID: %d. Enforced Client-Server Architecture (Mesh: %s)" % [id, client.mesh])
	
	# If I am the host (ID 1), add myself to the lobby
	if id == 1:
		GameManager.add_player(1, local_player_name)


func _disconnected() -> void:
	_log("[Signaling] Server disconnected: %d - %s" % [client.code, client.reason])
	
	# If the host leaves or server crashes, everyone cleans up and goes back to main menu
	GameManager.client_return_to_lobby()
	GameManager.players.clear()
	
	var main_menu = get_node_or_null("MainMenuCanvas")
	if main_menu:
		main_menu.show()
		
	if lobby_ui:
		lobby_ui.hide()

func _lobby_joined(lobby_id: String) -> void:
	_log("[Signaling] Joined lobby %s" % lobby_id)
	current_room_code = lobby_id
	
	# Automatically copy to clipboard!
	DisplayServer.clipboard_set(lobby_id)
	print("Room ID copied to clipboard: ", lobby_id)
	
	# Wait until we actually receive the player list before transitioning
	if not GameManager.players.is_empty():
		_transition_to_lobby()
	else:
		if not GameManager.lobby_updated.is_connected(_transition_to_lobby):
			GameManager.lobby_updated.connect(_transition_to_lobby, CONNECT_ONE_SHOT)

func _transition_to_lobby() -> void:
	# Hides the entire connection UI so you can see the 3D world
	var canvas = get_node_or_null("MainMenuCanvas")
	if canvas: canvas.hide()
	
	var parent_ui = get_parent().get_parent()
	if parent_ui and parent_ui.has_method("hide"):
		parent_ui.hide() 
	
	if lobby_ui:
		lobby_ui.show_lobby()



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


func is_mobile_device() -> bool:
	if OS.has_feature("mobile"): return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"): return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var ua = JavaScriptBridge.eval("navigator.userAgent")
		if ua:
			for m in ["Android", "iPhone", "iPad", "iPod", "Mobile"]:
				if m in ua: return true
	return false

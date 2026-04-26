extends Control

@onready var client: Node = $Client
@onready var host: LineEdit = $VBoxContainer/Connect/Host
@onready var room: LineEdit = $VBoxContainer/Connect/RoomSecret
@onready var mesh: CheckBox = $VBoxContainer/Connect/Mesh

var local_player_name: String = ""

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
	name_input.focus_entered.connect(func(): if is_mobile_device(): DisplayServer.virtual_keyboard_show(""))
	vbox.add_child(name_input)
	
	var host_btn = Button.new()
	host_btn.text = "Host Game"
	host_btn.add_theme_font_size_override("font_size", 32)
	host_btn.pressed.connect(func():
		local_player_name = name_input.text.strip_edges()
		client.start(host.text, "", false)
	)
	vbox.add_child(host_btn)
	
	var join_hbox = HBoxContainer.new()
	vbox.add_child(join_hbox)
	
	var join_input = LineEdit.new()
	join_input.placeholder_text = "Paste Room Key Here"
	join_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_input.add_theme_font_size_override("font_size", 24)
	join_input.virtual_keyboard_enabled = true
	# iOS Fix: Trigger keyboard on GUI input (touch) rather than focus_entered
	join_input.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed:
			if is_mobile_device():
				DisplayServer.virtual_keyboard_show(join_input.text, join_input.get_global_rect())
	)
	join_hbox.add_child(join_input)
	
	var join_btn = Button.new()
	join_btn.text = "Join Game"
	join_btn.add_theme_font_size_override("font_size", 24)
	join_btn.pressed.connect(func():
		local_player_name = name_input.text.strip_edges()
		var code = join_input.text.strip_edges().to_upper()
		if code != "":
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
	_log("[Multiplayer] Server connected (I am %d)" % client.rtc_mp.get_unique_id())


func _mp_server_disconnect() -> void:
	_log("[Multiplayer] Server disconnected (I am %d)" % client.rtc_mp.get_unique_id())


@export var player_scene: PackedScene

func _mp_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var pf = player_scene.instantiate()
		pf.name = str(id)
		
		# Set the team index. The MultiplayerSynchronizer will automatically send this to everyone!
		var spawned = get_node("/root/World/main/SpawnedObjects")
		pf.team_index = spawned.get_child_count() % 2 
		
		spawned.add_child(pf, true)


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
	
	# Automatically copy to clipboard!
	DisplayServer.clipboard_set(lobby_id)
	print("Room ID copied to clipboard: ", lobby_id)
	
	# Hides the entire connection UI so you can see the 3D world
	var canvas = get_node_or_null("MainMenuCanvas")
	if canvas: canvas.hide()
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


func is_mobile_device() -> bool:
	if OS.has_feature("mobile"): return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"): return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var ua = JavaScriptBridge.eval("navigator.userAgent")
		if ua:
			for m in ["Android", "iPhone", "iPad", "iPod", "Mobile"]:
				if m in ua: return true
	return false

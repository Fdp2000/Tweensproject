extends CanvasLayer

var bg: ColorRect
var player_list: VBoxContainer
var ready_button: Button
var start_button: Button
var leave_button: Button
var room_label: Label

func _ready():
	name = "LobbyUI"
	layer = 100 # Put above everything else
	
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(control)
	
	bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "Lobby - Waiting for Players"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	room_label = Label.new()
	room_label.add_theme_font_size_override("font_size", 24)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(room_label)
	
	player_list = VBoxContainer.new()
	player_list.custom_minimum_size = Vector2(400, 300)
	vbox.add_child(player_list)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.pressed.connect(_on_start_pressed)
	start_button.hide() # Only visible to host
	hbox.add_child(start_button)
	
	leave_button = Button.new()
	leave_button.text = "Leave Lobby"
	leave_button.add_theme_font_size_override("font_size", 32)
	leave_button.pressed.connect(_on_leave_pressed)
	hbox.add_child(leave_button)
	
	GameManager.lobby_updated.connect(update_ui)
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(show_lobby)
	
	# Wait one frame for unique ID to be ready if called early
	call_deferred("update_ui")
	
	# Hide initially until lobby is actually joined
	hide()

func show_lobby():
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Check if host
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		start_button.show()
	else:
		start_button.hide()
	update_ui()

	pass

func _on_leave_pressed():
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui:
		if client_ui.client.rtc_mp:
			client_ui.client.rtc_mp.close()
		client_ui.client.stop()
		client_ui._disconnected()

func _on_start_pressed():
	GameManager.host_start_game()

func update_ui():
	if not visible: return
	
	# Clear list
	for child in player_list.get_children():
		child.queue_free()
		
	for id in GameManager.players:
		var data = GameManager.players[id]
		var lbl = Label.new()
		lbl.text = data["name"]
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 24)
		player_list.add_child(lbl)
			
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		start_button.disabled = false
		
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui and client_ui.get("current_room_code") != null:
		if client_ui.current_room_code != "":
			room_label.text = "Room Secret: " + client_ui.current_room_code
		else:
			room_label.text = "Room: Server Hosted"

func _on_game_started():
	hide()
	# Let player.gd or client_ui.gd handle mouse capturing when gameplay starts

extends CanvasLayer

var player_list: VBoxContainer
var room_label: Label

func _ready():
	name = "LobbyUI"
	layer = 100 # Put above everything else
	
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Allow clicking through the empty space
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	control.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	vbox.add_child(panel)
	
	var inner_vbox = VBoxContainer.new()
	panel.add_child(inner_vbox)
	
	room_label = Label.new()
	room_label.add_theme_font_size_override("font_size", 16)
	room_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inner_vbox.add_child(room_label)
	
	var sep = HSeparator.new()
	inner_vbox.add_child(sep)
	
	player_list = VBoxContainer.new()
	inner_vbox.add_child(player_list)
	
	GameManager.lobby_updated.connect(update_ui)
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(show_lobby)
	
	call_deferred("update_ui")
	hide()

func show_lobby():
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)

	if client_ui and client_ui.get("local_player_name") != null:
		GameManager.sync_player_data(multiplayer.get_unique_id(), client_ui.local_player_name)

	GameManager.host_start_game()

func update_ui():
	if not visible: return
	
	for child in player_list.get_children():
		child.queue_free()
		
	for id in GameManager.players:
		var data = GameManager.players[id]
		var lbl = Label.new()
		lbl.text = data["name"]
		if data.get("role", GameManager.PlayerRole.THIEF) == GameManager.PlayerRole.COP:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		player_list.add_child(lbl)
		
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui and client_ui.get("current_room_code") != null:
		if client_ui.current_room_code != "":
			room_label.text = "Room: " + client_ui.current_room_code
		else:
			room_label.text = "Room: Server Hosted"

func _on_game_started():
	hide()

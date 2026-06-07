extends CanvasLayer

var player_list: VBoxContainer
var room_label: Label


func _ready() -> void:
	name = "LobbyUI"
	layer = 100

	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	control.add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
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
	margin.add_child(panel)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(inner_vbox)

	room_label = Label.new()
	room_label.add_theme_font_size_override("font_size", 16)
	room_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inner_vbox.add_child(room_label)

	var sep := HSeparator.new()
	inner_vbox.add_child(sep)

	player_list = VBoxContainer.new()
	player_list.custom_minimum_size = Vector2(220, 120)
	inner_vbox.add_child(player_list)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	inner_vbox.add_child(button_row)


	GameManager.lobby_updated.connect(update_ui)
	GameManager.game_started.connect(_on_game_started)

	call_deferred("update_ui")
	hide()


func show_lobby() -> void:
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)

	if client_ui:
		if client_ui.get("has_requested_lobby") != null and not client_ui.has_requested_lobby:
			hide()
			return

	if GameManager.players.is_empty():
		hide()
		return

	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	update_ui()


func update_ui() -> void:
	if not visible:
		return

	for child in player_list.get_children():
		child.queue_free()

	for id in GameManager.players:
		var data = GameManager.players[id]

		var lbl := Label.new()
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

func _on_game_started() -> void:
	hide()

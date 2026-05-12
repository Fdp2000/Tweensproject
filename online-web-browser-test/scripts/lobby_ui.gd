extends CanvasLayer

var bg: ColorRect
var player_list: VBoxContainer
var ready_button: Button
var start_button: Button

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
	
	player_list = VBoxContainer.new()
	player_list.custom_minimum_size = Vector2(400, 300)
	vbox.add_child(player_list)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	ready_button = Button.new()
	ready_button.text = "Not Ready"
	ready_button.add_theme_font_size_override("font_size", 32)
	ready_button.pressed.connect(_on_ready_pressed)
	hbox.add_child(ready_button)
	
	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.pressed.connect(_on_start_pressed)
	start_button.hide() # Only visible to host
	hbox.add_child(start_button)
	
	GameManager.lobby_updated.connect(update_ui)
	GameManager.game_started.connect(_on_game_started)
	
	# Wait one frame for unique ID to be ready if called early
	call_deferred("update_ui")
	
	# Hide initially until lobby is actually joined
	hide()

func show_lobby():
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Check if host
	if multiplayer.is_server():
		start_button.show()
	else:
		start_button.hide()
	update_ui()

func _on_ready_pressed():
	var my_id = multiplayer.get_unique_id()
	if GameManager.players.has(my_id):
		var current_ready = GameManager.players[my_id]["ready"]
		GameManager.rpc("sync_player_data", my_id, GameManager.players[my_id]["name"], not current_ready)

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
		lbl.text = data["name"] + (" (Ready)" if data["ready"] else " (Not Ready)")
		if data["ready"]:
			lbl.add_theme_color_override("font_color", Color.GREEN)
		else:
			lbl.add_theme_color_override("font_color", Color.RED)
		lbl.add_theme_font_size_override("font_size", 24)
		player_list.add_child(lbl)
		
	var my_id = multiplayer.get_unique_id()
	if GameManager.players.has(my_id):
		if GameManager.players[my_id]["ready"]:
			ready_button.text = "Ready"
			ready_button.modulate = Color.GREEN
		else:
			ready_button.text = "Not Ready"
			ready_button.modulate = Color.WHITE
			
	if multiplayer.is_server():
		start_button.disabled = not GameManager.all_players_ready()

func _on_game_started():
	hide()
	# Let player.gd or client_ui.gd handle mouse capturing when gameplay starts

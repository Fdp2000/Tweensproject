extends Control

@onready var cop_list = $HBoxContainer/CopSide/CopList
@onready var thief_list = $HBoxContainer/ThiefSide/ThiefList
@onready var winner_label = $WinnerLabel
@onready var countdown_label = $CountdownLabel

var countdown = 5.0
var is_fading = false

func _process(delta):
	countdown -= delta
	countdown_label.text = "Returning to lobby in " + str(ceil(countdown)) + "..."
	
	if countdown <= 1.0 and not is_fading:
		is_fading = true
		var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
		if client_ui and client_ui.has_method("play_lobby_fade_out"):
			client_ui.play_lobby_fade_out()
	
	if countdown <= 0.0 and multiplayer.is_server():
		set_process(false)
		GameManager.rpc("return_to_lobby")

func populate(winner_text: String, cops_data: Array, thieves_data: Array):
	is_fading = false
	winner_label.text = winner_text
	
	for child in cop_list.get_children():
		child.queue_free()
	for child in thief_list.get_children():
		child.queue_free()
		
	for data in cops_data:
		var lbl = Label.new()
		lbl.text = data["name"] + " - Captures: " + str(data["captures"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_font_size_override("font_size", 20)
		cop_list.add_child(lbl)
		
	for data in thieves_data:
		var lbl = Label.new()
		lbl.text = data["name"] + " - Cash: " + Balance.format_money(data["cash"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_font_size_override("font_size", 20)
		thief_list.add_child(lbl)

extends CanvasLayer

@onready var time_label = $MarginContainer/VBoxContainer/TimeLabel
@onready var cash_label = $MarginContainer/VBoxContainer/CashLabel
@onready var game_over_panel = $GameOverPanel
@onready var game_over_label = $GameOverPanel/VBoxContainer/GameOverLabel

func _ready():
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.cash_updated.connect(_on_cash_updated)
	GameManager.game_over.connect(_on_game_over)
	
	_on_cash_updated() # Initialize text
	game_over_panel.hide()

func _on_time_updated(time_left: int):
	var minutes = time_left / 60
	var seconds = time_left % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	
	if time_left <= 60:
		time_label.add_theme_color_override("font_color", Color.RED)

func _on_cash_updated():
	cash_label.text = "Stolen Cash: $%d / $%d" % [GameManager.team_cash, GameManager.cash_quota]

func _on_game_over(winner_team: int):
	game_over_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if winner_team == GameManager.PlayerRole.THIEF:
		game_over_label.text = "THIEVES ESCAPED!"
		game_over_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		game_over_label.text = "COPS SECURED THE MUSEUM!"
		game_over_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))

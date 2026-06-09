extends CanvasLayer

@onready var time_label = $MarginContainer/VBoxContainer/TimeLabel
@onready var cash_label = $MarginContainer/VBoxContainer/CashLabel
@onready var game_over_panel = $GameOverPanel
@onready var game_over_label = $GameOverPanel/VBoxContainer/GameOverLabel

func _ready():
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.cash_updated.connect(_on_cash_updated)
	GameManager.game_over.connect(_on_game_over)
	GameManager.pre_game_started.connect(_on_pre_game_started)
	GameManager.game_ended.connect(_on_game_ended)
	
	_on_cash_updated() # Initialize text
	_on_time_updated(GameManager.round_timer) # Initialize time instantly!
	
	reset_hud_state()

func reset_hud_state():
	$MarginContainer.modulate.a = 0.0 # Hide initially
	game_over_panel.hide()

func _on_pre_game_started(_assignments):
	reset_hud_state()

func _on_game_ended():
	reset_hud_state()

func fade_in(duration: float = 1.5):
	var tween = create_tween()
	tween.tween_property($MarginContainer, "modulate:a", 1.0, duration)

func _on_time_updated(time_left: int):
	if time_left < 0:
		time_label.text = "--:--"
		time_label.add_theme_color_override("font_color", Color.WHITE)
		return
		
	var minutes = time_left / 60
	var seconds = time_left % 60
	time_label.text = "%d:%02d" % [minutes, seconds]
	
	if time_left <= 60:
		time_label.add_theme_color_override("font_color", Color.RED)

func _on_cash_updated():
	cash_label.text = "%s / %s" % [Balance.format_money(GameManager.team_cash), Balance.format_money(GameManager.cash_quota)]

func _on_game_over(winner_team: int):
	game_over_panel.show()
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if winner_team == GameManager.PlayerRole.THIEF:
		game_over_label.text = "THIEVES ESCAPED!"
		game_over_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		game_over_label.text = "COPS SECURED THE MUSEUM!"
		game_over_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))

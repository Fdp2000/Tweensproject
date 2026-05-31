extends CanvasLayer
class_name CutsceneUI

@onready var background: ColorRect = $Root/Background
@onready var countdown_label: Label = $Root/CountdownLabel

@export var total_countdown_time: float = 3.0
@export var vs_font_size: int = 81
@export var vs_is_italic: bool = true

func _ready():
	layer = 128 # Ensure this renders ON TOP of LobbyUI (which is layer 100)
	
	$Root.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.size = get_viewport().get_visible_rect().size
	background.modulate.a = 0.0
	countdown_label.text = ""
	visible = false
	
	var vs_label = $Root.get_node_or_null("VSLabel")
	if vs_label:
		vs_label.hide()
		# Apply custom font size and italics
		if vs_label is RichTextLabel:
			vs_label.add_theme_font_size_override("normal_font_size", vs_font_size)
			vs_label.add_theme_font_size_override("italics_font_size", vs_font_size)
			
			var base_text = "[color=blue]V[/color][color=red]S[/color]"
			if vs_is_italic:
				vs_label.text = "[center][i]" + base_text + "[/i][/center]"
			else:
				vs_label.text = "[center]" + base_text + "[/center]"
				
		elif vs_label is Label:
			vs_label.add_theme_font_size_override("font_size", vs_font_size)

func _notification(what):
	if what == Control.NOTIFICATION_RESIZED:
		if has_node("Root"):
			$Root.size = get_viewport().get_visible_rect().size

func fade_to_black(duration: float = 1.0):
	visible = true
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 1.0):
	visible = true
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, duration)
	await tween.finished

func play_countdown():
	visible = true
	background.modulate.a = 0.0
	countdown_label.modulate.a = 1.0
	
	var countdown_tick_duration = total_countdown_time / 3.0
	
	countdown_label.pivot_offset = countdown_label.size / 2.0
	
	for i in range(3, 0, -1):
		countdown_label.text = str(i)
		AudioManager.play_2d_sfx("countdown_tick")
		
		# Continuous cinematic push-in
		countdown_label.scale = Vector2.ONE * 0.5
		countdown_label.modulate.a = 0.0
		
		var tween = create_tween()
		tween.set_parallel(true)
		# Fade in quickly
		tween.tween_property(countdown_label, "modulate:a", 1.0, countdown_tick_duration * 0.2)
		# Fade out near the end
		tween.tween_property(countdown_label, "modulate:a", 0.0, countdown_tick_duration * 0.3).set_delay(countdown_tick_duration * 0.7)
		# Scale continuously and linearly through the entire duration
		tween.tween_property(countdown_label, "scale", Vector2.ONE * 1.5, countdown_tick_duration).set_trans(Tween.TRANS_LINEAR)
		
		await get_tree().create_timer(countdown_tick_duration).timeout
		
	countdown_label.text = "GO!"
	AudioManager.play_2d_sfx("countdown_go")
	countdown_label.scale = Vector2.ZERO
	countdown_label.modulate.a = 1.0
	
	var tween_go = create_tween()
	# Burst outwards to a massive size using the bouncy elastic effect
	tween_go.tween_property(countdown_label, "scale", Vector2.ONE * 1.25, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Wait and hold it on screen
	tween_go.tween_interval(0.6)
	
	# Fade out smoothly
	tween_go.tween_property(countdown_label, "modulate:a", 0.0, 0.5)
	
	await tween_go.finished
	visible = false

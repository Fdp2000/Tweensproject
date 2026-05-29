extends CanvasLayer
class_name CutsceneUI

@onready var background: ColorRect = $Root/Background
@onready var countdown_label: Label = $Root/CountdownLabel

func _ready():
	$Root.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.size = get_viewport().get_visible_rect().size
	background.modulate.a = 0.0
	countdown_label.text = ""
	visible = false

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
	
	for i in range(3, 0, -1):
		countdown_label.text = str(i)
		
		# Pulse animation
		countdown_label.scale = Vector2.ONE * 1.5
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		await get_tree().create_timer(0.5).timeout
		
	countdown_label.text = "GO!"
	countdown_label.scale = Vector2.ONE * 2.0
	var tween_go = create_tween()
	tween_go.tween_property(countdown_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween_go.parallel().tween_property(countdown_label, "modulate:a", 0.0, 1.0)
	
	await tween_go.finished
	visible = false

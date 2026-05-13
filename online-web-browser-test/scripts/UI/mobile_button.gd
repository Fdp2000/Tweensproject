extends Control

@export var action_name: String = ""
@export var button_text: String = ""
@export var radius: float = 40.0
@export var base_color: Color = Color(0, 0, 0, 0.5)
@export var pressed_color: Color = Color(1, 1, 1, 0.7)
@export var text_color: Color = Color(1, 1, 1, 1)

var is_pressed = false
var touch_id = -1
var center = Vector2.ZERO

func _ready():
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	center = custom_minimum_size / 2.0

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			var local_pos = (event.position - global_position)
			if local_pos.distance_to(center) <= radius:
				touch_id = event.index
				is_pressed = true
				if action_name == "mobile_shoot" or action_name == "secondary_action":
					var player = owner if owner else get_parent()
					while player and not player is CharacterBody3D:
						player = player.get_parent()
					if player:
						if action_name == "mobile_shoot" and "is_mobile_shooting" in player:
							player.is_mobile_shooting = true
						elif action_name == "secondary_action" and player.has_method("toggle_camera"):
							player.toggle_camera()
				else:
					Input.action_press(action_name)
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			is_pressed = false
			if action_name != "mobile_shoot":
				Input.action_release(action_name)
			queue_redraw()
			get_viewport().set_input_as_handled()

func _draw():
	var color = pressed_color if is_pressed else base_color
	draw_circle(center, radius, color)
	
	# Draw text
	if button_text != "":
		var font = ThemeDB.fallback_font
		var font_size = int(radius * 0.5)
		var string_size = font.get_string_size(button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center + Vector2(-string_size.x / 2.0, string_size.y * 0.3) # Approximate vertical centering
		draw_string(font, text_pos, button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

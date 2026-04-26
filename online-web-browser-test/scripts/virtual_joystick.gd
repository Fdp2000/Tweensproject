extends Control

var stick_pos = Vector2.ZERO
var center = Vector2.ZERO
var radius = 60.0
var input_vector = Vector2.ZERO
var touch_id = -1

func _ready():
	custom_minimum_size = Vector2(160, 160)
	# Anchor to bottom left
	anchor_top = 1.0
	anchor_bottom = 1.0
	anchor_left = 0.0
	anchor_right = 0.0
	
	# Set position relative to its anchor
	offset_left = 40
	offset_right = 40 + 160
	offset_top = -200
	offset_bottom = -200 + 160
	
	center = custom_minimum_size / 2.0
	stick_pos = center

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			var local_pos = get_local_mouse_position()
			# Check if touch is within our invisible square boundary
			if Rect2(Vector2.ZERO, custom_minimum_size).has_point(local_pos):
				touch_id = event.index
				update_stick(local_pos)
				get_viewport().set_input_as_handled() # Prevent camera rotation
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			update_stick(center)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenDrag and event.index == touch_id:
		update_stick(get_local_mouse_position())
		get_viewport().set_input_as_handled() # Prevent camera rotation

func update_stick(pos):
	var offset = pos - center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	stick_pos = center + offset
	
	# Deadzone
	if offset.length() < 10.0:
		input_vector = Vector2.ZERO
	else:
		input_vector = offset / radius
		
	queue_redraw()

func _draw():
	# Draw base
	draw_circle(center, radius, Color(0, 0, 0, 0.5))
	# Draw stick
	draw_circle(stick_pos, radius * 0.4, Color(1, 1, 1, 0.8))

func get_value() -> Vector2:
	return input_vector

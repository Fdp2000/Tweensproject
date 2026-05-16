extends Node
class_name MobileInputManager

var player: CharacterBody3D
var look_touch_index: int = -1
var last_look_pos: Vector2 = Vector2.ZERO
var joystick: Node = null

func setup(parent_player: CharacterBody3D):
	player = parent_player
	if not player.is_mobile_device(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var canvas = player.get_node_or_null("PlayerCanvas")
	if not canvas: return
	
	var screen_size = DisplayServer.window_get_size()
	var ui_scale = clamp(min(screen_size.x, screen_size.y) / 720.0, 0.8, 2.0)
	
	var mobile_ui = Control.new()
	mobile_ui.name = "MobileUI"
	mobile_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(mobile_ui)
	
	var look_area = Control.new()
	look_area.name = "LookArea"
	look_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look_area.mouse_filter = Control.MOUSE_FILTER_STOP
	look_area.gui_input.connect(_on_look_area_input)
	mobile_ui.add_child(look_area)
	
	joystick = load("res://scripts/UI/virtual_joystick.gd").new()
	if joystick:
		joystick.name = "Joystick"
		var joy_size = 200 * ui_scale
		joystick.custom_minimum_size = Vector2(joy_size, joy_size)
		joystick.radius = 70 * ui_scale
		joystick.anchor_top = 1.0
		joystick.anchor_bottom = 1.0
		joystick.anchor_left = 0.0
		joystick.anchor_right = 0.0
		joystick.offset_left = 40 * ui_scale
		joystick.offset_right = (40 + 200) * ui_scale
		joystick.offset_top = - (220 * ui_scale)
		joystick.offset_bottom = - (20 * ui_scale)
		mobile_ui.add_child(joystick)
	
	# We still call this so cop.gd can add its Charge button!
	player._add_custom_mobile_ui(mobile_ui, ui_scale)

func _on_look_area_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if look_touch_index == -1:
				look_touch_index = event.index
				last_look_pos = event.position
		elif event.index == look_touch_index:
			look_touch_index = -1
	
	if event is InputEventScreenDrag and event.index == look_touch_index:
		var drag_relative = event.position - last_look_pos
		last_look_pos = event.position
		
		var actual_sens = player.mouse_sensitivity * 0.001
		
		if player.disable_body_rotation:
			player.pitch_pivot.rotate_y(-drag_relative.x * actual_sens)
		else:
			player.rotate_y(-drag_relative.x * actual_sens)
			
		player.pitch_pivot.rotate_x(-drag_relative.y * actual_sens)
		player.pitch_pivot.rotation.x = clamp(player.pitch_pivot.rotation.x, -1.0, 1.0)
		player.get_viewport().set_input_as_handled()

func get_joystick_vector() -> Vector2:
	if joystick and joystick.has_method("get_value"):
		return joystick.get_value()
	return Vector2.ZERO

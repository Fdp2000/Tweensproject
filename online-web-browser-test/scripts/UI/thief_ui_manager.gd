extends Node
class_name ThiefUIManager

var thief: Node3D
var canvas: CanvasLayer

# UI References
var rescue_ui: Control
var cam_crosshair: ColorRect
var cam_left_btn: Button
var cam_right_btn: Button

func setup(parent_thief: Node3D):
	thief = parent_thief
	await thief.get_tree().process_frame
	canvas = thief.get_node_or_null("PlayerCanvas")
	if not canvas: return

	_build_rescue_ui()
	_build_camera_ui()
	
	if thief.has_method("is_mobile_device") and thief.is_mobile_device():
		_build_mobile_ui()

func _build_rescue_ui():
	rescue_ui = Control.new()
	rescue_ui.set_script(load("res://scripts/UI/dash_ui.gd"))
	rescue_ui.set("ring_color", Color(0.2, 1.0, 0.4, 0.9))
	rescue_ui.set("ready_color", Color(1.0, 1.0, 1.0, 0.0))
	rescue_ui.custom_minimum_size = Vector2(40, 40)
	rescue_ui.set_anchors_preset(Control.PRESET_CENTER)
	rescue_ui.offset_left = 20
	rescue_ui.offset_right = 60
	rescue_ui.offset_top = -40
	rescue_ui.offset_bottom = 0
	rescue_ui.set("hide_when_empty", true)
	rescue_ui.name = "RescueUI"
	canvas.add_child(rescue_ui)

func _build_camera_ui():
	cam_crosshair = ColorRect.new()
	cam_crosshair.name = "CamCrosshair"
	cam_crosshair.color = Color(1.0, 1.0, 1.0, 0.7)
	cam_crosshair.custom_minimum_size = Vector2(4, 4)
	cam_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	cam_crosshair.offset_left = -2
	cam_crosshair.offset_right = 2
	cam_crosshair.offset_top = -2
	cam_crosshair.offset_bottom = 2
	cam_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_crosshair.hide()
	canvas.add_child(cam_crosshair)
	
	if thief.has_method("is_mobile_device") and thief.is_mobile_device():
		cam_left_btn = Button.new()
		cam_left_btn.name = "CamLeftBtn"
		cam_left_btn.text = "<"
		cam_left_btn.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		cam_left_btn.position = Vector2(20, -50)
		cam_left_btn.size = Vector2(100, 100)
		cam_left_btn.pressed.connect(func(): thief._cycle_camera(-1))
		cam_left_btn.hide()
		canvas.add_child(cam_left_btn)
		
		cam_right_btn = Button.new()
		cam_right_btn.name = "CamRightBtn"
		cam_right_btn.text = ">"
		cam_right_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		cam_right_btn.position = Vector2(-120, -50)
		cam_right_btn.size = Vector2(100, 100)
		cam_right_btn.pressed.connect(func(): thief._cycle_camera(1))
		cam_right_btn.hide()
		canvas.add_child(cam_right_btn)

func _build_mobile_ui():
	var screen_size = DisplayServer.window_get_size()
	var ui_scale = clamp(min(screen_size.x, screen_size.y) / 720.0, 0.8, 2.0)
	
	var interact_btn = Button.new()
	interact_btn.name = "InteractButton"
	interact_btn.text = "INTERACT"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.15)
	style.set_corner_radius_all(100)
	style.set_border_width_all(4)
	style.border_color = Color(1, 1, 1, 0.4)
	
	interact_btn.add_theme_stylebox_override("normal", style)
	interact_btn.add_theme_stylebox_override("hover", style)
	interact_btn.add_theme_stylebox_override("pressed", style)
	interact_btn.add_theme_font_size_override("font_size", 18 * ui_scale)
	
	var btn_size = 130 * ui_scale
	interact_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	interact_btn.anchor_left = 1.0
	interact_btn.anchor_top = 1.0
	interact_btn.anchor_right = 1.0
	interact_btn.anchor_bottom = 1.0
	interact_btn.offset_left = -btn_size - (40 * ui_scale)
	interact_btn.offset_top = -btn_size - (280 * ui_scale)
	
	# Handle inputs by talking directly to the thief!
	interact_btn.button_down.connect(func(): 
		thief.is_mobile_interact = true
		thief.handle_mobile_interact_press()
	)
	interact_btn.button_up.connect(func(): 
		thief.is_mobile_interact = false
	)
	canvas.add_child(interact_btn)

# --- PUBLIC FUNCTIONS FOR THIEF.GD TO CALL ---

func update_rescue_ring(progress: float, is_visible: bool):
	if rescue_ui:
		rescue_ui.set("progress", progress)
		rescue_ui.visible = is_visible

func toggle_camera_ui(is_active: bool):
	if cam_crosshair: cam_crosshair.visible = is_active
	if cam_left_btn: cam_left_btn.visible = is_active
	if cam_right_btn: cam_right_btn.visible = is_active
	
	var touch_ui = canvas.get_node_or_null("TouchUI")
	if touch_ui: touch_ui.visible = not is_active

extends Node
class_name ThiefUIManager

var thief: Node3D
var canvas: CanvasLayer

# UI References
var rescue_ui: Control
var drop_cooldown_ui: Control
var cam_crosshair: ColorRect
var cam_left_btn: Button
var cam_right_btn: Button

func setup(parent_thief: Node3D):
	thief = parent_thief
	
	# Wait until PlayerCanvas is created by player.gd (which also yields)
	while not thief.has_node("PlayerCanvas"):
		if not thief.is_inside_tree(): return
		await thief.get_tree().process_frame
		
	canvas = thief.get_node("PlayerCanvas")
	if not canvas: return

	_build_rescue_ui()
	_build_drop_cooldown_ui()
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

func _build_drop_cooldown_ui():
	drop_cooldown_ui = Control.new()
	drop_cooldown_ui.set_script(load("res://scripts/UI/dash_ui.gd"))
	drop_cooldown_ui.set("ring_color", Color(1.0, 0.4, 0.2, 0.9)) # Orange/Red Cooldown
	drop_cooldown_ui.set("ready_color", Color(1.0, 1.0, 1.0, 0.0))
	drop_cooldown_ui.custom_minimum_size = Vector2(40, 40)
	drop_cooldown_ui.set_anchors_preset(Control.PRESET_CENTER)
	drop_cooldown_ui.offset_left = -60
	drop_cooldown_ui.offset_right = -20
	drop_cooldown_ui.offset_top = -40
	drop_cooldown_ui.offset_bottom = 0
	drop_cooldown_ui.size = Vector2(40, 40)
	drop_cooldown_ui.set("hide_when_empty", true)
	drop_cooldown_ui.name = "DropCooldownUI"
	canvas.add_child(drop_cooldown_ui)

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
	var interact_btn = load("res://scripts/UI/mobile_button.gd").new()
	interact_btn.name = "InteractButton"
	interact_btn.button_text = "INTERACT"
	interact_btn.radius = 85.0
	interact_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_btn.offset_left = -260
	interact_btn.offset_top = -260
	interact_btn.offset_right = -90
	interact_btn.offset_bottom = -90
	
	var mobile_ui = canvas.get_node_or_null("MobileUI")
	if mobile_ui:
		mobile_ui.add_child(interact_btn)
	else:
		canvas.add_child(interact_btn)
		
	# Handle inputs by talking directly to the thief!
	interact_btn.button_down.connect(func(): 
		thief.is_mobile_interact = true
		thief.handle_mobile_interact_press()
	)
	interact_btn.button_up.connect(func(): 
		thief.is_mobile_interact = false
	)

# --- PUBLIC FUNCTIONS FOR THIEF.GD TO CALL ---

func update_rescue_ring(progress: float, is_visible: bool):
	if rescue_ui:
		rescue_ui.set("progress", progress)
		if rescue_ui.has_method("queue_redraw"): rescue_ui.queue_redraw()
		if is_visible:
			rescue_ui.show()
		else:
			rescue_ui.hide()

func update_drop_cooldown_ring(progress: float, is_visible: bool):
	if drop_cooldown_ui:
		drop_cooldown_ui.set("progress", progress)
		if drop_cooldown_ui.has_method("queue_redraw"): drop_cooldown_ui.queue_redraw()
		if is_visible:
			drop_cooldown_ui.show()
		else:
			drop_cooldown_ui.hide()

func toggle_camera_ui(is_visible: bool):
	if cam_crosshair:
		cam_crosshair.visible = is_visible
	if cam_left_btn:
		cam_left_btn.visible = is_visible
	if cam_right_btn:
		cam_right_btn.visible = is_visible

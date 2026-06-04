extends Node3D

@export var viewport: SubViewport

@export var top_left: Marker3D
@export var top_right: Marker3D
@export var bottom_left: Marker3D

var screen_has_keyboard_focus := false


func _input(event: InputEvent) -> void:
	if viewport == null:
		return

	# Keyboard input: send it to the viewport after the player has clicked this screen.
	if event is InputEventKey:
		if screen_has_keyboard_focus:
			var key_event := event.duplicate()
			viewport.push_input(key_event)
		return

	# Optional text input support. Useful for some keyboard layouts.
	if event is InputEventFromWindow and screen_has_keyboard_focus:
		viewport.push_input(event.duplicate())

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var viewport_pos = get_mouse_position_on_screen(mouse_pos)

	if viewport_pos == null:
		# If clicking outside this screen, release keyboard focus.
		if event is InputEventMouseButton and event.pressed:
			screen_has_keyboard_focus = false
		return

	if event is InputEventMouseMotion:
		var new_event := InputEventMouseMotion.new()
		new_event.position = viewport_pos
		new_event.global_position = viewport_pos
		new_event.relative = event.relative
		new_event.velocity = event.velocity
		new_event.button_mask = event.button_mask
		viewport.push_input(new_event)

	elif event is InputEventMouseButton:
		if event.pressed:
			screen_has_keyboard_focus = true
			print("Viewport click position: ", viewport_pos)

		var new_event := InputEventMouseButton.new()
		new_event.position = viewport_pos
		new_event.global_position = viewport_pos
		new_event.button_index = event.button_index
		new_event.pressed = event.pressed
		new_event.double_click = event.double_click
		new_event.button_mask = event.button_mask
		viewport.push_input(new_event)


func get_mouse_position_on_screen(mouse_pos: Vector2):
	if top_left == null or top_right == null or bottom_left == null:
		return null

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var tl := top_left.global_position
	var tr := top_right.global_position
	var bl := bottom_left.global_position
	var br := tr + (bl - tl)

	var hit = Geometry3D.ray_intersects_triangle(ray_origin, ray_dir, tl, tr, bl)

	if hit == null:
		hit = Geometry3D.ray_intersects_triangle(ray_origin, ray_dir, tr, br, bl)

	if hit == null:
		return null

	var width_vec := tr - tl
	var height_vec := bl - tl
	var hit_vec: Vector3 = hit - tl

	var u := hit_vec.dot(width_vec) / width_vec.length_squared()
	var v := hit_vec.dot(height_vec) / height_vec.length_squared()

	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return null

	return Vector2(
		u * viewport.size.x,
		v * viewport.size.y
	)

extends Node
class_name ThiefCameraManager

var thief: Node3D
var is_on_cameras: bool = false
var available_cameras: Array[Node] = []
var current_cam_index: int = 0
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0

var last_ping_msec: int = 0
const PING_COOLDOWN_MS: int = 1000

func setup(parent: Node3D):
	thief = parent

func handle_input(event: InputEvent) -> bool:
	if not is_on_cameras: return false
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var actual_sens = thief.mouse_sensitivity * 0.001
		cam_yaw -= event.relative.x * actual_sens
		cam_pitch -= event.relative.y * actual_sens
		cam_yaw = clamp(cam_yaw, -1.0, 1.0)
		cam_pitch = clamp(cam_pitch, -0.5, 0.5)
		update_camera_rotation()
		return true # Tell the main script we handled this!
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_A or event.physical_keycode == KEY_LEFT:
			cycle_camera(-1)
			return true
		elif event.physical_keycode == KEY_D or event.physical_keycode == KEY_RIGHT:
			cycle_camera(1)
			return true
			
	var is_cam_interact = (event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_cam_interact:
		fire_camera_ping()
		return true
		
	return false

func access_cameras():
	available_cameras = thief.get_tree().get_nodes_in_group("SecurityCameras")
	if available_cameras.size() == 0:
		print("No security cameras found!")
		return
		
	is_on_cameras = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if thief.get("ui_manager"):
		thief.ui_manager.toggle_camera_ui(true)
		
	current_cam_index = randi() % available_cameras.size()
	switch_to_camera(current_cam_index)

func switch_to_camera(index: int):
	if available_cameras.size() == 0: return
	
	var old_cam = available_cameras[current_cam_index]
	if old_cam.has_method("release_control"):
		old_cam.rpc("release_control", thief.multiplayer.get_unique_id())
	var old_cam3d = old_cam.get_node_or_null("CameraMount/Camera3D")
	if old_cam3d:
		old_cam3d.current = false
		
	current_cam_index = posmod(index, available_cameras.size())
	var new_cam = available_cameras[current_cam_index]
	if new_cam.has_method("request_control"):
		new_cam.rpc("request_control", thief.multiplayer.get_unique_id())
		
	var new_cam3d = new_cam.get_node_or_null("CameraMount/Camera3D")
	if new_cam3d:
		new_cam3d.current = true
		
	cam_yaw = 0.0
	cam_pitch = 0.0
	update_camera_rotation()

func cycle_camera(dir: int):
	if not is_on_cameras: return
	switch_to_camera(current_cam_index + dir)

func update_camera_rotation():
	if not is_on_cameras or available_cameras.size() == 0: return
	var cam_root = available_cameras[current_cam_index]
	
	var cam3d = cam_root.get_node_or_null("CameraMount/Camera3D")
	if cam3d:
		cam3d.rotation.y = cam_yaw
		cam3d.rotation.x = cam_pitch
		
	if cam_root.has_method("sync_rotation"):
		cam_root.rpc("sync_rotation", cam_yaw, cam_pitch, thief.multiplayer.get_unique_id())

func fire_camera_ping():
	if not is_on_cameras or available_cameras.size() == 0: return
	
	var current_time = Time.get_ticks_msec()
	if current_time - last_ping_msec < PING_COOLDOWN_MS: return
	last_ping_msec = current_time
	
	var cam_root = available_cameras[current_cam_index]
	var ray = cam_root.get_node_or_null("CameraMount/Camera3D/PingRay")
	if ray:
		ray.force_raycast_update()
		if ray.is_colliding():
			var collider = ray.get_collider()
			if collider and collider.has_method("get_pinged") and collider.get("team_index") == 1:
				collider.rpc("get_pinged")
			else:
				var hit_pos = ray.get_collision_point()
				thief.rpc("sync_world_ping", hit_pos)

func release_cameras():
	is_on_cameras = false
	if thief.get("ui_manager"):
		thief.ui_manager.toggle_camera_ui(false)
		
	if available_cameras.size() > 0:
		var old_cam = available_cameras[current_cam_index]
		if old_cam.has_method("release_control"):
			old_cam.rpc("release_control", thief.multiplayer.get_unique_id())
			
	if thief.get("camera"):
		thief.camera.current = true

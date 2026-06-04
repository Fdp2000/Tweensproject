extends Node
class_name ThiefCameraManager

var thief: Node3D
var is_on_cameras: bool = false
var available_cameras: Array[Node] = []
var current_cam_index: int = 0
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0

var saved_orientations: Dictionary = {}

var last_ping_msec: int = 0

func setup(parent: Node3D):
	thief = parent

func handle_input(event: InputEvent) -> bool:
	if not is_on_cameras: return false
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var actual_sens = thief.mouse_sensitivity * 0.001
		cam_yaw -= event.relative.x * actual_sens
		cam_pitch -= event.relative.y * actual_sens
		var current_cam = available_cameras[current_cam_index] if available_cameras.size() > 0 else null
		
		var min_y = current_cam.get("min_yaw") if current_cam and "min_yaw" in current_cam else -1.0
		var max_y = current_cam.get("max_yaw") if current_cam and "max_yaw" in current_cam else 1.0
		var min_p = current_cam.get("min_pitch") if current_cam and "min_pitch" in current_cam else -1.0
		var max_p = current_cam.get("max_pitch") if current_cam and "max_pitch" in current_cam else 1.0
		
		if min_y > max_y:
			var temp = min_y; min_y = max_y; max_y = temp
		if min_p > max_p:
			var temp = min_p; min_p = max_p; max_p = temp
			
		cam_yaw = clamp(cam_yaw, min_y, max_y)
		cam_pitch = clamp(cam_pitch, min_p, max_p)
		update_camera_rotation()
		
		if current_cam and current_cam.has_method("sync_rotation"):
			current_cam.rpc("sync_rotation", cam_yaw, cam_pitch, thief.multiplayer.get_unique_id())
			
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
	
	# Save the user's personal orientation for the camera they are leaving
	saved_orientations[old_cam.get_path()] = Vector2(cam_yaw, cam_pitch)
	
	if old_cam.has_method("release_control"):
		old_cam.rpc("release_control", thief.multiplayer.get_unique_id())
	var old_cam3d = old_cam.find_child("Camera3D", true, false)
	if old_cam3d:
		old_cam3d.current = false
		
	if old_cam.has_node("pivotPoint"):
		old_cam.get_node("pivotPoint").visible = true
		
	current_cam_index = posmod(index, available_cameras.size())
	var new_cam = available_cameras[current_cam_index]
	if new_cam.has_method("request_control"):
		new_cam.rpc("request_control", thief.multiplayer.get_unique_id())
		
	var new_cam3d = new_cam.find_child("Camera3D", true, false)
	if new_cam3d:
		new_cam3d.current = true
		
		if new_cam.has_node("pivotPoint"):
			new_cam.get_node("pivotPoint").visible = false
		
		# Clear the Thief's listener so we can hear through the Security Camera!
		var listener = thief.find_child("AudioListener3D", true, false)
		if listener:
			listener.clear_current()
			print("[Audio Debug] Thief's AudioListener3D disabled! Current Camera3D is now: ", new_cam3d.name, " at position ", new_cam3d.global_position)
		else:
			print("[Audio Debug] WARNING: Thief had no AudioListener3D to clear!")
			
		# Explicitly force an AudioListener3D onto the Security Camera to guarantee spatial audio works
		var cam_listener = new_cam3d.get_node_or_null("ActiveListener")
		if not cam_listener:
			cam_listener = AudioListener3D.new()
			cam_listener.name = "ActiveListener"
			new_cam3d.add_child(cam_listener)
		cam_listener.make_current()
		print("[Audio Debug] Attached and activated explicit AudioListener3D onto Security Camera!")
		
	# Load the user's personal orientation, or default to the camera's start rotation
	if saved_orientations.has(new_cam.get_path()):
		var saved = saved_orientations[new_cam.get_path()]
		cam_yaw = saved.x
		cam_pitch = saved.y
	else:
		cam_yaw = new_cam.get("start_yaw") if "start_yaw" in new_cam else 0.0
		cam_pitch = new_cam.get("start_pitch") if "start_pitch" in new_cam else 0.0
		
	update_camera_rotation()
	
	# Force an immediate sync when switching to a camera so the physical model starts lerping to our view if we are primary
	if new_cam.has_method("sync_rotation"):
		new_cam.rpc("sync_rotation", cam_yaw, cam_pitch, thief.multiplayer.get_unique_id())

func cycle_camera(dir: int):
	if not is_on_cameras: return
	switch_to_camera(current_cam_index + dir)

func update_camera_rotation():
	if not is_on_cameras or available_cameras.size() == 0: return
	var cam_root = available_cameras[current_cam_index]
	
	var cam3d = cam_root.find_child("Camera3D", true, false)
	if cam3d:
		cam3d.rotation.y = cam_yaw
		cam3d.rotation.x = cam_pitch

func fire_camera_ping():
	if not is_on_cameras or available_cameras.size() == 0: return
	
	var current_time = Time.get_ticks_msec()
	if current_time - last_ping_msec < Balance.cam_laser_ping_cooldown_ms: return
	last_ping_msec = current_time
	
	var cam_root = available_cameras[current_cam_index]
	var ray = cam_root.find_child("PingRay", true, false)
	if ray:
		# Ensure the raycast checks Layer 4 (value 8) where hypnotized thieves live!
		ray.collision_mask |= 8 
		ray.force_raycast_update()
		
		var origin = ray.global_position
		var hit_pos = ray.get_collision_point() if ray.is_colliding() else origin - ray.global_transform.basis.z * 100.0
		var collider = ray.get_collider() if ray.is_colliding() else null
		
		var target_player = null
		
		# 1. Direct Hit Check
		if collider and collider.has_method("get_pinged"):
			var is_cop = collider.get("team_index") == 1
			var is_hypnotized = collider.get("team_index") == 0 and collider.get("is_hypnotized")
			if is_cop or is_hypnotized:
				target_player = collider
				
		# 2. Generous Cylinder Check (Auto-Aim for near misses)
		if not target_player:
			var ray_dir = (hit_pos - origin).normalized()
			var ray_length = origin.distance_to(hit_pos)
			var best_dist = 2.5 # Extremely generous 2.5 meter snap radius
			
			var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
			if spawned:
				for child in spawned.get_children():
					if child.has_method("get_pinged"):
						var is_cop = child.get("team_index") == 1
						var is_hypnotized = child.get("team_index") == 0 and child.get("is_hypnotized")
						if is_cop or is_hypnotized:
							var player_center = child.global_position + Vector3(0, 1.0, 0) # Offset to center of mass
							var to_player = player_center - origin
							var depth = to_player.dot(ray_dir)
							
							# Check if player is between the camera and the wall hit point
							if depth > 0 and depth < ray_length:
								var closest_point_on_line = origin + ray_dir * depth
								var dist = closest_point_on_line.distance_to(player_center)
								
								if dist < best_dist:
									best_dist = dist
									target_player = child
									
		# 3. Execute the Ping
		if target_player:
			target_player.rpc("get_pinged")
		elif ray.is_colliding():
			thief.rpc("sync_world_ping", hit_pos)

func release_cameras():
	is_on_cameras = false
	if thief.get("ui_manager"):
		thief.ui_manager.toggle_camera_ui(false)
		
	if available_cameras.size() > 0:
		var old_cam = available_cameras[current_cam_index]
		if old_cam.has_node("pivotPoint"):
			old_cam.get_node("pivotPoint").visible = true
			
		if old_cam.has_method("release_control"):
			old_cam.rpc("release_control", thief.multiplayer.get_unique_id())
			
	if thief.get("camera"):
		thief.camera.current = true
		
		# Return the listener to the Thief's body!
		var listener = thief.find_child("AudioListener3D", true, false)
		if listener:
			listener.make_current()
			print("[Audio Debug] Audio returned to Thief! Thief's AudioListener3D is now active at position: ", listener.global_position)
		else:
			print("[Audio Debug] WARNING: Could not find Thief's AudioListener3D to reactivate!")

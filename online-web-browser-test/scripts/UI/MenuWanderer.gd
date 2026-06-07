extends CharacterBody3D

var target_points: Array[Vector3] = []
var current_target_index: int = 0
var speed: float = 4.5
var is_thief: bool = false
var nav_agent: NavigationAgent3D

var stuck_timer: float = 0.0
var last_pos: Vector3 = Vector3.ZERO

func _ready():
	is_thief = name.contains("Thief")
	floor_max_angle = deg_to_rad(85.0) # Allow climbing very steep slopes so they don't get stuck in the valley!
	
	# Dynamically add NavigationAgent3D
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	add_child(nav_agent)
	
	# Dynamically add CollisionShape3D for gravity and wall sliding!
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	
	await get_tree().process_frame
	
	if target_points.size() > 0:
		nav_agent.target_position = target_points[0]
		
	var anim_player = find_child("AnimationPlayer", true, false)
	var c_mesh = find_child("Chameleon", true, false)
	var r_head = find_child("Rhino_Head", true, false)
	var r_body = find_child("Rhino_Body", true, false)
	
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui:
		if is_thief and c_mesh:
			var skins = client_ui.get("chameleon_skin_materials")
			if skins and skins.size() > 0:
				var random_mat = skins.pick_random()
				c_mesh.material_override = random_mat
		elif not is_thief and r_head and r_body:
			var skins = client_ui.get("rhino_skin_materials")
			if skins and skins.size() > 0:
				var random_mat = skins.pick_random()
				r_head.material_override = random_mat
				r_body.material_override = random_mat

	# Hide NameTag
	var nametag = find_child("NameTag", true, false)
	if nametag:
		nametag.hide()

	if anim_player:
		if is_thief:
			var run_anims = ["Run1", "Run3", "Run4", "Run5"]
			anim_player.play(run_anims.pick_random())
			anim_player.speed_scale = 1.3
			speed = Balance.base_thief_speed
		else:
			anim_player.play("Run_Forward")
			anim_player.speed_scale = 1.2
			speed = Balance.cop_base_speed

func play_footstep_sound():
	pass

func _physics_process(delta):
	# Instantly delete if we are no longer in the lobby (prevent showing up during gameplay)
	if GameManager.current_state != GameManager.GameState.LOBBY:
		queue_free()
		return
		
	# Use physical distance instead of nav_agent.is_navigation_finished() because
	# NavigationAgent3D can sometimes report true on the very first frame before pathing starts!
	var dist_sq = global_position.distance_squared_to(nav_agent.target_position)
	if dist_sq < 4.0: # 2 meters squared
		current_target_index += 1
		if current_target_index < target_points.size():
			nav_agent.target_position = target_points[current_target_index]
		else:
			queue_free()
			return
		
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_pos)
	dir.y = 0
	dir = dir.normalized()
	
	if dir.length_squared() > 0.01:
		# Add PI to target angle because models face -Z natively
		var target_angle = atan2(dir.x, dir.z) + PI
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
		
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		

	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
	move_and_slide()
	
	# Stuck check (prevent hanging the spawner forever)
	if global_position.distance_squared_to(last_pos) < 0.001:
		stuck_timer += delta
		if stuck_timer > 2.0:
			queue_free()
			return
	else:
		stuck_timer = 0.0
	last_pos = global_position

extends Area3D

var velocity = Vector3.ZERO
var plunger_gravity = 7
var speed = 50

@export var team_color: Color = Color("ff1d1d") # Default red
var shooter_team_index: int = -1
var shooter_id: int = -1

func _ready():
	# Apply team color to the plunger head
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color
	$MeshInstance3D2.set_surface_override_material(0, mat)
	
	if multiplayer.is_server():
		await get_tree().create_timer(3.0).timeout
		if is_inside_tree():
			queue_free()

func _physics_process(delta):
	if not multiplayer.is_server():
		return
		
	velocity.y -= plunger_gravity * delta
	
	# CCD Raycast logic
	var space_state = get_world_3d().direct_space_state
	var next_pos = global_position + velocity * delta
	var query = PhysicsRayQueryParameters3D.create(global_position, next_pos)
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	
	if result:
		global_position = result.position
		
		if multiplayer.is_server():
			var body = result.collider
			if body.has_method("take_damage") or body.is_in_group("players") or "Player" in body.name:
				# Friendly fire check: skip damage if same team
				if body.get("team_index") != null and body.team_index == shooter_team_index:
					queue_free()
					return
				
				print("SERVER: Plunger hit player! Sending damage RPC...")
				if body.has_method("take_damage"):
					body.rpc("take_damage", result.position, result.normal, team_color, shooter_id)
				else:
					body.call("take_damage", result.position, result.normal, team_color, shooter_id)
				
			queue_free()
	else:
		global_position = next_pos
	
	if velocity.length() > 0.1:
		var dir = velocity.normalized()
		if abs(dir.dot(Vector3.UP)) < 0.999:
			look_at(global_position + velocity, Vector3.UP)
		else:
			look_at(global_position + velocity, Vector3.RIGHT)

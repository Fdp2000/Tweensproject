extends Node
class_name ThiefPingManager

var thief: CharacterBody3D
var ping_visual: Node3D = null
var ping_timer: SceneTreeTimer = null

func setup(parent: CharacterBody3D):
	thief = parent
	_ready_ping_visual()

func _ready_ping_visual():
	var ping_scene = load("res://scenes/MiscScenes/thief_ping.tscn")
	if ping_scene:
		ping_visual = ping_scene.instantiate()
		thief.add_child(ping_visual)
		
		# --- THE MAGIC SETTING ---
		# This detaches the visual from the Thief's physical movement!
		ping_visual.top_level = true 
		ping_visual.visible = false

func trigger_ping(pos: Vector3):
	if not ping_visual: return
	
	# Move the ping to the target location (slightly lifted so it doesn't clip the floor)
	ping_visual.global_position = pos + Vector3(0, 0.5, 0)
	ping_visual.visible = true
	
	# Safe disconnect: If they pinged again early, kill the old timer!
	if ping_timer and ping_timer.timeout.is_connected(_hide_ping):
		ping_timer.timeout.disconnect(_hide_ping)
		
	# --- USE BALANCE MAP PING DURATION ---
	ping_timer = thief.get_tree().create_timer(Balance.thief_map_ping_duration)
	ping_timer.timeout.connect(_hide_ping)

func _hide_ping():
	if ping_visual:
		ping_visual.visible = false

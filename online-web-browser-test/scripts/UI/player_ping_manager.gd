extends Node
class_name PlayerPingManager

var player: CharacterBody3D
var ping_timer: SceneTreeTimer = null
var cop_ping_visual: Node3D = null

func setup(parent_player: CharacterBody3D):
	player = parent_player

func trigger_ping():
	if not cop_ping_visual:
		_ready_ping_visual()
		
	if cop_ping_visual:
		cop_ping_visual.visible = true
		
		# --- FIX: SAFE DISCONNECT ---
		if ping_timer and ping_timer.timeout.is_connected(_hide_ping):
			ping_timer.timeout.disconnect(_hide_ping)
		# ----------------------------
			
		ping_timer = player.get_tree().create_timer(5.0)
		ping_timer.timeout.connect(_hide_ping)

func _ready_ping_visual():
	var ping_scene = load("res://scenes/MiscScenes/cop_ping.tscn")
	if ping_scene:
		cop_ping_visual = ping_scene.instantiate()
		player.add_child(cop_ping_visual)
		cop_ping_visual.position = Vector3(0, 2.5, 0)
		cop_ping_visual.visible = false

func _hide_ping():
	if cop_ping_visual:
		cop_ping_visual.visible = false

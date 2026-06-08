extends Node
class_name ThiefPingManager

var thief: CharacterBody3D
var ping_visual: Node3D = null
var ping_timer: SceneTreeTimer = null

func setup(parent: CharacterBody3D):
	thief = parent
	_ready_ping_visual()

const PING_SCENE = preload("res://scenes/MiscScenes/thief_ping.tscn")

func _ready_ping_visual():
	if PING_SCENE:
		ping_visual = PING_SCENE.instantiate()
		thief.add_child(ping_visual)
		
		# --- THE MAGIC SETTING ---
		# This detaches the visual from the Thief's physical movement!
		ping_visual.top_level = true 
		ping_visual.visible = false

func trigger_ping(pos: Vector3):
	if not ping_visual: return
	
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var spawned = GameManager.get_spawned_objects()
		if spawned:
			var local_player = spawned.get_node_or_null(str(multiplayer.get_unique_id()))
			if local_player and local_player.get("team_index") == 0: # 0 is Thief team
				pass # Ground ping is now completely silent as requested

	# Optional map ping (the old 2d one)
	# EventBus.emit_signal("map_ping", pos)
	
	var local_id = thief.multiplayer.get_unique_id()
	if GameManager.players.has(local_id) and GameManager.players[local_id].get("role") == GameManager.PlayerRole.COP:
		return
	
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

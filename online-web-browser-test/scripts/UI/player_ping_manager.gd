extends Node
class_name PlayerPingManager

var player: CharacterBody3D
var ping_timer: SceneTreeTimer = null
var cop_ping_visual: Node3D = null

func setup(parent_player: CharacterBody3D):
	player = parent_player

func trigger_ping():
	var local_id = player.multiplayer.get_unique_id()
	if GameManager.players.has(local_id) and GameManager.players[local_id].get("role") == GameManager.PlayerRole.COP:
		return
		
	if not cop_ping_visual:
		_ready_ping_visual()
		
	if cop_ping_visual:
		cop_ping_visual.visible = true
		AudioManager.play_3d_sfx("cop_ping", player.global_position)
		
		# --- FIX: SAFE DISCONNECT ---
		if ping_timer and ping_timer.timeout.is_connected(_hide_ping):
			ping_timer.timeout.disconnect(_hide_ping)
		# ----------------------------
			
		# --- USE BALANCE COP PING DURATION ---
		ping_timer = player.get_tree().create_timer(Balance.cop_spot_ping_duration)
		ping_timer.timeout.connect(_hide_ping)

const PING_SCENE = preload("res://scenes/MiscScenes/cop_ping.tscn")

func _ready_ping_visual():
	if PING_SCENE:
		cop_ping_visual = PING_SCENE.instantiate()
		player.add_child(cop_ping_visual)
		
		var is_thief = player.get("team_index") == 0
		
		if is_thief:
			cop_ping_visual.position = Vector3(0, 2, 0) # Smaller offset for thief
			cop_ping_visual.scale = Vector3(0.8, 0.8, 0.8) # Scale down the thief ping
			var mesh_node = cop_ping_visual.get_node_or_null("MeshInstance3D")
			if mesh_node:
				var hypno_shader = load("res://Assets/Shaders/HypnoShader/hypnoShaderV2.tres")
				var new_mat = ShaderMaterial.new()
				new_mat.shader = hypno_shader
				mesh_node.material_override = new_mat
		else:
			cop_ping_visual.position = Vector3(0, 2.5, 0)
			
		cop_ping_visual.visible = false

func _hide_ping():
	if cop_ping_visual:
		cop_ping_visual.visible = false

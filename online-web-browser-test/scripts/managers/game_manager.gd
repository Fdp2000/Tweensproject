extends Node

const SCOREBOARD_SCENE = preload("res://scenes/Zones/Scoreboard.tscn")
const PING_SCENE = preload("res://scenes/MiscScenes/ping_marker.tscn")

enum GameState {
	LOBBY,
	PLAYING
}

enum PlayerRole {
	THIEF,
	COP
}

var current_state: GameState = GameState.LOBBY
var players: Dictionary = {}
var forced_teams: Dictionary = {}
var team_cash: int = 0
var cash_quota: int = 10000
var round_timer: int = 300
var active_thieves: int = 0

var last_heartbeat_times: Dictionary = {}
var last_server_pong_time: float = 0.0
var heartbeat_timer: Timer

signal player_joined(id: int)
signal lobby_updated
signal game_started
signal game_ended
signal cash_updated
signal time_updated(time_left: int)
signal game_over(winner_team: int)

var timer_node: Timer
var cached_scoreboard: Control = null

func _ready():
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 5.0
	heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(heartbeat_timer)

	timer_node = Timer.new()
	timer_node.wait_time = 1.0
	timer_node.autostart = false
	timer_node.timeout.connect(_on_timer_tick)
	add_child(timer_node)
	
	# PRE-CACHER: Instantiate the scoreboard on load so WebGL pre-renders the fonts!
	if SCOREBOARD_SCENE:
		cached_scoreboard = SCOREBOARD_SCENE.instantiate()
		cached_scoreboard.visible = false
		
		# CanvasLayer forces it to the top so it doesn't get buried under other UI
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100 
		canvas_layer.add_child(cached_scoreboard)
		add_child(canvas_layer)
		
		cached_scoreboard.set_process(false) # CRITICAL: Call this AFTER adding to tree!
		cached_scoreboard.process_mode = Node.PROCESS_MODE_DISABLED # Double tap!


func _on_timer_tick():
	if not multiplayer.is_server(): return
	if current_state != GameState.PLAYING: return
	
	round_timer -= 1
	rpc("sync_time", round_timer)
	
	if round_timer <= 0:
		rpc("end_game_with_winner", PlayerRole.COP)


func set_player_force_role(peer_id: int, role_string: String):
	if multiplayer.is_server():
		forced_teams[peer_id] = role_string


@rpc("any_peer", "call_local", "reliable")
func sync_time(time_left: int):
	round_timer = time_left
	time_updated.emit(round_timer)


func add_player(id: int, p_name: String = ""):
	if players.size() >= 10 and not players.has(id):
		if multiplayer.is_server() and id != 1:
			multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	if not players.has(id):
		var default_name = "Player " + str(players.size() + 1)
		players[id] = {
			"name": p_name if p_name != "" else default_name,
			"role": PlayerRole.THIEF
		}
		
		if multiplayer.is_server():
			last_heartbeat_times[id] = Time.get_ticks_msec()
			rpc("sync_full_lobby", players)
			player_joined.emit(id)
			lobby_updated.emit()
		else:
			lobby_updated.emit()


func remove_player(id: int):
	if players.has(id):
		last_heartbeat_times.erase(id)
		var role = players[id].get("role", PlayerRole.THIEF)
		players.erase(id)
		
		if multiplayer.is_server():
			rpc("sync_full_lobby", players)
			lobby_updated.emit()
		else:
			lobby_updated.emit()
		
		if current_state == GameState.PLAYING and multiplayer.is_server():
			if role == PlayerRole.THIEF:
				thief_captured()
			check_game_validity()
			
		if multiplayer.is_server():
			var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
			if spawned:
				var player_node = spawned.get_node_or_null(str(id))
				if player_node:
					player_node.queue_free()


@rpc("any_peer", "call_local")
func sync_player_data(id: int, p_name: String):
	if not multiplayer.is_server(): return
	
	if not players.has(id):
		add_player(id, p_name)
	else:
		if p_name != "":
			players[id]["name"] = p_name
		rpc("sync_full_lobby", players)


@rpc("authority", "call_local")
func sync_full_lobby(lobby_data: Dictionary):
	players = lobby_data
	lobby_updated.emit()


@rpc("any_peer", "call_local")
func start_game(role_assignments: Dictionary):
	current_state = GameState.PLAYING
	team_cash = 0
	active_thieves = 0
	
	for id_str in role_assignments.keys():
		var id = int(id_str)

		if players.has(id):
			var assigned_role = role_assignments[id_str]
			players[id]["role"] = assigned_role

			var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)

			if spawned:
				var player_node = spawned.get_node_or_null(str(id))

				if player_node:
					player_node.player_name = players[id].get("name", "Player " + str(id))
					player_node.team_index = 1 if assigned_role == PlayerRole.COP else 0

			if assigned_role == PlayerRole.THIEF:
				active_thieves += 1
	
	var total_players = players.size()
	
	match total_players:
		2:
			cash_quota = Balance.quota_2p
			round_timer = Balance.timer_2p
		3:
			cash_quota = Balance.quota_3p
			round_timer = Balance.timer_3p
		4:
			cash_quota = Balance.quota_4p
			round_timer = Balance.timer_4p
		5:
			cash_quota = Balance.quota_5p
			round_timer = Balance.timer_5p
		6:
			cash_quota = Balance.quota_6p
			round_timer = Balance.timer_6p
		7:
			cash_quota = Balance.quota_7p
			round_timer = Balance.timer_7p
		8:
			cash_quota = Balance.quota_8p
			round_timer = Balance.timer_8p
		9:
			cash_quota = Balance.quota_9p
			round_timer = Balance.timer_9p
		10:
			cash_quota = Balance.quota_10p
			round_timer = Balance.timer_10p
		_:
			cash_quota = Balance.quota_10p if total_players > 10 else Balance.quota_2p
			round_timer = Balance.timer_10p if total_players > 10 else Balance.timer_2p
	
	if multiplayer.is_server():
		timer_node.start()
		rpc("sync_time", round_timer)

	if multiplayer.is_server():
		print("SERVER PLAYERS DICTIONARY: ", players)

	game_started.emit()


@rpc("any_peer", "call_local")
func add_cash(amount: int):
	team_cash += amount
	cash_updated.emit()
	
	if multiplayer.is_server() and team_cash >= cash_quota:
		rpc("end_game_with_winner", PlayerRole.THIEF)


@rpc("any_peer", "call_local")
func thief_captured():
	if not multiplayer.is_server(): return

	active_thieves -= 1

	if active_thieves <= 0:
		rpc("end_game_with_winner", PlayerRole.COP)


@rpc("any_peer", "call_local")
func thief_rescued():
	if not multiplayer.is_server(): return
	active_thieves += 1


func check_game_validity():
	if not multiplayer.is_server(): return
	
	var cops = 0
	var thieves = 0

	for id in players.keys():
		if players[id]["role"] == PlayerRole.COP:
			cops += 1
		elif players[id]["role"] == PlayerRole.THIEF:
			thieves += 1
		
	if (cops == 0 or thieves == 0) and players.size() > 1:
		rpc("end_game_with_winner", PlayerRole.COP if thieves == 0 else PlayerRole.THIEF)


@rpc("any_peer", "call_local")
func end_game_with_winner(winner_team: int):
	if current_state != GameState.PLAYING: return

	current_state = GameState.LOBBY
	timer_node.stop()
	game_over.emit(winner_team)
	
	if multiplayer.is_server():
		var winner_text = "COPS SECURED THE MUSEUM" if winner_team == PlayerRole.COP else "THE THIEVES ESCAPED WITH THE LOOT"
		
		var cops_data = []
		var thieves_data = []
		
		var spawned = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects")

		if spawned:
			for player in spawned.get_children():
				var p_name = player.get("player_name") if player.get("player_name") else "Player"

				if player.get("team_index") == 1:
					var caps = player.get("total_captures")
					cops_data.append({"name": p_name, "captures": caps if caps != null else 0})
				else:
					var cash = player.get("cash_contributed")
					thieves_data.append({"name": p_name, "cash": cash if cash != null else 0})
					
		rpc("show_scoreboard", winner_text, cops_data, thieves_data)


@rpc("any_peer", "call_local")
func show_scoreboard(winner_text: String, cops_data: Array, thieves_data: Array):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)

	if client_ui and client_ui.get("current_hud"):
		client_ui.current_hud.queue_free()
		client_ui.current_hud = null
		
	if cached_scoreboard:
		cached_scoreboard.populate(winner_text, cops_data, thieves_data)
		cached_scoreboard.visible = true
		cached_scoreboard.process_mode = Node.PROCESS_MODE_INHERIT
		cached_scoreboard.set_process(true)
		cached_scoreboard.countdown = 5.0 # Reset timer


@rpc("any_peer", "call_local")
func return_to_lobby():
	if not multiplayer.is_server(): return
	rpc("client_return_to_lobby")


@rpc("any_peer", "call_local")
func client_return_to_lobby():
	if cached_scoreboard:
		cached_scoreboard.visible = false
		cached_scoreboard.process_mode = Node.PROCESS_MODE_DISABLED
		
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var spawned = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects")

		if spawned:
			for child in spawned.get_children():
				child.name += "_deleted"
				spawned.remove_child(child)
				child.queue_free()
				
		var artifacts = get_tree().get_nodes_in_group("artifact")

		for art in artifacts:
			if art.has_method("reset_artifact"):
				art.rpc("reset_artifact")
			
		team_cash = 0
		
		# Respawn all players in the lobby!
		for id in players.keys():
			player_joined.emit(id)
		
	game_ended.emit()

func full_teardown():
	var scoreboard = get_tree().get_root().get_node_or_null("Scoreboard")
	if scoreboard:
		scoreboard.queue_free()
		
	var spawned = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects")
	if spawned:
		for child in spawned.get_children():
			child.name += "_deleted"
			spawned.remove_child(child)
			child.queue_free()
			
	var artifacts = get_tree().get_nodes_in_group("artifact")
	for art in artifacts:
		if art.has_method("reset_artifact"):
			art.reset_artifact()
			
	team_cash = 0
	players.clear()
	last_heartbeat_times.clear()
	last_server_pong_time = 0.0
	game_ended.emit()

func host_start_game():
	if not multiplayer.is_server(): return
	
	if players.size() < 2:
		print("Cannot start game: Not enough players!")
		return
	
	var peer_ids = players.keys()
	peer_ids.shuffle()
	
	var assignments = {}
	var forced_cops = []
	var forced_thieves = []
	var random_pool = []
	
	for id in peer_ids:
		var force_choice = forced_teams.get(id, "random")

		if force_choice == "cop":
			forced_cops.append(id)
		elif force_choice == "thief":
			forced_thieves.append(id)
		else:
			random_pool.append(id)
			
	var total_players = peer_ids.size()
	var target_cops = 1
	
	if total_players >= Balance.min_players_for_3_cops:
		target_cops = 3
	elif total_players >= Balance.min_players_for_2_cops:
		target_cops = 2
	
	var cops_needed = target_cops - forced_cops.size()
	
	for id in forced_cops:
		assignments[str(id)] = PlayerRole.COP

	for id in forced_thieves:
		assignments[str(id)] = PlayerRole.THIEF
		
	for id in random_pool:
		if cops_needed > 0:
			assignments[str(id)] = PlayerRole.COP
			cops_needed -= 1
		else:
			assignments[str(id)] = PlayerRole.THIEF
			
	rpc("start_game", assignments)


@rpc("any_peer", "call_local")
func spawn_location_ping(pos: Vector3):
	if PING_SCENE:
		var ping = PING_SCENE.instantiate()
		add_child(ping)
		ping.global_position = pos


func _on_heartbeat_tick():
	if multiplayer and multiplayer.has_multiplayer_peer():
		if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return
			
		if multiplayer.is_server():
			var current_time = Time.get_ticks_msec()
			for peer_id in last_heartbeat_times.keys():
				if peer_id == 1: continue
				if (current_time - last_heartbeat_times[peer_id]) / 1000.0 > 10.0:
					print("[Heartbeat] Client %d timed out. Disconnecting." % peer_id)
					multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		else:
			var current_time = Time.get_ticks_msec()
			if last_server_pong_time == 0.0:
				last_server_pong_time = current_time
				
			if (current_time - last_server_pong_time) / 1000.0 > 10.0:
				print("[Heartbeat] Server timed out. Disconnecting.")
				multiplayer.multiplayer_peer.close()
				multiplayer.server_disconnected.emit()
				return
				
			rpc_id(1, "client_ping")

@rpc("any_peer", "call_remote", "reliable")
func client_ping():
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		last_heartbeat_times[sender_id] = Time.get_ticks_msec()
		rpc_id(sender_id, "server_pong")

@rpc("authority", "call_remote", "reliable")
func server_pong():
	last_server_pong_time = Time.get_ticks_msec()

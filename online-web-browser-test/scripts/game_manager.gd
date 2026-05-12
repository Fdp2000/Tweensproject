extends Node

enum GameState {
	LOBBY,
	PLAYING
}

enum PlayerRole {
	THIEF,
	COP
}

var current_state: GameState = GameState.LOBBY
var players: Dictionary = {} # Key: Peer ID (int), Value: Dictionary { "name": String, "ready": bool, "role": PlayerRole }
var team_cash: int = 0
var cash_quota: int = 10000
var round_timer: int = 300
var active_thieves: int = 0

signal lobby_updated
signal game_started
signal game_ended
signal cash_updated
signal time_updated(time_left: int)
signal game_over(winner_team: int)

var timer_node: Timer

func _ready():
	timer_node = Timer.new()
	timer_node.wait_time = 1.0
	timer_node.autostart = false
	timer_node.timeout.connect(_on_timer_tick)
	add_child(timer_node)

func _on_timer_tick():
	if not multiplayer.is_server(): return
	if current_state != GameState.PLAYING: return
	
	round_timer -= 1
	rpc("sync_time", round_timer)
	
	if round_timer <= 0:
		rpc("end_game_with_winner", PlayerRole.COP)

@rpc("any_peer", "call_local", "unreliable")
func sync_time(time_left: int):
	round_timer = time_left
	time_updated.emit(round_timer)

func add_player(id: int, p_name: String = ""):
	if not players.has(id):
		var default_name = "Player " + str(players.size() + 1)
		players[id] = {
			"name": p_name if p_name != "" else default_name,
			"role": PlayerRole.THIEF
		}
		lobby_updated.emit()

func remove_player(id: int):
	if players.has(id):
		var role = players[id].get("role", PlayerRole.THIEF)
		players.erase(id)
		lobby_updated.emit()
		
		if current_state == GameState.PLAYING and multiplayer.is_server():
			if role == PlayerRole.THIEF:
				thief_captured() # Treat disconnect as capture for game end logic
			check_game_validity()

@rpc("any_peer", "call_local")
func sync_player_data(id: int, p_name: String):
	if not players.has(id):
		add_player(id, p_name)
	else:
		players[id]["name"] = p_name
		lobby_updated.emit()

@rpc("any_peer", "call_local")
func start_game(role_assignments: Dictionary):
	current_state = GameState.PLAYING
	team_cash = 0
	active_thieves = 0
	
	for id_str in role_assignments.keys():
		var id = int(id_str)
		if players.has(id):
			players[id]["role"] = role_assignments[id_str]
			if role_assignments[id_str] == PlayerRole.THIEF:
				active_thieves += 1
	
	cash_quota = max(1, active_thieves) * 5000
	round_timer = 300 # 5 minutes
	
	if multiplayer.is_server():
		timer_node.start()
		rpc("sync_time", round_timer)
			
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
		if players[id]["role"] == PlayerRole.COP: cops += 1
		elif players[id]["role"] == PlayerRole.THIEF: thieves += 1
		
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
		
	var scoreboard_scene = load("res://scenes/Scoreboard.tscn")
	if scoreboard_scene:
		var scoreboard = scoreboard_scene.instantiate()
		get_tree().get_root().add_child(scoreboard)
		scoreboard.populate(winner_text, cops_data, thieves_data)

@rpc("any_peer", "call_local")
func return_to_lobby():
	if not multiplayer.is_server(): return
	rpc("client_return_to_lobby")

@rpc("any_peer", "call_local")
func client_return_to_lobby():
	var scoreboard = get_tree().get_root().get_node_or_null("Scoreboard")
	if scoreboard:
		scoreboard.queue_free()
		
	if multiplayer.is_server():
		var spawned = get_tree().get_root().get_node_or_null("World/main/SpawnedObjects")
		if spawned:
			for child in spawned.get_children():
				child.queue_free()
				
		var artifacts = get_tree().get_nodes_in_group("artifact")
		for art in artifacts:
			art.rpc("reset_artifact")
			
		# Reset global team cash and timer for the next round
		team_cash = 0
		
	for id in players.keys():
		pass # Ready state removed
		
	game_ended.emit()

func host_start_game():
	if not multiplayer.is_server(): return
	
	var peer_ids = players.keys()
	peer_ids.shuffle()
	
	var assignments = {}
	var total_players = peer_ids.size()
	
	var num_cops = 1
	if total_players >= 6:
		num_cops = 2
	if total_players >= 9:
		num_cops = 3
	
	for i in range(total_players):
		var role = PlayerRole.COP if i < num_cops else PlayerRole.THIEF
		assignments[str(peer_ids[i])] = role
		
	rpc("start_game", assignments)

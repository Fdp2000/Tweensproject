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
		players[id] = {
			"name": p_name if p_name != "" else "Player " + str(id),
			"ready": false,
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
func sync_player_data(id: int, p_name: String, is_ready: bool):
	if players.has(id):
		players[id]["name"] = p_name
		players[id]["ready"] = is_ready
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
	
	# Delay before kicking players back to lobby screen
	await get_tree().create_timer(5.0).timeout
	
	for id in players.keys():
		players[id]["ready"] = false
	game_ended.emit()

func all_players_ready() -> bool:
	if players.size() == 0: return false
	for id in players.keys():
		if not players[id]["ready"]: return false
	return true

func host_start_game():
	if not multiplayer.is_server(): return
	if not all_players_ready(): return
	
	var peer_ids = players.keys()
	peer_ids.shuffle()
	
	var assignments = {}
	var total_players = peer_ids.size()
	var num_cops = max(1, int(total_players / 4.0))
	
	for i in range(total_players):
		var role = PlayerRole.COP if i < num_cops else PlayerRole.THIEF
		assignments[str(peer_ids[i])] = role
		
	rpc("start_game", assignments)

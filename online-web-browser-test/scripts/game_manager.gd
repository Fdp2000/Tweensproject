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

signal lobby_updated
signal game_started
signal game_ended

func _ready():
	# Make sure we persist through scene changes if needed
	pass

func add_player(id: int, p_name: String = ""):
	if not players.has(id):
		players[id] = {
			"name": p_name if p_name != "" else "Player " + str(id),
			"ready": false,
			"role": PlayerRole.THIEF # Default, assigned later
		}
		lobby_updated.emit()

func remove_player(id: int):
	if players.has(id):
		players.erase(id)
		lobby_updated.emit()
		
		# Check if the game is ruined due to disconnect
		if current_state == GameState.PLAYING:
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
	
	# Update local roles based on host's assignments
	for id_str in role_assignments.keys():
		var id = int(id_str)
		if players.has(id):
			players[id]["role"] = role_assignments[id_str]
			
	game_started.emit()

func check_game_validity():
	if not multiplayer.is_server(): return
	
	# Example logic: if 0 cops or 0 thieves left, end game
	var cops = 0
	var thieves = 0
	for id in players.keys():
		if players[id]["role"] == PlayerRole.COP: cops += 1
		elif players[id]["role"] == PlayerRole.THIEF: thieves += 1
		
	if (cops == 0 or thieves == 0) and players.size() > 1:
		rpc("end_game")

@rpc("any_peer", "call_local")
func end_game():
	current_state = GameState.LOBBY
	# Reset readiness
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
	
	# Assign roles (1 Cop per 3 Thieves, or just random 1 cop if small lobby)
	var peer_ids = players.keys()
	peer_ids.shuffle()
	
	var assignments = {}
	var total_players = peer_ids.size()
	var num_cops = max(1, int(total_players / 4.0)) # At least 1 cop, +1 per 4 players
	
	for i in range(total_players):
		var role = PlayerRole.COP if i < num_cops else PlayerRole.THIEF
		# Convert integer key to string for JSON serialization over RPC
		assignments[str(peer_ids[i])] = role
		
	rpc("start_game", assignments)

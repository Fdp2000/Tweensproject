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

var all_vents: Array[Node] = []
var active_vents: Array[Node] = []

var last_heartbeat_times: Dictionary = {}
var last_server_pong_time: float = 0.0
var heartbeat_timer: Timer

@export var pre_game_fade_delay: float = 1.64

signal player_joined(id: int)
signal lobby_updated
signal pre_game_started(assignments: Dictionary)
signal game_started
signal game_ended
signal cash_updated
signal time_updated(time_left: int)
signal game_over(winner_team: int)

var timer_node: Timer
var cached_scoreboard: Control = null

var selected_chameleon_skin: int = 0
var selected_rhino_skin: int = 0
var employee_of_month_id: int = -1

var _cached_spawned_objects: Node = null

func get_spawned_objects() -> Node:
	if is_instance_valid(_cached_spawned_objects) and not _cached_spawned_objects.is_queued_for_deletion() and _cached_spawned_objects.is_inside_tree():
		return _cached_spawned_objects
		
	var root = get_tree().get_root()
	if root:
		_cached_spawned_objects = root.find_child("SpawnedObjects", true, false)
	return _cached_spawned_objects

func _ready():
	print("GameManager is ready.")
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
	
	if round_timer < 0:
		return # Infinite time!
	
	round_timer -= 1
	rpc("sync_time", round_timer)
	
	if round_timer <= 0:
		rpc("end_game_with_winner", PlayerRole.COP)


func set_player_force_role(peer_id: int, role_string: String):
	if multiplayer.is_server():
		forced_teams[peer_id] = role_string

@rpc("any_peer", "call_local", "reliable")
func sync_employee_of_month(chosen_id: int) -> void:
	employee_of_month_id = chosen_id
	print("Employee of the Month synced: ", employee_of_month_id)

@rpc("any_peer", "call_local", "reliable")
func sync_time(time_left: int):
	round_timer = time_left
	time_updated.emit(round_timer)


func add_player(id: int, p_name: String = "", chameleon_skin: int = 0, rhino_skin: int = 0):
	if players.size() >= 10 and not players.has(id):
		if multiplayer.is_server() and id != 1:
			multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	if not players.has(id):
		var default_name = "Player " + str(players.size() + 1)
		players[id] = {
			"name": p_name if p_name != "" else default_name,
			"role": PlayerRole.THIEF,
			"chameleon_skin": chameleon_skin,
			"rhino_skin": rhino_skin
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
			var spawned = get_spawned_objects()
			if spawned:
				var player_node = spawned.get_node_or_null(str(id))
				if player_node:
					player_node.queue_free()




@rpc("any_peer", "call_local")
func sync_player_data(id: int, p_name: String, chameleon_skin: int = 0, rhino_skin: int = 0):
	if not multiplayer.is_server(): 
		return
	
	if not players.has(id):
		add_player(id, p_name, chameleon_skin, rhino_skin)
	else:
		if p_name != "":
			players[id]["name"] = p_name

		players[id]["chameleon_skin"] = chameleon_skin
		players[id]["rhino_skin"] = rhino_skin

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

			var spawned = get_spawned_objects()

			if spawned:
				var player_node = spawned.get_node_or_null(str(id))

				if player_node:
					player_node.player_name = players[id].get("name", "Player " + str(id))
					player_node.team_index = 1 if assigned_role == PlayerRole.COP else 0

			if assigned_role == PlayerRole.THIEF:
				active_thieves += 1
	
	var total_players = players.size()
	
	match total_players:
		1:
			cash_quota = Balance.quota_2p # Default to 2p quota for testing
			round_timer = -1 # Infinite time flag
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
		rpc("sync_time", round_timer)

	if multiplayer.is_server():
		print("SERVER PLAYERS DICTIONARY: ", players)

	if multiplayer.is_server():
		var rhino_ids := []

		for id in players.keys():
			if players[id].get("role", PlayerRole.THIEF) == PlayerRole.COP:
				rhino_ids.append(id)

		if rhino_ids.size() > 0:
			employee_of_month_id = rhino_ids.pick_random()
		else:
			employee_of_month_id = -1

		rpc("sync_employee_of_month", employee_of_month_id)
		print("Host chose Employee of the Month: ", employee_of_month_id)

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


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		# Check if it already exists
		var existing = get_tree().get_root().get_node_or_null("AudioDevTool")
		if not existing:
			var devtool_script = load("res://scripts/UI/AudioDevTool.gd")
			var devtool = devtool_script.new()
			devtool.name = "AudioDevTool"
			get_tree().get_root().add_child(devtool)
		else:
			existing.queue_free()

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
		
		var spawned = get_spawned_objects()

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
	# Play the Thief Win music if the thieves won (force restarting it from the beginning!)
	if winner_text == "THE THIEVES ESCAPED WITH THE LOOT":
		AudioManager.play_music("thief_win", 0.5, 0.0, true)
		
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


func start_game_clock():
	if multiplayer.is_server():
		timer_node.start()
		open_initial_vents()

# --- VENT SYSTEM LOGIC ---

func register_vent(vent: Node):
	if not all_vents.has(vent):
		all_vents.append(vent)

func open_initial_vents():
	if not multiplayer.is_server() or all_vents.is_empty(): return
	
	# Close any currently open vents
	for vent in active_vents:
		if is_instance_valid(vent):
			vent.rpc("close_vent")
	active_vents.clear()
	
	# Determine how many vents to open based on cop count
	var cops_count = 0
	for id in players.keys():
		if players[id]["role"] == PlayerRole.COP:
			cops_count += 1
			
	var vents_to_open = max(1, cops_count)
	
	# Pick random vents
	var options = all_vents.duplicate()
	options.shuffle()
	
	for i in range(min(vents_to_open, options.size())):
		var vent = options[i]
		vent.rpc("open_vent")
		active_vents.append(vent)

func cycle_vent(old_vent_name: String):
	if not multiplayer.is_server(): return
	
	# Find and close the old vent
	var vent_to_remove = null
	for vent in active_vents:
		if vent.name == old_vent_name:
			vent_to_remove = vent
			break
			
	if vent_to_remove:
		vent_to_remove.rpc("close_vent")
		active_vents.erase(vent_to_remove)
		
	# Find a new closed vent
	var closed_vents = []
	for vent in all_vents:
		if not active_vents.has(vent) and vent != vent_to_remove:
			closed_vents.append(vent)
			
	if closed_vents.size() > 0:
		var new_vent = closed_vents.pick_random()
		new_vent.rpc("open_vent")
		active_vents.append(new_vent)
	elif vent_to_remove:
		# Edge case: No closed vents available! Re-open the old one
		vent_to_remove.rpc("open_vent")
		active_vents.append(vent_to_remove)

# -------------------------


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
		var spawned = get_spawned_objects()

		if spawned:
			for child in spawned.get_children():
				spawned.remove_child(child)
				child.queue_free()
				
		var artifacts = get_tree().get_nodes_in_group("artifact")

		for art in artifacts:
			if art.has_method("reset_artifact"):
				art.rpc("reset_artifact")
			
		team_cash = 0
		
		# Reset the vents properly without clearing the array (since the map isn't destroyed)
		for vent in active_vents:
			if is_instance_valid(vent):
				vent.rpc("close_vent")
		active_vents.clear()
			
	# EVERYBODY waits 0.5 seconds.
	# The screen is pitch black right now. This network buffer lets the despawn packets 
	# arrive and completely clear out the clients' MultiplayerSpawners before we try to respawn!
	await get_tree().create_timer(0.5).timeout
		
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		# Respawn all players in the lobby!
		for id in players.keys():
			player_joined.emit(id)
		
	game_ended.emit()

func full_teardown():
	var cutscene_manager = get_tree().get_root().find_child("CutsceneManager", true, false)
	if cutscene_manager and cutscene_manager.has_method("cancel_cinematic"):
		cutscene_manager.cancel_cinematic()

	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui:
		var menu_cam = client_ui.get("menu_camera")
		if menu_cam:
			menu_cam.make_current()

	var scoreboard = get_tree().get_root().get_node_or_null("Scoreboard")
	if scoreboard:
		scoreboard.queue_free()
		
	var spawned = get_spawned_objects()
	if spawned:
		for child in spawned.get_children():
			spawned.remove_child(child)
			child.queue_free()
			
	var artifacts = get_tree().get_nodes_in_group("artifact")
	for art in artifacts:
		if art.has_method("reset_artifact"):
			art.reset_artifact()
			
	team_cash = 0
	
	# Actually close the vents visually before clearing the list!
	for vent in all_vents:
		if is_instance_valid(vent) and vent.has_method("close_vent"):
			vent.close_vent()
	active_vents.clear()
	
	timer_node.stop()
	current_state = GameState.LOBBY
	
	players.clear()
	last_heartbeat_times.clear()
	last_server_pong_time = 0.0
	game_ended.emit()

func host_start_game():
	if not multiplayer.is_server(): return
	
	if players.size() < 1:
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
	elif total_players == 1:
		target_cops = 0
	
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
			
	rpc("trigger_pre_game_start", assignments)

@rpc("any_peer", "call_local")
func trigger_pre_game_start(assignments: Dictionary):
	pre_game_started.emit(assignments)
	
	# Dynamically grab the fade time from the CutsceneManager so we don't break your timings!
	var fade_time = 1.0
	var cutscene = get_tree().get_root().find_child("CutsceneManager", true, false)
	if cutscene and "pre_game_fade_to_black_time" in cutscene:
		fade_time = cutscene.pre_game_fade_to_black_time
	
	# Wait exactly until the screen is 100% pitch black
	await get_tree().create_timer(fade_time).timeout
	
	# NUKE THE LOBBY PLAYERS HERE! The screen is fully black now!
	if multiplayer.is_server():
		var spawned = get_spawned_objects()
		if spawned:
			for child in spawned.get_children():
				spawned.remove_child(child)
				child.queue_free()
				
	# Wait the remaining buffer time for the network to sync the deletions
	var remaining_time = max(0.0, pre_game_fade_delay - fade_time)
	if remaining_time > 0.0:
		await get_tree().create_timer(remaining_time).timeout
	
	if multiplayer.is_server():
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

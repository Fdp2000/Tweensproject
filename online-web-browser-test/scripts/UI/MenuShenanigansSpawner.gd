extends Node3D

@export var thief_scene: PackedScene = preload("res://scenes/UIScenes/ShenaniganThief.tscn")
@export var cop_scene: PackedScene = preload("res://scenes/UIScenes/ShenaniganCop.tscn")
@export var spawn_interval_min: float = 4.0
@export var spawn_interval_max: float = 6.0
@export var chase_delay: float = 1.0

var spawn_pairs: Array[Dictionary] = []
var spawn_timer: Timer
var last_pair_index: int = -1
var is_temporarily_disabled: bool = false

func _ready():
	# Hook into GameManager to disable spawning during the 1.6s pre-game cutscene and the 5.0s scoreboard screen!
	if GameManager.has_signal("pre_game_started"):
		GameManager.pre_game_started.connect(func(_assignments): _set_disabled(true))
	if GameManager.has_signal("game_over"):
		GameManager.game_over.connect(func(_winner): _set_disabled(true))
	if GameManager.has_signal("game_ended"):
		GameManager.game_ended.connect(func(): _set_disabled(false))
		
	# Find all child markers and group them by prefixes like "A_Start", "A_End", "B_Start", "B_End"
	var markers = {}
	for child in get_children():
		if child is Marker3D:
			var parts = child.name.split("_")
			if parts.size() == 2:
				var group = parts[0]
				var type = parts[1]
				if not markers.has(group):
					markers[group] = {}
				markers[group][type] = child
				
	for group in markers.keys():
		if markers[group].has("Start") and markers[group].has("End"):
			var mid = Vector3.ZERO
			if markers[group].has("Mid"):
				mid = markers[group]["Mid"].global_position
			spawn_pairs.append({
				"group": group,
				"start": markers[group]["Start"].global_position,
				"mid": mid,
				"end": markers[group]["End"].global_position
			})
			
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_timer_timeout)
	add_child(spawn_timer)
	
	if spawn_pairs.size() > 0:
		_start_timer()

func _start_timer():
	spawn_timer.start(randf_range(spawn_interval_min, spawn_interval_max))

func _set_disabled(disabled: bool):
	is_temporarily_disabled = disabled
	if disabled:
		# Immediately delete any walkers currently on the screen!
		for child in get_parent().get_children():
			if child.name.contains("ShenaniganThief") or child.name.contains("ShenaniganCop"):
				child.queue_free()

func _on_timer_timeout():
	if not is_inside_tree() or GameManager.current_state != GameManager.GameState.LOBBY or is_temporarily_disabled:
		_start_timer() # Keep timer running quietly in background so it's ready when we return to lobby
		return
		
	# Pick a random pair that is NOT the same as the last one
	var index = randi() % spawn_pairs.size()
	while index == last_pair_index and spawn_pairs.size() > 1:
		index = randi() % spawn_pairs.size()
	last_pair_index = index
	
	var pair = spawn_pairs[index]
	
	var is_reverse = randf() > 0.5
	var start_pos: Vector3
	var points: Array[Vector3] = []
	
	if is_reverse:
		start_pos = pair["end"]
		if pair["mid"] != Vector3.ZERO:
			points.append(pair["mid"])
		points.append(pair["start"])
	else:
		start_pos = pair["start"]
		if pair["mid"] != Vector3.ZERO:
			points.append(pair["mid"])
		points.append(pair["end"])
	
	# Spawn Thief
	var thief = thief_scene.instantiate()
	get_parent().add_child(thief)
	thief.global_position = start_pos
	thief.target_points = points
	thief.scale = Vector3(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5)
	
	# Wait for chase delay, then spawn Cop chasing the Thief!
	await get_tree().create_timer(chase_delay).timeout
	
	# Double check we are still in lobby before spawning the cop!
	if GameManager.current_state == GameManager.GameState.LOBBY and not is_temporarily_disabled:
		var cop = cop_scene.instantiate()
		get_parent().add_child(cop)
		cop.global_position = start_pos
		cop.target_points = points
		cop.scale = Vector3(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5)
		
		# Wait for the cop to finish their run and delete themselves!
		await cop.tree_exited
	
	# Only start the countdown for the next event AFTER this one finishes!
	_start_timer()

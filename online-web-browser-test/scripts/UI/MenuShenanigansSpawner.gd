extends Node3D

@export var thief_scene: PackedScene = preload("res://scenes/UIScenes/ShenaniganThief.tscn")
@export var cop_scene: PackedScene = preload("res://scenes/UIScenes/ShenaniganCop.tscn")
@export var spawn_interval_min: float = 4.0
@export var spawn_interval_max: float = 6.0
@export var chase_delay: float = 1.0

var spawn_pairs: Array[Dictionary] = []
var spawn_timer: Timer
var last_pair_index: int = -1

@export_category("Debug")
@export var trigger_event_A: bool = false:
	set(value): _debug_trigger("A")
@export var trigger_event_B: bool = false:
	set(value): _debug_trigger("B")
@export var trigger_event_C: bool = false:
	set(value): _debug_trigger("C")

func _ready():
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

func _on_timer_timeout():
	# If we're not in the lobby, wipe any existing actors and stop spawning
	if GameManager.current_state != GameManager.GameState.LOBBY:
		# The individual wanderers handle their own deletion, but we just won't spawn new ones
		_start_timer() # Keep timer running quietly in background so it's ready when we return to lobby
		return
		
	# Pick a random pair that is NOT the same as the last one
	var index = randi() % spawn_pairs.size()
	while index == last_pair_index and spawn_pairs.size() > 1:
		index = randi() % spawn_pairs.size()
	last_pair_index = index
	
	var pair = spawn_pairs[index]
	
	var points: Array[Vector3] = []
	if pair["mid"] != Vector3.ZERO:
		points.append(pair["mid"])
	points.append(pair["end"])
	
	# Spawn Thief
	var thief = thief_scene.instantiate()
	get_parent().add_child(thief)
	thief.global_position = pair["start"]
	thief.target_points = points
	thief.scale = Vector3(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5)
	
	# Wait for chase delay, then spawn Cop chasing the Thief!
	await get_tree().create_timer(chase_delay).timeout
	
	# Double check we are still in lobby before spawning the cop!
	if GameManager.current_state == GameManager.GameState.LOBBY:
		var cop = cop_scene.instantiate()
		get_parent().add_child(cop)
		cop.global_position = pair["start"]
		cop.target_points = points
		cop.scale = Vector3(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5)
		
		# Wait for the cop to finish their run and delete themselves!
		await cop.tree_exited
	
	# Only start the countdown for the next event AFTER this one finishes!
	_start_timer()

func _input(event):
	# Developer keyboard shortcuts!
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_7: _debug_trigger("A")
		if event.keycode == KEY_8: _debug_trigger("B")
		if event.keycode == KEY_9: _debug_trigger("C")

func _debug_trigger(group_name: String):
	if not is_inside_tree() or GameManager.current_state != GameManager.GameState.LOBBY:
		return
		
	# Find the pair with this group name
	var found_pair = null
	for pair in spawn_pairs:
		if pair["group"] == group_name:
			found_pair = pair
			break
			
	if found_pair != null:
		# Restart the timer so it doesn't overlap with our manual debug spawn
		spawn_timer.stop()
		
		var points: Array[Vector3] = []
		if found_pair["mid"] != Vector3.ZERO:
			points.append(found_pair["mid"])
		points.append(found_pair["end"])
		
		# Spawn Thief
		var thief = thief_scene.instantiate()
		get_parent().add_child(thief)
		thief.global_position = found_pair["start"]
		thief.target_points = points
		thief.scale = Vector3(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5)
		
		# Wait for chase delay, then spawn Cop chasing the Thief!
		await get_tree().create_timer(chase_delay).timeout
		
		# Double check we are still in lobby before spawning the cop!
		if GameManager.current_state == GameManager.GameState.LOBBY:
			# Spawn Cop
			var cop = cop_scene.instantiate()
			get_parent().add_child(cop)
			cop.global_position = found_pair["start"]
			cop.target_points = points
			cop.scale = Vector3(1.0 / 1.5, 1.0 / 1.5, 1.0 / 1.5)
			
			await cop.tree_exited
		
		_start_timer()

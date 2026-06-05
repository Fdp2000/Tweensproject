extends Node3D

@export var wanted_poster_scene: PackedScene
@export var employee_poster_scene: PackedScene

@export var chameleon_skin_images: Array[Texture2D]
@export var rhino_skin_images: Array[Texture2D]

@onready var wanted_spawns: Node3D = $WantedPosterSpawns
@onready var employee_spawns: Node3D = $EmployeePosterSpawns

var spawned_posters: Array[Node] = []


func _ready() -> void:
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(clear_posters)


func _on_game_started() -> void:
	# Wait a tiny bit so GameManager.players roles/skins are ready.
	await get_tree().process_frame
	build_posters_from_players()


func build_posters_from_players() -> void:
	clear_posters()

	var wanted_markers := wanted_spawns.get_children()
	var employee_markers := employee_spawns.get_children()

	var wanted_index := 0
	var rhino_players := []

	# First pass:
	# Spawn wanted posters for every chameleon.
	# Collect all rhinos into a list.
	for id in GameManager.players.keys():
		var data = GameManager.players[id]

		var player_name: String = data.get("name", "Player")
		var role: int = data.get("role", GameManager.PlayerRole.THIEF)

		if role == GameManager.PlayerRole.THIEF:
			if wanted_index >= wanted_markers.size():
				print("Not enough wanted poster spawn points.")
				continue

			var skin_index: int = data.get("chameleon_skin", 0)
			var texture := get_safe_texture(chameleon_skin_images, skin_index)

			var poster = wanted_poster_scene.instantiate()
			wanted_markers[wanted_index].add_child(poster)
			poster.global_transform = wanted_markers[wanted_index].global_transform

			if poster.has_method("setup_poster"):
				poster.setup_poster(player_name, texture)

			spawned_posters.append(poster)
			wanted_index += 1

		elif role == GameManager.PlayerRole.COP:
			rhino_players.append(data)

	# Second pass:
	# Pick ONE random rhino for Employee of the Month.
	if rhino_players.size() > 0 and employee_markers.size() > 0:
		var chosen_rhino = rhino_players.pick_random()

		var employee_name: String = chosen_rhino.get("name", "Employee")
		var rhino_skin_index: int = chosen_rhino.get("rhino_skin", 0)
		var rhino_texture := get_safe_texture(rhino_skin_images, rhino_skin_index)

		var poster = employee_poster_scene.instantiate()
		employee_markers[0].add_child(poster)
		poster.global_transform = employee_markers[0].global_transform

		if poster.has_method("setup_poster"):
			poster.setup_poster(employee_name, rhino_texture)

		spawned_posters.append(poster)
	else:
		print("No rhinos found, or no employee poster spawn point.")


func get_safe_texture(texture_array: Array[Texture2D], index: int) -> Texture2D:
	if texture_array.is_empty():
		return null

	index = clampi(index, 0, texture_array.size() - 1)
	return texture_array[index]


func clear_posters() -> void:
	for poster in spawned_posters:
		if is_instance_valid(poster):
			poster.queue_free()

	spawned_posters.clear()

extends CanvasLayer

@onready var robbers_list: VBoxContainer = $Root/Panel/RobbersList
@onready var cops_list: VBoxContainer = $Root/Panel/CopsList
@onready var root_control: Control = $Root
@onready var left_spawn: Node3D = $Root/SubViewportContainer/SubViewport/LeftSpawn
@onready var right_spawn: Node3D = $Root/SubViewportContainer/SubViewport/RightSpawn
@onready var preview_camera: Camera3D = $Root/SubViewportContainer/SubViewport/Camera3D

@export var thief_preview_scene: PackedScene
@export var cop_preview_scene: PackedScene

func _ready():
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.size = get_viewport().get_visible_rect().size

func _notification(what):
	if what == Control.NOTIFICATION_RESIZED:
		if root_control:
			root_control.size = get_viewport().get_visible_rect().size

func show_from_spawned(spawned: Node):
	visible = true
	preview_camera.current = true

	clear_models()
	clear_name_lists()

	var robbers := []
	var cops := []

	for player in spawned.get_children():
		var player_name := get_display_name(player)
		var team_index = player.get("team_index")

		if team_index == 1:
			add_name_to_list(cops_list, player_name)
			cops.append(player)
		else:
			add_name_to_list(robbers_list, player_name)
			robbers.append(player)

	for i in range(robbers.size()):
		if thief_preview_scene:
			var model = thief_preview_scene.instantiate()
			left_spawn.add_child(model)

			apply_lineup_transform(model, i, robbers.size(), false)
			play_emote(model)

	for i in range(cops.size()):
		if cop_preview_scene:
			var model = cop_preview_scene.instantiate()
			right_spawn.add_child(model)

			apply_lineup_transform(model, i, cops.size(), true)
			play_emote(model)

func add_name_to_list(list: VBoxContainer, player_name: String):
	var label := Label.new()
	label.text = player_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)

	list.add_child(label)


func get_display_name(player: Node3D) -> String:
	print("Versus reading player ", player.name, " player_name = ", player.get("player_name"))
	var n = player.get("player_name")

	if n != null and str(n) != "":
		return str(n)

	var game_manager = get_tree().get_root().find_child("GameManager", true, false)
	if game_manager:
		var peer_id := int(str(player.name))
		if game_manager.players.has(peer_id):
			return str(game_manager.players[peer_id].get("name", "Player " + str(peer_id)))

	return "Player " + str(player.name)


func play_emote(model: Node3D):
	var anim = model.find_child("AnimationPlayer", true, false)

	if anim:
		if anim.has_animation("emote"):
			anim.play("emote")
		elif anim.has_animation("Idle1"):
			anim.play("Idle1")

func apply_lineup_transform(model: Node3D, index: int, total: int, is_cop: bool):

	var side := 1.0 if is_cop else -1.0
	var scale := 1.0
	var x := 0.0
	var z := 0.0

	match total:

		1:
			scale = 1.8
			x = side * 2.5
			z = 0.0

		2:
			scale = 1.4
			x = side * (2.0 + index * 1.2)
			z = 0.0

		3:
			scale = 1.1
			x = side * (1.8 + index * 0.8)
			z = 0.0

		4:
			scale = 1.0
			x = side * (1.6 + index * 0.7)
			z = 0.0

		_:
			scale = 0.85

			var row := int(index / 3)
			var col := index % 3

			x = side * (1.5 + col * 0.7)
			z = row * -0.9

	model.position = Vector3(x, 0, z)

	model.scale = Vector3.ONE * scale

	if is_cop:
		model.rotation.y = deg_to_rad(-20)
	else:
		model.rotation.y = deg_to_rad(20)


func clear_models():
	for child in left_spawn.get_children():
		child.queue_free()

	for child in right_spawn.get_children():
		child.queue_free()


func clear_name_lists():
	for child in robbers_list.get_children():
		child.queue_free()

	for child in cops_list.get_children():
		child.queue_free()


func hide_matchup():
	visible = false
	clear_models()
	clear_name_lists()

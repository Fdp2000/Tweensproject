extends CanvasLayer

@onready var robbers_list: VBoxContainer = $Root/Panel/RobbersList
@onready var cops_list: VBoxContainer = $Root/Panel/CopsList
@onready var root_control: Control = $Root
@onready var left_spawn: Node3D = $Root/SubViewportContainer/SubViewport/LeftSpawn
@onready var right_spawn: Node3D = $Root/SubViewportContainer/SubViewport/RightSpawn
@onready var preview_camera: Camera3D = $Root/SubViewportContainer/SubViewport/Camera3D

@export var thief_preview_scene: PackedScene
@export var cop_preview_scene: PackedScene

var left_model: Node3D
var right_model: Node3D

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

	var robber_index := 0
	var cop_index := 0

	for player in spawned.get_children():
		var player_name := get_display_name(player)
		var team_index = player.get("team_index")

		if team_index == 1:
			add_name_to_list(cops_list, player_name)

			if cop_index == 0 and cop_preview_scene:
				right_model = cop_preview_scene.instantiate()
				right_spawn.add_child(right_model)
				play_emote(right_model)

			cop_index += 1

		else:
			add_name_to_list(robbers_list, player_name)

			if robber_index == 0 and thief_preview_scene:
				left_model = thief_preview_scene.instantiate()
				left_spawn.add_child(left_model)
				play_emote(left_model)

			robber_index += 1


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
		elif anim.has_animation("idle"):
			anim.play("idle")


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

extends CanvasLayer

@onready var left_name_label: Label = $LeftName
@onready var right_name_label: Label = $RightName

@onready var left_spawn: Node3D = $SubViewportContainer/SubViewport/LeftSpawn
@onready var right_spawn: Node3D = $SubViewportContainer/SubViewport/RightSpawn

var left_model: Node3D
var right_model: Node3D


func show_versus(left_name: String, right_name: String, left_scene: PackedScene, right_scene: PackedScene):
	visible = true

	left_name_label.text = left_name
	right_name_label.text = right_name

	clear_models()

	left_model = left_scene.instantiate()
	right_model = right_scene.instantiate()

	left_spawn.add_child(left_model)
	right_spawn.add_child(right_model)

	play_emote(left_model)
	play_emote(right_model)


func play_emote(model: Node3D):
	var anim_player = model.find_child("AnimationPlayer", true, false)

	if anim_player:
		anim_player.play("emote")


func clear_models():
	for child in left_spawn.get_children():
		child.queue_free()

	for child in right_spawn.get_children():
		child.queue_free()


func hide_versus():
	visible = false

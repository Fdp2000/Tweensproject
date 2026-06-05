extends Node3D

@onready var name_label: Label3D = find_child("NameLabel", true, false) as Label3D
@onready var character_image: Sprite3D = find_child("CharacterImage", true, false) as Sprite3D

func setup_poster(player_name: String, skin_texture: Texture2D) -> void:
	if name_label:
		name_label.text = player_name
	else:
		print("WantedPoster missing NameLabel")

	if character_image:
		character_image.texture = skin_texture
	else:
		print("WantedPoster missing CharacterImage")

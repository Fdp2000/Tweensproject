extends Area3D
class_name BiomeAudioTrigger

@export_category("Biome Music Settings")
@export var biome_music_track: String = "biome_asia"
@export var default_music_track: String = "base_tension"
@export var crossfade_duration: float = 2.0

func _ready():
	# Automatically connect the Area3D signals when the game starts
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D):
	# We ONLY want the music to change when the LOCAL player walks into the area.
	# We don't want the music to change just because a clone or a physics prop fell into the room!
	if body is CharacterBody3D and body.has_method("is_multiplayer_authority"):
		if body.is_multiplayer_authority():
			AudioManager.play_music(biome_music_track, crossfade_duration)

func _on_body_exited(body: Node3D):
	if body is CharacterBody3D and body.has_method("is_multiplayer_authority"):
		if body.is_multiplayer_authority():
			AudioManager.play_music(default_music_track, crossfade_duration)

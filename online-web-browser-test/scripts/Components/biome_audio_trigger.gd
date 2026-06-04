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
	if body is CharacterBody3D and body.has_method("is_multiplayer_authority"):
		if body.is_multiplayer_authority():
			if "current_physical_biome" in body:
				body.current_physical_biome = biome_music_track
				
			# Don't change actual music if we are looking through cameras!
			var cam_manager = body.get("camera_manager")
			if cam_manager and cam_manager.is_on_cameras:
				return
				
			AudioManager.play_music(biome_music_track, crossfade_duration)

func _on_body_exited(body: Node3D):
	if body is CharacterBody3D and body.has_method("is_multiplayer_authority"):
		if body.is_multiplayer_authority():
			if "current_physical_biome" in body:
				body.current_physical_biome = default_music_track
				
			var cam_manager = body.get("camera_manager")
			if cam_manager and cam_manager.is_on_cameras:
				return
				
			AudioManager.play_music(default_music_track, crossfade_duration)

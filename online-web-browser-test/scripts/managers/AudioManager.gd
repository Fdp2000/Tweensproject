extends Node

# THE MASTER AUDIO CONFIGURATION
# Keys are the sound names you will call in code.
# The paths assume you have placed your files in res://Assets/Sound/SFX/
const MUSIC_CONFIG = {
	"main_menu":    {"path": "res://Assets/Sound/Music/MainMenu Theme/Criminal Chameleons Lobby.mp3", "volume": -5.0, "bus": "Music"},
	"match_start":  {"path": "res://Assets/Sound/Music/Intro Cutscene/Brassfall Surge.ogg", "volume": 0.0, "bus": "Music"},
	"base_tension": {"path": "res://Assets/Sound/Music/BaseMap Song/Stealth Drum Loop.ogg", "volume": -8.0, "bus": "Music"},
	"biome_forest": {"path": "res://Assets/Sound/Music/Biome_Forest.ogg", "volume": -8.0, "bus": "Music"},
	"biome_egypt":  {"path": "res://Assets/Sound/Music/Biome_Egypt.ogg", "volume": -8.0, "bus": "Music"},
	"biome_island": {"path": "res://Assets/Sound/Music/Biome_Island.ogg", "volume": -8.0, "bus": "Music"},
	"biome_antarctica": {"path": "res://Assets/Sound/Music/Biome_Antarctica.ogg", "volume": -8.0, "bus": "Music"},
	"biome_asia":   {"path": "res://Assets/Sound/Music/Biome_Asia.ogg", "volume": -8.0, "bus": "Music"}
}

const SFX_CONFIG = {
	# --- 2D / UI SOUNDS ---
	"ui_click":       {"path": "res://Assets/Sound/SFX/UI Click/click1.wav",       "volume": -5.0, "bus": "UI"},
	"countdown_tick": {"path": "res://Assets/Sound/SFX/Countdown/Beep.wav", "volume": -8.0, "bus": "UI"},
	"countdown_go":   {"path": "res://Assets/Sound/SFX/Countdown/GO!.wav",  "volume": -5.0, "bus": "UI"},
	"jailed":         {"path": "res://Assets/Sound/SFX/Jail Capture/Jail.wav", "volume":  0.0, "bus": "UI"},
	"rescue_progress":{"path": "res://Assets/Sound/SFX/Rescue_Progress.wav","volume": -5.0, "bus": "Quiet SFX"},
	
	# --- 3D / SPATIAL SOUNDS ---
	"join_lobby":     {"path": "res://Assets/Sound/SFX/PlayerJoin/virtual_vibes-cinematic-thud-fx-379991.wav", "volume": -2.0, "bus": "SFX", "max_distance": 20.0},
	"footstep_thief": {
		"paths": ["res://Assets/Sound/SFX/Thief Footstep/Final Theif footsteps1.wav", "res://Assets/Sound/SFX/Thief Footstep/Final Theif footsteps2.wav"], 
		"volume": -8.0, "bus": "Quiet SFX", "random_pitch": [0.9, 1.1],
		"max_distance": 15.0 # Fades completely to zero at 15 meters
	},
	"footstep_cop": {
		"paths": ["res://Assets/Sound/SFX/Cop Footsteps/CopFootsteps1.wav", "res://Assets/Sound/SFX/Cop Footsteps/CopFootsteps3.wav", "res://Assets/Sound/SFX/Cop Footsteps/CopFootsteps4.wav"], 
		"volume": -8.0, "bus": "SFX", "random_pitch": [0.85, 1.05],
		"max_distance": 25.0 # Cops are louder and can be heard from further away
	},
	"footstep_cop_charge": {
		"path": "res://Assets/Sound/SFX/Cop Footsteps/Cop Chargefootstep.wav", 
		"volume": -2.0, "bus": "SFX", "random_pitch": [0.95, 1.05],
		"max_distance": 40.0 # Charge should be extremely loud and terrifying
	},
	"footstep_cop_debuff": {
		"path": "res://Assets/Sound/SFX/Cop Footsteps/CopWALKFootsteps.wav", 
		"volume": -12.0, "bus": "Quiet SFX", "random_pitch": [0.8, 0.95],
		"max_distance": 15.0 # Exhausted dragging feet
	},
	"cop_vocals_grunt": {"path": "res://Assets/Sound/SFX/RhinoCharge.mp3", "volume": 0.0, "bus": "Loud SFX", "max_distance": 60.0},
	"charge_wall_impact": {"path": "res://Assets/Sound/SFX/RhinoImpact.mp3", "volume": 5.0, "bus": "Loud SFX", "max_distance": 80.0},
	"cop_vocals_exhausted": {
		"paths": ["res://Assets/Sound/SFX/Cops Breath/Breath1.wav", "res://Assets/Sound/SFX/Cops Breath/Breath2.wav", "res://Assets/Sound/SFX/Cops Breath/Breath3.wav"],
		"volume": -5.0, "bus": "SFX", "random_pitch": [0.9, 1.1], "max_distance": 20.0
	},
	"capture":          {"path": "res://Assets/Sound/SFX/Capture/bonk_BEtiM8g.wav", "volume": -2.0,  "bus": "Loud SFX", "max_distance": 50.0},
	"artifact_pickup":  {"path": "res://Assets/Sound/SFX/Aritfact Pick/ArtifactPickup.wav", "volume": 0.0, "bus": "SFX", "max_distance": 20.0},
	"artifact_drop":    {"path": "res://Assets/Sound/SFX/Aritfact Pick/Artifact Drop.wav",  "volume": 0.0, "bus": "SFX", "max_distance": 20.0},
	"artifact_delivery":{"path": "res://Assets/Sound/SFX/Artifact Delivery/ArtifactDelivery.wav", "volume": 5.0, "bus": "Loud SFX", "max_distance": 150.0},
	"cop_ping":         {"path": "res://Assets/Sound/SFX/Cop Ping/freesound_community-sonar-ping-95840.wav", "volume": 2.0, "bus": "SFX", "max_distance": 200.0}
}

# POOL CONFIGURATION
const POOL_SIZE_2D = 16
const POOL_SIZE_3D = 32

var pool_2d: Array[AudioStreamPlayer] = []
var pool_3d: Array[AudioStreamPlayer3D] = []
var stream_cache: Dictionary = {}

# Music State
var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var active_music_player: int = 1 # 1 = A, 2 = B
var current_music_track: String = ""
var music_time_memory: Dictionary = {}
var crossfade_tween: Tween

func _ready():
	# Keeps audio playing even if the game is paused (crucial for UI sounds)
	process_mode = Node.PROCESS_MODE_ALWAYS 
	_initialize_2d_pool()
	_initialize_3d_pool()
	_initialize_music_players()

func _initialize_2d_pool():
	for i in range(POOL_SIZE_2D):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool_2d.append(player)

func _initialize_music_players():
	music_player_a = AudioStreamPlayer.new()
	music_player_a.bus = "Music"
	add_child(music_player_a)
	
	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = "Music"
	add_child(music_player_b)

func _initialize_3d_pool():
	for i in range(POOL_SIZE_3D):
		var player = AudioStreamPlayer3D.new()
		# Default 3D settings (Inverse distance falloff is standard for realism)
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 2.0
		player.max_distance = 30.0 # Sounds completely fade out at 30 meters
		add_child(player)
		pool_3d.append(player)

# Helper function to load AudioStreams into memory and cache them
func _get_stream(path_data: Variant) -> AudioStream:
	# If it's an array of paths, pick a random one!
	var path: String = ""
	if typeof(path_data) == TYPE_ARRAY:
		path = path_data.pick_random()
	else:
		path = path_data

	if not stream_cache.has(path):
		if ResourceLoader.exists(path):
			stream_cache[path] = load(path)
		else:
			printerr("AudioManager ERROR: Audio file not found at path -> ", path)
			return null
	return stream_cache[path]

# ---------------------------------------------------------
# 2D GLOBAL / UI AUDIO (Stereo)
# ---------------------------------------------------------
func play_2d_sfx(sound_name: String):
	if not SFX_CONFIG.has(sound_name):
		printerr("AudioManager ERROR: Sound name '", sound_name, "' not found in SFX_CONFIG.")
		return
		
	var config = SFX_CONFIG[sound_name]
	# Pass "path" or "paths"
	var path_data = config.get("paths", config.get("path", ""))
	var stream = _get_stream(path_data)
	
	if stream == null:
		return
		
	# Find an idle player in the pool
	for player in pool_2d:
		if not player.playing:
			player.stream = stream
			player.volume_db = config.get("volume", 0.0)
			player.bus = config.get("bus", "Master")
			
			if config.has("random_pitch"):
				player.pitch_scale = randf_range(config["random_pitch"][0], config["random_pitch"][1])
			else:
				player.pitch_scale = 1.0
				
			player.play()
			return
			
	# If we reach here, all 16 players are currently playing sounds at the exact same time!
	printerr("AudioManager WARNING: 2D Audio pool exhausted! Too many sounds playing at once.")

# ---------------------------------------------------------
# 3D SPATIAL AUDIO (Mono)
# ---------------------------------------------------------
func play_3d_sfx(sound_name: String, global_pos: Vector3):
	if not SFX_CONFIG.has(sound_name):
		printerr("AudioManager ERROR: Sound name '", sound_name, "' not found in SFX_CONFIG.")
		return
		
	var config = SFX_CONFIG[sound_name]
	var path_data = config.get("paths", config.get("path", ""))
	var stream = _get_stream(path_data)
	
	if stream == null:
		return
		
	# Find an idle 3D player in the pool
	for player in pool_3d:
		if not player.playing:
			player.stream = stream
			player.volume_db = config.get("volume", 0.0)
			player.bus = config.get("bus", "Master")
			player.max_distance = config.get("max_distance", 30.0) 
			
			# Apply random pitch if configured
			if config.has("random_pitch"):
				player.pitch_scale = randf_range(config["random_pitch"][0], config["random_pitch"][1])
			else:
				player.pitch_scale = 1.0
			
			player.global_position = global_pos
			player.play()
			return
			
	printerr("AudioManager WARNING: 3D Audio pool exhausted! Too many sounds playing at once.")

# ---------------------------------------------------------
# MUSIC MANAGEMENT (Crossfading & Time Memory)
# ---------------------------------------------------------
func play_music(track_name: String, crossfade_time: float = 2.0, volume_offset: float = 0.0):
	if not MUSIC_CONFIG.has(track_name):
		printerr("AudioManager ERROR: Music track '", track_name, "' not found.")
		return
		
	var config = MUSIC_CONFIG[track_name]
	var target_vol = config.get("volume", 0.0) + volume_offset
	
	if current_music_track == track_name:
		# If it's already playing, we just smoothly tween it to the new volume_offset!
		var current_player = music_player_b if active_music_player == 2 else music_player_a
		if crossfade_tween:
			crossfade_tween.kill()
		crossfade_tween = create_tween()
		crossfade_tween.tween_property(current_player, "volume_db", target_vol, crossfade_time).set_trans(Tween.TRANS_SINE)
		return
		
	var stream = _get_stream(config["path"])
	if stream == null:
		return
		
	# Save the playback position of the current track before fading out
	var old_player = music_player_a if active_music_player == 1 else music_player_b
	var new_player = music_player_b if active_music_player == 1 else music_player_a
	
	if current_music_track != "" and old_player.playing:
		music_time_memory[current_music_track] = old_player.get_playback_position()
		
	current_music_track = track_name
	active_music_player = 2 if active_music_player == 1 else 1
	
	new_player.stream = stream
	new_player.bus = config.get("bus", "Music")
	
	# Restore time position if it exists, otherwise start at 0
	var start_time = music_time_memory.get(track_name, 0.0)
	new_player.volume_db = -80.0
	new_player.play(start_time)
	
	# Crossfade using a Tween
	if crossfade_tween:
		crossfade_tween.kill()
	crossfade_tween = create_tween()
	
	crossfade_tween.tween_property(new_player, "volume_db", target_vol, crossfade_time).set_trans(Tween.TRANS_SINE)
	if old_player.playing:
		crossfade_tween.parallel().tween_property(old_player, "volume_db", -80.0, crossfade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		crossfade_tween.tween_callback(old_player.stop)

func stop_music(fade_time: float = 1.0):
	if current_music_track == "":
		return
		
	var current_player = music_player_a if active_music_player == 1 else music_player_b
	
	# Save playback position so we can resume it later when play_music is called again
	if current_player.playing:
		music_time_memory[current_music_track] = current_player.get_playback_position()
	
	if crossfade_tween:
		crossfade_tween.kill()
	crossfade_tween = create_tween()
	
	if current_player.playing:
		crossfade_tween.tween_property(current_player, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		crossfade_tween.tween_callback(current_player.stop)
		
	current_music_track = ""

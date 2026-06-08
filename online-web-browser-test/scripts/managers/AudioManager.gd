extends Node3D

# THE MASTER AUDIO CONFIGURATION
# Keys are the sound names you will call in code.
# The paths assume you have placed your files in res://Assets/Sound/SFX/
var MUSIC_CONFIG = {
	"main_menu":    {"path": "res://Assets/Sound/Music/MainMenu Theme/Criminal Chameleons Lobby.mp3", "volume": -6.0, "bus": "Music"},
	"match_start":  {"path": "res://Assets/Sound/Music/Intro Cutscene/Brassfall Surge.ogg", "volume": -5, "bus": "Music"},
	"base_tension": {"path": "res://Assets/Sound/Music/BaseMap Song/Stealth Drum Loop.ogg", "volume": -18.0, "bus": "Music"},
	"biome_forest": {"path": "res://Assets/Sound/Music/Biomes/forest exhibit.ogg", "volume": -18.0, "bus": "Music"},
	"biome_egypt":  {"path": "res://Assets/Sound/Music/Biomes/egyptianexhibition.ogg", "volume": -18.0, "bus": "Music"},
	"biome_island": {"path": "res://Assets/Sound/Music/Biomes/tropical exhibit.ogg", "volume": -18.0, "bus": "Music"},
	"biome_antarctica": {"path": "res://Assets/Sound/Music/Biomes/arcticexhibition.ogg", "volume": -18.0, "bus": "Music"},
	"biome_asia":   {"path": "res://Assets/Sound/Music/Biomes/chinese exhibition.ogg", "volume": -18.0, "bus": "Music"},
	"thief_win":    {"path": "res://Assets/Sound/Music/cha milli.wav", "volume": -10.0, "bus": "Music"}
}

var SFX_CONFIG = {
	# --- 2D / UI SOUNDS ---
	"ui_click":       {"path": "res://Assets/Sound/SFX/UI Click/click1.wav",       "volume": -15.0, "bus": "UI"},
	"countdown_tick": {"path": "res://Assets/Sound/SFX/Countdown/Beep.wav", "volume": -20.0, "bus": "UI"},
	"countdown_go":   {"path": "res://Assets/Sound/SFX/Countdown/GO!.wav",  "volume": -17.0, "bus": "UI"},
	"rescue_progress":{"path": "res://Assets/Sound/SFX/Rescue Progress/Rescue Progress.wav","volume": -28, "bus": "Quiet SFX"},
	"rescue_success": {"path": "res://Assets/Sound/SFX/Rescue Progress/cha milli.wav", "volume": -12.0, "bus": "Loud SFX", "max_distance": 30.0, "unit_size": 14.0},
	
	# Lobby / Pre-game SFX
	"join_lobby":     {"path": "res://Assets/Sound/SFX/PlayerJoin/virtual_vibes-cinematic-thud-fx-379991.wav", "volume": -4.5, "bus": "Loud SFX", "max_distance": 20.0, "unit_size": 6.0, "attenuation": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC},
	"footstep_thief": {
		"paths": ["res://Assets/Sound/SFX/Thief Footstep/Final Theif footsteps1.wav", "res://Assets/Sound/SFX/Thief Footstep/Final Theif footsteps2.wav"], 
		"volume": -12.0, "bus": "Quiet SFX", "random_pitch": [0.9, 1.1],
		"max_distance": 15.0, "unit_size": 4.5
	},
	"footstep_cop": {
		"paths": ["res://Assets/Sound/SFX/Cop Footsteps/CopFootsteps1.wav", "res://Assets/Sound/SFX/Cop Footsteps/CopFootsteps3.wav", "res://Assets/Sound/SFX/Cop Footsteps/CopFootsteps4.wav"], 
		"volume": -12.0, "bus": "Quiet SFX", "random_pitch": [0.85, 1.05],
		"max_distance": 40.0, "unit_size": 13.0
	},
	"footstep_cop_charge": {
		"path": "res://Assets/Sound/SFX/Cop Footsteps/Cop Chargefootstep.wav", 
		"volume": -10.0, "bus": "Loud SFX", "random_pitch": [0.95, 1.05],
		"max_distance": 55.0, "unit_size": 18.0
	},
	"footstep_cop_debuff": {
		"path": "res://Assets/Sound/SFX/Cop Footsteps/CopWALKFootsteps.wav", 
		"volume": -12.0, "bus": "Quiet SFX", "random_pitch": [0.8, 0.95],
		"max_distance": 20.0, "unit_size": 10.0
	},
	"cop_exhausted_breath": {
		"paths": [
			"res://Assets/Sound/SFX/Cops Breath/Breath1.wav",
			"res://Assets/Sound/SFX/Cops Breath/Breath2.wav",
			"res://Assets/Sound/SFX/Cops Breath/Breath3.wav"
		],
		"volume": -8.0, "bus": "Quiet SFX", "max_distance": 25.0, "unit_size": 12.0
	},
	"cop_vocals_grunt": {"path": "res://Assets/Sound/SFX/RhinoCharge.mp3", "volume": 2.0, "bus": "Loud SFX", "max_distance": 35.0, "unit_size": 17.0},
	"charge_wall_impact": {"path": "res://Assets/Sound/SFX/RhinoImpact.mp3", "volume": 2.0, "bus": "Loud SFX", "max_distance": 35.0, "unit_size": 17.0},

	"capture":          {"path": "res://Assets/Sound/SFX/Capture/bonk_BEtiM8g.wav", "volume": -6.0,  "bus": "Loud SFX", "max_distance": 500.0, "unit_size": 55},
	"jailed":           {"path": "res://Assets/Sound/SFX/Jail Capture/Jail.wav", "volume": -4.0, "bus": "Loud SFX", "max_distance": 500.0, "unit_size": 500.0},
	"artifact_pickup":  {"path": "res://Assets/Sound/SFX/Aritfact Pick/ArtifactPickup.wav", "volume": -14.0, "bus": "Quiet SFX", "max_distance": 10.0, "unit_size": 3.0},
	"artifact_drop":    {"path": "res://Assets/Sound/SFX/Aritfact Pick/Artifact Drop.wav",  "volume": -14.0, "bus": "Quiet SFX", "max_distance": 10.0, "unit_size": 3.0},
	"artifact_delivery":{"path": "res://Assets/Sound/SFX/Artifact Delivery/ArtifactDelivery.wav", "volume": -2.0, "bus": "Loud SFX", "max_distance": 500.0, "unit_size": 500.0},
	"cop_ping":         {"path": "res://Assets/Sound/SFX/Cop Ping/freesound_community-sonar-ping-95840.wav", "volume": -18.0, "bus": "Loud SFX", "max_distance": 500.0, "unit_size": 500.0}
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
var current_music_player: AudioStreamPlayer
var current_biome: String = ""

# --- Hypnosis Audio Effects ---
var hypno_chorus: AudioEffectChorus
var hypno_lowpass: AudioEffectLowPassFilter
var hypno_reverb: AudioEffectReverb
var master_bus_idx: int
var hypno_chorus_idx: int
var hypno_lowpass_idx: int
var hypno_reverb_idx: int
var hypno_tween: Tween

var active_music_player: int = 1 # 1 = A, 2 = B
var current_music_track: String = ""
var music_time_memory: Dictionary = {}
var crossfade_tween: Tween

var _sfx_cooldowns: Dictionary = {}

func _ready():
	# Keeps audio playing even if the game is paused (crucial for UI sounds)
	process_mode = Node.PROCESS_MODE_ALWAYS 
	_initialize_2d_pool()
	_initialize_3d_pool()
	_initialize_music_players()
	_preload_all_audio()
	
	# Setup Hypno Effects dynamically so we don't corrupt the .tres file
	master_bus_idx = AudioServer.get_bus_index("Master")
	
	hypno_chorus = AudioEffectChorus.new()
	hypno_chorus.voice_count = 2
	hypno_chorus.wet = 0.8
	
	hypno_lowpass = AudioEffectLowPassFilter.new()
	hypno_lowpass.cutoff_hz = 20000.0 # Normal hearing
	
	hypno_reverb = AudioEffectReverb.new()
	hypno_reverb.room_size = 0.6
	hypno_reverb.wet = 0.4
	
	AudioServer.add_bus_effect(master_bus_idx, hypno_chorus)
	hypno_chorus_idx = AudioServer.get_bus_effect_count(master_bus_idx) - 1
	
	AudioServer.add_bus_effect(master_bus_idx, hypno_lowpass)
	hypno_lowpass_idx = AudioServer.get_bus_effect_count(master_bus_idx) - 1
	
	AudioServer.add_bus_effect(master_bus_idx, hypno_reverb)
	hypno_reverb_idx = AudioServer.get_bus_effect_count(master_bus_idx) - 1
	
	_set_hypno_effects_enabled(false)

func _set_hypno_effects_enabled(enabled: bool):
	AudioServer.set_bus_effect_enabled(master_bus_idx, hypno_chorus_idx, enabled)
	AudioServer.set_bus_effect_enabled(master_bus_idx, hypno_lowpass_idx, enabled)
	AudioServer.set_bus_effect_enabled(master_bus_idx, hypno_reverb_idx, enabled)

func set_hypnotized(is_hypnotized: bool):
	if hypno_tween:
		hypno_tween.kill()
	
	hypno_tween = create_tween()
	
	if is_hypnotized:
		_set_hypno_effects_enabled(true)
		hypno_tween.tween_property(hypno_lowpass, "cutoff_hz", 800.0, 1.5).set_trans(Tween.TRANS_SINE)
		hypno_tween.parallel().tween_property(hypno_chorus, "wet", 0.8, 1.5)
		hypno_tween.parallel().tween_property(hypno_reverb, "wet", 0.4, 1.5)
	else:
		hypno_tween.tween_property(hypno_lowpass, "cutoff_hz", 20000.0, 0.6).set_trans(Tween.TRANS_SINE)
		hypno_tween.parallel().tween_property(hypno_chorus, "wet", 0.0, 0.6)
		hypno_tween.parallel().tween_property(hypno_reverb, "wet", 0.0, 0.6)
		hypno_tween.tween_callback(func(): _set_hypno_effects_enabled(false))

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

func _preload_all_audio():
	# Forcibly load all audio into RAM during the loading screen 
	# instead of lagging the game the first time they are played!
	for config_dict in [MUSIC_CONFIG, SFX_CONFIG]:
		for key in config_dict.keys():
			var config = config_dict[key]
			if config.has("path"):
				_get_stream(config["path"])
			elif config.has("paths"):
				for p in config["paths"]:
					_get_stream(p)

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
	if config.get("disabled", false):
		return
		
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
			
			if config.has("pitch_override"):
				player.pitch_scale = config["pitch_override"]
			elif config.has("random_pitch"):
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
func play_3d_sfx(sfx_name: String, global_pos: Vector3):
	if not SFX_CONFIG.has(sfx_name):
		push_warning("SFX not found: " + sfx_name)
		return
		
	# Global cooldown for lobby join so it doesn't clip if 8 players spawn at once
	if sfx_name == "join_lobby":
		var now = Time.get_ticks_msec()
		if _sfx_cooldowns.has(sfx_name) and now - _sfx_cooldowns[sfx_name] < 200:
			return
		_sfx_cooldowns[sfx_name] = now
		
	var config = SFX_CONFIG[sfx_name]
	if config.get("disabled", false):
		return
		
	var path_data = config.get("paths", config.get("path", ""))
	var stream = _get_stream(path_data)
	
	if stream == null:
		return
		
	# Find an idle 3D player in the pool
	for player in pool_3d:
		if not player.playing:
			player.global_position = global_pos
			player.stream = stream
			player.volume_db = config.get("volume", 0.0)
			player.max_db = player.volume_db # MAGIC TRICK: Clamp the volume so it never exceeds 100% when inside the bubble!
			player.bus = config.get("bus", "Master")
			player.max_distance = config.get("max_distance", 30.0) 
			player.unit_size = config.get("unit_size", 1.0)
			player.attenuation_model = config.get("attenuation_model", AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC)
			
			# Apply random pitch if configured
			if config.has("pitch_override"):
				player.pitch_scale = config["pitch_override"]
			elif config.has("random_pitch"):
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
func play_music(track_name: String, crossfade_time: float = 2.0, volume_offset: float = 0.0, force_restart: bool = false):
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
	
	# Always restart cutscene tracks from the beginning (or if explicitly forced)!
	if force_restart or track_name == "match_start":
		start_time = 0.0
		music_time_memory[track_name] = 0.0
		
	new_player.volume_db = -80.0
	new_player.play(start_time)
	
	# Crossfade using a Tween
	if crossfade_tween:
		crossfade_tween.kill()
	crossfade_tween = create_tween()
	
	# FADE IN: We use EASE_OUT so it jumps up quickly and becomes audible, then settles at the target volume
	crossfade_tween.tween_property(new_player, "volume_db", target_vol, crossfade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if old_player.playing:
		# FADE OUT: We use EASE_IN so it stays loud for a moment, then drops quickly at the end
		crossfade_tween.parallel().tween_property(old_player, "volume_db", -80.0, crossfade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		crossfade_tween.tween_callback(old_player.stop)

func stop_music(fade_time: float = 1.0):
	if current_music_track == "":
		return
		
	var current_player = music_player_a if active_music_player == 1 else music_player_b
	
	# Save playback position so we can resume it later when play_music is called again
	if current_player.playing:
		music_time_memory[current_music_track] = current_player.get_playback_position()
	
	if current_player.playing:
		if crossfade_tween:
			crossfade_tween.kill()
		crossfade_tween = create_tween()
		crossfade_tween.tween_property(current_player, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		crossfade_tween.tween_callback(current_player.stop)
		
	current_music_track = ""

func _input(event):
	# DEV SHORTCUT: Mute/Unmute Master Bus
	if event is InputEventKey and event.physical_keycode == KEY_M and event.pressed and not event.echo:
		var master_bus_idx = AudioServer.get_bus_index("Master")
		var is_muted = not AudioServer.is_bus_mute(master_bus_idx)
		AudioServer.set_bus_mute(master_bus_idx, is_muted)
		print("Master Audio Muted: ", is_muted)

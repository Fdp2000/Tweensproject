extends Node

# THE MASTER AUDIO CONFIGURATION
# Keys are the sound names you will call in code.
# The paths assume you have placed your files in res://Assets/Sound/SFX/
const SFX_CONFIG = {
	# --- 2D / UI SOUNDS ---
	"ui_click":       {"path": "res://Assets/Sound/SFX/UI_Click.wav",       "volume": -5.0, "bus": "UI"},
	"cop_ping":       {"path": "res://Assets/Sound/SFX/Cop_Ping.wav",       "volume": -3.0, "bus": "UI"},
	"countdown_tick": {"path": "res://Assets/Sound/SFX/Countdown/Beep.wav", "volume": -8.0, "bus": "UI"},
	"countdown_go":   {"path": "res://Assets/Sound/SFX/Countdown/GO!.wav",  "volume": -5.0, "bus": "UI"},
	"jailed":         {"path": "res://Assets/Sound/SFX/Jailed.wav",         "volume":  0.0, "bus": "UI"},
	"rescue_progress":{"path": "res://Assets/Sound/SFX/Rescue_Progress.wav","volume": -5.0, "bus": "Quiet SFX"},
	
	# --- 3D / SPATIAL SOUNDS ---
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
	"capture":        {"path": "res://Assets/Sound/SFX/Capture.wav",        "volume": -2.0,  "bus": "Loud SFX", "max_distance": 50.0},
	"artifact_drop":  {"path": "res://Assets/Sound/SFX/Artifact_Drop.wav",  "volume":  0.0,  "bus": "Quiet SFX"}
}

# POOL CONFIGURATION
const POOL_SIZE_2D = 16
const POOL_SIZE_3D = 32

var pool_2d: Array[AudioStreamPlayer] = []
var pool_3d: Array[AudioStreamPlayer3D] = []
var stream_cache: Dictionary = {}

func _ready():
	# Keeps audio playing even if the game is paused (crucial for UI sounds)
	process_mode = Node.PROCESS_MODE_ALWAYS 
	_initialize_2d_pool()
	_initialize_3d_pool()

func _initialize_2d_pool():
	for i in range(POOL_SIZE_2D):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool_2d.append(player)

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

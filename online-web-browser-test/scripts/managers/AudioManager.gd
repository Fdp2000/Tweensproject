extends Node

# THE MASTER AUDIO CONFIGURATION
# Keys are the sound names you will call in code.
# The paths assume you have placed your files in res://Assets/Sound/SFX/
const SFX_CONFIG = {
	"ui_click":       {"path": "res://Assets/Sound/SFX/UI_Click.wav",       "volume": -5.0, "bus": "UI"},
	"cop_ping":       {"path": "res://Assets/Sound/SFX/Cop_Ping.wav",       "volume": -3.0, "bus": "UI"},
	"countdown_tick": {"path": "res://Assets/Sound/SFX/Countdown/Beep.wav", "volume": -8.0, "bus": "UI"},
	"countdown_go":   {"path": "res://Assets/Sound/SFX/Countdown/GO!.wav",   "volume": -5.0, "bus": "UI"},
	"jailed":         {"path": "res://Assets/Sound/SFX/Jailed.wav",         "volume":  0.0, "bus": "UI"},
	"rescue_progress":{"path": "res://Assets/Sound/SFX/Rescue_Progress.wav","volume": -5.0, "bus": "Quiet SFX"}
}

# POOL CONFIGURATION
const POOL_SIZE_2D = 16

var pool_2d: Array[AudioStreamPlayer] = []
var stream_cache: Dictionary = {}

func _ready():
	# Keeps audio playing even if the game is paused (crucial for UI sounds)
	process_mode = Node.PROCESS_MODE_ALWAYS 
	_initialize_2d_pool()

func _initialize_2d_pool():
	for i in range(POOL_SIZE_2D):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool_2d.append(player)

# Helper function to load AudioStreams into memory and cache them
func _get_stream(path: String) -> AudioStream:
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
	var stream = _get_stream(config["path"])
	
	if stream == null:
		return
		
	# Find an idle player in the pool
	for player in pool_2d:
		if not player.playing:
			player.stream = stream
			player.volume_db = config.get("volume", 0.0)
			player.bus = config.get("bus", "Master")
			player.play()
			return
			
	# If we reach here, all 16 players are currently playing sounds at the exact same time!
	printerr("AudioManager WARNING: 2D Audio pool exhausted! Too many sounds playing at once.")

extends Node

signal balance_updated

# ==========================================
# 1. MOVEMENT & CORE PHYSICS
# ==========================================
var base_thief_speed: float = 6.5
# The speed the Mixamo animation was originally recorded at. 
# (Most Mixamo jogs are around 4.0 m/s. Mixamo sprints are around 6.0 m/s).
var anim_native_speed: float = 4.0
var cop_base_speed: float = 6.85
var hypno_thief_speed: float = 2.05
var thief_braking_friction: float = 6.5
var cop_braking_friction: float = 6.5

# ==========================================
# 2. STEALTH & CAMERA PERSPECTIVE
# ==========================================
var thief_camo_activation_time: float = 0.5
var thief_camo_fade_duration_sec: float = 1.0 # Literal timer: Fades over 1.0 seconds
var cop_fov_angle: float = 90.0
var thief_spring_arm_length: float = 4.711 # (Your current X distance)

# ==========================================
# 3. ABILITIES & INTERACTION TIMERS
# ==========================================S
var cop_charge_speed_multiplier: float = 1.6 # 1.5x Base Speed
var cop_charge_duration: float = 1.2
var cop_charge_cooldown: float = 4.2
var cop_exhaustion_duration: float = 3
var cop_exhaustion_speed_multiplier: float = 0.35 # 0.6x Base Speed (40% slow)
var thief_rescue_time: float = 2.0

# ==========================================
# 4. ECONOMY & RADII
# ==========================================
var cash_small: int = 4_500_000
var cash_medium: int = 7_000_000
var cash_large: int = 12_000_000

var artifact_small_speed_multiplier: float = 0.9 # 90% Speed
var artifact_medium_speed_multiplier: float = 0.75 # 75% Speed
var artifact_large_speed_multiplier: float = 0.5 # 50% Speed

var delivery_zone_radius: float = 3.25
var interact_shape_size: float = 2.25
var camera_wall_radius: float = 0.15

# ==========================================
# 5. MATCH STRUCTURE & SCALING
# ==========================================
var min_players_for_2_cops: int = 6
var min_players_for_3_cops: int = 9

var quota_2p: int = 13_000_000
var quota_3p: int = 21_000_000
var quota_4p: int = 33_000_000
var quota_5p: int = 45_000_000
var quota_6p: int = 33_000_000
var quota_7p: int = 45_000_000
var quota_8p: int = 57_000_000
var quota_9p: int = 41_000_000
var quota_10p: int = 53_000_000

var timer_2p: int = 180
var timer_3p: int = 180
var timer_4p: int = 180
var timer_5p: int = 180
var timer_6p: int = 210
var timer_7p: int = 210
var timer_8p: int = 210
var timer_9p: int = 240
var timer_10p: int = 240

# ==========================================
# 6. PING CONSTRAINTS
# ==========================================
var cam_laser_ping_cooldown_ms: int = 1000
var thief_map_ping_duration: float = 5.0
var cop_spot_ping_duration: float = 5.0

# ==========================================
# PRESET & MEMORY SYSTEM
# ==========================================
var saved_presets: Dictionary = {}
const CUSTOM_SAVE_PATH: String = "user://balance_presets.json"
const OFFICIAL_SAVE_PATH: String = "res://default_presets.json"

func _ready():
	load_all_presets()

# --- THE NETWORK SYNC ---
# The Host calls this to push their UI slider settings to all connected players
func broadcast_balance_update():
	if multiplayer.is_server():
		var current_data = _get_current_state_dict()
		rpc("receive_balance_update", current_data)

@rpc("authority", "call_remote", "reliable")
func receive_balance_update(data: Dictionary):
	_apply_dict_to_state(data)
	print("Client successfully received Host's Balance settings!")

# --- SAVE & LOAD SYSTEM ---
func load_all_presets():
	# 1. ALWAYS capture the hardcoded variables first as our Baseline
	saved_presets["Default Game (Baseline)"] = _get_current_state_dict()

	# 2. Look for official team presets saved in the Godot project
	if FileAccess.file_exists(OFFICIAL_SAVE_PATH):
		var file = FileAccess.open(OFFICIAL_SAVE_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data and data is Dictionary:
			# This adds the Git presets alongside the Baseline
			saved_presets.merge(data, true)
		file.close()

	# 3. Look for custom presets the Host saved in their own browser/PC
	if FileAccess.file_exists(CUSTOM_SAVE_PATH):
		var file = FileAccess.open(CUSTOM_SAVE_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data and data is Dictionary:
			# This adds the local custom presets to the final list
			saved_presets.merge(data, true) 
		file.close()

func save_custom_preset(preset_name: String):
	saved_presets[preset_name] = _get_current_state_dict()
	var file = FileAccess.open(CUSTOM_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_presets, "\t"))
		file.close()

func apply_preset(preset_name: String):
	if saved_presets.has(preset_name):
		_apply_dict_to_state(saved_presets[preset_name])
		broadcast_balance_update() # Tell the server to tell everyone else!

# --- DEV EXPORT WORKFLOW ---
func export_to_clipboard(preset_name: String):
	var export_format = { preset_name: _get_current_state_dict() }
	var json_str = JSON.stringify(export_format, "\t")
	var copy_str = json_str.substr(2, json_str.length() - 4) + ","
	DisplayServer.clipboard_set(copy_str)
	print("Copied to clipboard! Paste into default_presets.json")

# --- INTERNAL HELPER DICTIONARIES ---
func _get_current_state_dict() -> Dictionary:
	var dict = {}
	for prop in get_property_list():
		var p_name = prop["name"]
		var p_type = prop["type"]
		var p_usage = prop["usage"]
		
		# Only grab our actual variables, ignore built-in Node properties
		if p_usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p_type in [TYPE_INT, TYPE_FLOAT]:
			dict[p_name] = get(p_name)
	return dict

func _apply_dict_to_state(data: Dictionary):
	for key in data.keys():
		if key in self: # Safe check to ensure variable exists
			set(key, data[key])
	balance_updated.emit()

func format_money(amount: int) -> String:
	if amount >= 1_000_000:
		var millions = float(amount) / 1_000_000.0
		var str_val = "%.1f" % millions
		if str_val.ends_with(".0"):
			str_val = str_val.left(str_val.length() - 2)
		return "$" + str_val + "M"
	elif amount >= 1_000:
		return "$" + str(amount / 1000) + "K"
	else:
		return "$" + str(amount)

extends Node

# ==========================================
# 1. MOVEMENT & CORE PHYSICS
# ==========================================
var base_thief_speed: float = 6.5
var cop_base_speed: float = 7.0
var hypno_thief_speed: float = 2.6
var thief_braking_friction: float = 6.5
var cop_braking_friction: float = 6.5

# ==========================================
# 2. STEALTH & CAMERA PERSPECTIVE
# ==========================================
var thief_camo_activation_time: float = 2.0
var thief_camo_transition_speed: float = 8.0 # Higher = faster fade
var cop_fov_angle: float = 90.0
var thief_spring_arm_length: float = 4.711 # (Your current X distance)

# ==========================================
# 3. ABILITIES & INTERACTION TIMERS
# ==========================================
var cop_charge_speed_boost: float = 1.5
var cop_charge_duration: float = 1.5
var cop_charge_cooldown: float = 4.0
var cop_charge_exhaustion_penalty: float = 0.6
var thief_rescue_time: float = 2.0

# ==========================================
# 4. ECONOMY & RADII
# ==========================================
var cash_small: int = 500
var cash_medium: int = 1500
var cash_large: int = 4000

var weight_small: float = 0.9
var weight_medium: float = 0.75
var weight_large: float = 0.5

var delivery_zone_radius: float = 5.0
var interact_shape_size: float = 2.0
var camera_wall_radius: float = 0.5

# ==========================================
# 5. MATCH STRUCTURE & SCALING
# ==========================================
# ==========================================
# 5. MATCH STRUCTURE & SCALING
# ==========================================
var min_players_for_2_cops: int = 5
var min_players_for_3_cops: int = 8

var quota_2p: int = 5000
var quota_3p: int = 10000
var quota_4p: int = 15000
var quota_5p: int = 15000 # (2nd Cop spawns here, so maybe quota stays flat!)
var quota_6p: int = 20000
var quota_7p: int = 25000
var quota_8p: int = 25000
var quota_9p: int = 30000
var quota_10p: int = 35000

var timer_2p: int = 180
var timer_3p: int = 200
var timer_4p: int = 220
var timer_5p: int = 240
var timer_6p: int = 260
var timer_7p: int = 280
var timer_8p: int = 300
var timer_9p: int = 320
var timer_10p: int = 340

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

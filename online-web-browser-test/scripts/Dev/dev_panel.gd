extends CanvasLayer

var panel: PanelContainer
var tabs: TabContainer
var balance_vbox: VBoxContainer
var teams_vbox: VBoxContainer
var preset_dropdown: OptionButton

func _ready():
	visible = false
	layer = 128 # FORCE IT ABOVE LOBBY UI (Lobby is 100)
	_build_ui()
	
	if GameManager:
		GameManager.lobby_updated.connect(_refresh_teams_tab)

func _input(event):
	# Press F12 to toggle the Dev Menu
	if event is InputEventKey and event.physical_keycode == KEY_F12 and event.pressed and not event.echo:
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			visible = !visible
			if visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_refresh_presets_dropdown()
				_refresh_teams_tab()
			else:
				# Safely recapture the mouse ONLY if the game has actually started!
				if GameManager and GameManager.current_state == GameManager.GameState.PLAYING:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_ui():
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP mouse clicks from passing through the background into the 3D world!
	control.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(control)
	
	panel = PanelContainer.new()
	# MAKE IT FULLSCREEN
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) 
	control.add_child(panel)
	
	tabs = TabContainer.new()
	# Add some margin so it doesn't hug the very edge of the screen
	tabs.add_theme_constant_override("margin_top", 10)
	tabs.add_theme_constant_override("margin_left", 10)
	tabs.add_theme_constant_override("margin_right", 10)
	tabs.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(tabs)
	
	_build_balance_tab()
	_build_teams_tab()
	_build_presets_tab()

# --- TAB 1: BALANCE SETTINGS ---
# --- TAB 1: BALANCE SETTINGS ---
func _build_balance_tab():
	var scroll = ScrollContainer.new()
	scroll.name = "Variables"
	tabs.add_child(scroll)
	
	balance_vbox = VBoxContainer.new()
	balance_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(balance_vbox)
	
	# Define our UI Categories based on execution time!
	var categories = {
		# --- LIVE TUNING (Takes effect instantly mid-match) ---
		"🟢 LIVE: Movement & Speeds": ["base_thief_speed", "cop_base_speed", "hypno_thief_speed", "thief_braking_friction", "cop_braking_friction"],
		"🟢 LIVE: Abilities & Timers": ["cop_charge_speed_boost", "cop_charge_duration", "cop_charge_cooldown", "cop_charge_exhaustion_penalty", "thief_rescue_time"],
		"🟢 LIVE: Stealth & Pings": ["thief_camo_activation_time", "thief_camo_transition_speed", "thief_spring_arm_length", "cam_laser_ping_cooldown_ms", "thief_map_ping_duration", "cop_spot_ping_duration"],

		# --- PRE-MATCH SETUP (Requires a new round) ---
		"🔴 SETUP: Radii & Collisions": ["delivery_zone_radius", "interact_shape_size", "camera_wall_radius", "cop_fov_angle"],
		"🔴 SETUP: Artifact Economy": ["cash_small", "cash_medium", "cash_large", "weight_small", "weight_medium", "weight_large"],
		"🔴 SETUP: Cop Thresholds": ["min_players_for_2_cops", "min_players_for_3_cops"],
		"🔴 SETUP: Match Quotas": ["quota_2p", "quota_3p", "quota_4p", "quota_5p", "quota_6p", "quota_7p", "quota_8p", "quota_9p", "quota_10p"],
		"🔴 SETUP: Match Timers": ["timer_2p", "timer_3p", "timer_4p", "timer_5p", "timer_6p", "timer_7p", "timer_8p", "timer_9p", "timer_10p"]
	}
	
	for category_name in categories.keys():
		# 1. Create a beautiful header for the category
		var header_bg = ColorRect.new()
		header_bg.color = Color(0.2, 0.2, 0.25, 1.0)
		header_bg.custom_minimum_size = Vector2(0, 30)
		
		var header_lbl = Label.new()
		header_lbl.text = "  " + category_name
		header_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		header_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_lbl.add_theme_font_size_override("font_size", 16)
		header_bg.add_child(header_lbl)
		
		balance_vbox.add_child(header_bg)
		
		# 2. Build the sliders for variables in this category
		for var_name in categories[category_name]:
			if var_name in Balance:
				var val = Balance.get(var_name)
				var is_float = typeof(val) == TYPE_FLOAT
				
				var hbox = HBoxContainer.new()
				
				var lbl = Label.new()
				# Clean up the variable name for the UI (e.g., "base_player_speed" -> "Base Player Speed")
				lbl.text = "    " + var_name.replace("_", " ").capitalize()
				lbl.custom_minimum_size = Vector2(300, 0)
				hbox.add_child(lbl)
				
				var spin = SpinBox.new()
				spin.min_value = 0.0
				spin.max_value = 99999.0
				if is_float:
					spin.step = 0.1
				spin.value = val
				
				spin.value_changed.connect(func(new_val):
					Balance.set(var_name, new_val)
					Balance.broadcast_balance_update()
				)
				hbox.add_child(spin)
				balance_vbox.add_child(hbox)
		
		# Add a little spacer between categories
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		balance_vbox.add_child(spacer)

# --- TAB 2: TEAM OVERRIDE ---
func _build_teams_tab():
	var scroll = ScrollContainer.new()
	scroll.name = "Force Teams"
	tabs.add_child(scroll)
	
	teams_vbox = VBoxContainer.new()
	teams_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(teams_vbox)

func _refresh_teams_tab():
	for child in teams_vbox.get_children():
		child.queue_free()
		
	for id in GameManager.players.keys():
		var p_name = GameManager.players[id]["name"]
		
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = p_name + " (" + str(id) + ")"
		lbl.custom_minimum_size = Vector2(300, 0)
		hbox.add_child(lbl)
		
		var opt = OptionButton.new()
		opt.add_item("Random")
		opt.add_item("Force Cop")
		opt.add_item("Force Thief")
		
		# Set the dropdown to whatever it was previously set to
		var current_force = GameManager.forced_teams.get(id, "random")
		if current_force == "cop": opt.selected = 1
		elif current_force == "thief": opt.selected = 2
		else: opt.selected = 0
		
		opt.item_selected.connect(func(index):
			var role_str = "random"
			if index == 1: role_str = "cop"
			elif index == 2: role_str = "thief"
			GameManager.set_player_force_role(id, role_str)
		)
		hbox.add_child(opt)
		teams_vbox.add_child(hbox)

# --- TAB 3: PRESETS & EXPORT ---
func _build_presets_tab():
	var margin = MarginContainer.new()
	margin.name = "Presets"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	tabs.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Load Area
	preset_dropdown = OptionButton.new()
	vbox.add_child(preset_dropdown)
	
	var load_btn = Button.new()
	load_btn.text = "Load Selected Preset"
	load_btn.pressed.connect(func():
		if preset_dropdown.item_count > 0:
			var preset_name = preset_dropdown.get_item_text(preset_dropdown.selected)
			Balance.apply_preset(preset_name)
			_refresh_balance_sliders() # Update the UI sliders to show the new values
	)
	vbox.add_child(load_btn)
	
	var hs = HSeparator.new()
	vbox.add_child(hs)
	
	# Save Area
	var save_input = LineEdit.new()
	save_input.placeholder_text = "New Preset Name"
	vbox.add_child(save_input)
	
	var save_btn = Button.new()
	save_btn.text = "Save Local Preset"
	save_btn.pressed.connect(func():
		var p_name = save_input.text.strip_edges()
		if p_name != "":
			Balance.save_custom_preset(p_name)
			save_input.text = ""
			_refresh_presets_dropdown()
	)
	vbox.add_child(save_btn)
	
	var hs2 = HSeparator.new()
	vbox.add_child(hs2)
	
	# Export Area
	var export_btn = Button.new()
	export_btn.text = "Export Current to Clipboard (For Devs)"
	export_btn.pressed.connect(func():
		var p_name = "Exported_" + str(Time.get_ticks_msec())
		if save_input.text.strip_edges() != "":
			p_name = save_input.text.strip_edges()
		Balance.export_to_clipboard(p_name)
	)
	vbox.add_child(export_btn)

func _refresh_presets_dropdown():
	preset_dropdown.clear()
	for p_name in Balance.saved_presets.keys():
		preset_dropdown.add_item(p_name)

func _refresh_balance_sliders():
	for hbox in balance_vbox.get_children():
		var lbl = hbox.get_child(0) as Label
		var spin = hbox.get_child(1) as SpinBox
		# Convert Label text back to variable name format (e.g. "Base Player Speed" -> "base_player_speed")
		var var_name = lbl.text.replace(" ", "_").to_lower()
		if var_name in Balance:
			spin.set_value_no_signal(Balance.get(var_name))

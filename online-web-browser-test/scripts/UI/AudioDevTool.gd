extends CanvasLayer

var ui_scale = 1.0
var test_dummy_pos: Vector3 = Vector3.INF

func _ready():
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	ui_scale = min(get_viewport().size.x / 1920.0, get_viewport().size.y / 1080.0)
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 50
	panel.offset_top = 50
	panel.offset_right = -50
	panel.offset_bottom = -50
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = "AUDIO DEVTOOL"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var dump_btn = Button.new()
	dump_btn.text = "SAVE CONFIG TO TXT"
	dump_btn.add_theme_color_override("font_color", Color.GREEN)
	dump_btn.pressed.connect(_dump_configs)
	header.add_child(dump_btn)
	
	var dummy_btn = Button.new()
	dummy_btn.text = "DROP 3D TEST DUMMY"
	dummy_btn.add_theme_color_override("font_color", Color.MAGENTA)
	dummy_btn.pressed.connect(_drop_dummy)
	header.add_child(dummy_btn)
	
	var close_btn = Button.new()
	close_btn.text = "CLOSE (F10)"
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	# --- SFX CONFIG ---
	var sfx_title = Label.new()
	sfx_title.text = "\n--- SFX SETTINGS ---"
	sfx_title.add_theme_color_override("font_color", Color.YELLOW)
	list.add_child(sfx_title)
	
	for sfx_name in AudioManager.SFX_CONFIG.keys():
		var entry_vbox = VBoxContainer.new()
		list.add_child(entry_vbox)
		
		var row = HBoxContainer.new()
		entry_vbox.add_child(row)
		
		var name_lbl = Label.new()
		name_lbl.text = sfx_name
		name_lbl.custom_minimum_size = Vector2(200, 0)
		row.add_child(name_lbl)
		
		# --- BUS LABEL ---
		var bus_lbl = Label.new()
		var bus_name = AudioManager.SFX_CONFIG[sfx_name].get("bus", "Master")
		bus_lbl.text = "[" + bus_name + "]"
		bus_lbl.modulate = Color(0.6, 0.8, 1.0)
		bus_lbl.custom_minimum_size = Vector2(90, 0)
		row.add_child(bus_lbl)
		
		var play_btn = Button.new()
		play_btn.text = " Play "
		play_btn.pressed.connect(func(): 
			var is_3d = AudioManager.SFX_CONFIG[sfx_name].has("max_distance")
			if is_3d:
				var p = get_local_player()
				if p != null:
					var spawn_pos = p.global_position
					if test_dummy_pos != Vector3.INF:
						spawn_pos = test_dummy_pos
					AudioManager.play_3d_sfx(sfx_name, spawn_pos)
			else:
				AudioManager.play_2d_sfx(sfx_name)
		)
		row.add_child(play_btn)
		
		var mute_check = CheckBox.new()
		mute_check.text = "Mute"
		mute_check.button_pressed = AudioManager.SFX_CONFIG[sfx_name].get("disabled", false)
		mute_check.toggled.connect(func(t): AudioManager.SFX_CONFIG[sfx_name]["disabled"] = t)
		row.add_child(mute_check)
		
		var vol_lbl = Label.new()
		vol_lbl.text = "  Vol:"
		row.add_child(vol_lbl)
		
		var vol_val = SpinBox.new()
		var start_vol = AudioManager.SFX_CONFIG[sfx_name].get("volume", 0.0)
		vol_val.min_value = -80.0
		vol_val.max_value = 24.0
		vol_val.step = 0.5
		vol_val.value = start_vol
		vol_val.suffix = " dB"
		vol_val.custom_minimum_size = Vector2(80, 0)
		row.add_child(vol_val)
		
		var vol_slider = HSlider.new()
		vol_slider.min_value = -80.0
		vol_slider.max_value = 24.0
		vol_slider.step = 0.5
		vol_slider.value = start_vol
		vol_slider.custom_minimum_size = Vector2(150, 0)
		vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vol_slider.value_changed.connect(func(v): 
			AudioManager.SFX_CONFIG[sfx_name]["volume"] = v
			vol_val.set_value_no_signal(v)
		)
		vol_val.value_changed.connect(func(v):
			AudioManager.SFX_CONFIG[sfx_name]["volume"] = v
			vol_slider.set_value_no_signal(v)
		)
		row.add_child(vol_slider)
		
		var pitch_lbl = Label.new()
		pitch_lbl.text = "  Pitch:"
		row.add_child(pitch_lbl)
		
		var pitch_val = SpinBox.new()
		var start_pitch = AudioManager.SFX_CONFIG[sfx_name].get("pitch_override", 1.0)
		pitch_val.min_value = 0.1
		pitch_val.max_value = 3.0
		pitch_val.step = 0.05
		pitch_val.value = start_pitch
		pitch_val.suffix = "x"
		pitch_val.custom_minimum_size = Vector2(80, 0)
		row.add_child(pitch_val)
		
		var pitch_slider = HSlider.new()
		pitch_slider.min_value = 0.1
		pitch_slider.max_value = 3.0
		pitch_slider.step = 0.05
		pitch_slider.value = start_pitch
		pitch_slider.custom_minimum_size = Vector2(150, 0)
		pitch_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pitch_slider.value_changed.connect(func(v): 
			AudioManager.SFX_CONFIG[sfx_name]["pitch_override"] = v
			pitch_val.set_value_no_signal(v)
		)
		pitch_val.value_changed.connect(func(v):
			AudioManager.SFX_CONFIG[sfx_name]["pitch_override"] = v
			pitch_slider.set_value_no_signal(v)
		)
		row.add_child(pitch_slider)
		
		# 3D Settings if applicable
		if AudioManager.SFX_CONFIG[sfx_name].has("max_distance"):
			var row2 = HBoxContainer.new()
			entry_vbox.add_child(row2)
			
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(250, 0)
			row2.add_child(spacer)
			
			var max_dist_lbl = Label.new()
			max_dist_lbl.text = " MaxDist:"
			row2.add_child(max_dist_lbl)
			
			var max_dist_val = SpinBox.new()
			var start_dist = AudioManager.SFX_CONFIG[sfx_name].get("max_distance", 30.0)
			max_dist_val.min_value = 1.0
			max_dist_val.max_value = 500.0
			max_dist_val.step = 1.0
			max_dist_val.value = start_dist
			max_dist_val.suffix = " m"
			max_dist_val.custom_minimum_size = Vector2(80, 0)
			row2.add_child(max_dist_val)
			
			var dist_slider = HSlider.new()
			dist_slider.min_value = 1.0
			dist_slider.max_value = 500.0
			dist_slider.step = 1.0
			dist_slider.value = start_dist
			dist_slider.custom_minimum_size = Vector2(100, 0)
			dist_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dist_slider.value_changed.connect(func(v): 
				AudioManager.SFX_CONFIG[sfx_name]["max_distance"] = v
				max_dist_val.set_value_no_signal(v)
			)
			max_dist_val.value_changed.connect(func(v):
				AudioManager.SFX_CONFIG[sfx_name]["max_distance"] = v
				dist_slider.set_value_no_signal(v)
			)
			row2.add_child(dist_slider)

			var unit_lbl = Label.new()
			unit_lbl.text = " UnitSize:"
			row2.add_child(unit_lbl)

			var unit_val = SpinBox.new()
			var start_unit = AudioManager.SFX_CONFIG[sfx_name].get("unit_size", 1.0)
			unit_val.min_value = 0.1
			unit_val.max_value = 500.0
			unit_val.step = 0.1
			unit_val.value = start_unit
			unit_val.custom_minimum_size = Vector2(80, 0)
			row2.add_child(unit_val)

			var unit_slider = HSlider.new()
			unit_slider.min_value = 0.1
			unit_slider.max_value = 500.0
			unit_slider.step = 0.1
			unit_slider.value = start_unit
			unit_slider.custom_minimum_size = Vector2(100, 0)
			unit_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			unit_slider.value_changed.connect(func(v): 
				AudioManager.SFX_CONFIG[sfx_name]["unit_size"] = v
				unit_val.set_value_no_signal(v)
			)
			unit_val.value_changed.connect(func(v):
				AudioManager.SFX_CONFIG[sfx_name]["unit_size"] = v
				unit_slider.set_value_no_signal(v)
			)
			row2.add_child(unit_slider)
			
			var att_lbl = Label.new()
			att_lbl.text = " Atten:"
			row2.add_child(att_lbl)
			
			var att_opt = OptionButton.new()
			att_opt.add_item("Inverse")
			att_opt.add_item("Logarithmic")
			att_opt.add_item("Inverse Square")
			att_opt.add_item("Disabled")
			var model = AudioManager.SFX_CONFIG[sfx_name].get("attenuation_model", AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC)
			var idx = 1 
			if model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE: idx = 0
			elif model == AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE: idx = 2
			elif model == AudioStreamPlayer3D.ATTENUATION_DISABLED: idx = 3
			att_opt.selected = idx
			att_opt.item_selected.connect(func(i):
				var m = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
				if i == 0: m = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
				elif i == 2: m = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
				elif i == 3: m = AudioStreamPlayer3D.ATTENUATION_DISABLED
				AudioManager.SFX_CONFIG[sfx_name]["attenuation_model"] = m
			)
			row2.add_child(att_opt)
		
	# --- MUSIC CONFIG ---
	var music_title = Label.new()
	music_title.text = "\n--- MUSIC SETTINGS ---"
	music_title.add_theme_color_override("font_color", Color.CYAN)
	list.add_child(music_title)
	
	for music_name in AudioManager.MUSIC_CONFIG.keys():
		var row = HBoxContainer.new()
		list.add_child(row)
		
		var name_lbl = Label.new()
		name_lbl.text = music_name
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)
		
		# --- BUS LABEL ---
		var bus_lbl = Label.new()
		var bus_name = AudioManager.MUSIC_CONFIG[music_name].get("bus", "Master")
		bus_lbl.text = "[" + bus_name + "]"
		bus_lbl.modulate = Color(0.6, 0.8, 1.0)
		bus_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(bus_lbl)
		
		var play_btn = Button.new()
		play_btn.text = " Fade In "
		play_btn.pressed.connect(func(): AudioManager.play_music(music_name))
		row.add_child(play_btn)
		
		var stop_btn = Button.new()
		stop_btn.text = " Stop "
		stop_btn.pressed.connect(func(): AudioManager.stop_music())
		row.add_child(stop_btn)
		
		var vol_lbl = Label.new()
		vol_lbl.text = "  Base Vol:"
		row.add_child(vol_lbl)
		
		var vol_val = SpinBox.new()
		var start_vol = AudioManager.MUSIC_CONFIG[music_name].get("volume", 0.0)
		vol_val.min_value = -80.0
		vol_val.max_value = 24.0
		vol_val.step = 0.5
		vol_val.value = start_vol
		vol_val.suffix = " dB"
		vol_val.custom_minimum_size = Vector2(80, 0)
		row.add_child(vol_val)
		
		var vol_slider = HSlider.new()
		vol_slider.min_value = -80.0
		vol_slider.max_value = 24.0
		vol_slider.step = 0.5
		vol_slider.value = start_vol
		vol_slider.custom_minimum_size = Vector2(150, 0)
		vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var update_music_vol = func(v):
			AudioManager.MUSIC_CONFIG[music_name]["volume"] = v
			if AudioManager.current_music_track == music_name:
				var player = AudioManager.music_player_a if AudioManager.active_music_player == 1 else AudioManager.music_player_b
				player.volume_db = v
		
		vol_slider.value_changed.connect(func(v): 
			update_music_vol.call(v)
			vol_val.set_value_no_signal(v)
		)
		vol_val.value_changed.connect(func(v):
			update_music_vol.call(v)
			vol_slider.set_value_no_signal(v)
		)
		row.add_child(vol_slider)
		

		
		# Fade Duration
		var fade_lbl = Label.new()
		fade_lbl.text = " Fade:"
		row.add_child(fade_lbl)
		
		var fade_val = Label.new()
		var start_fade = AudioManager.MUSIC_CONFIG[music_name].get("fade_duration", 2.0)
		fade_val.text = "%4.1f s" % start_fade
		fade_val.custom_minimum_size = Vector2(60, 0)
		row.add_child(fade_val)
		
		var fade_slider = HSlider.new()
		fade_slider.min_value = 0.0
		fade_slider.max_value = 10.0
		fade_slider.step = 0.1
		fade_slider.value = start_fade
		fade_slider.custom_minimum_size = Vector2(100, 0)
		fade_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fade_slider.value_changed.connect(func(v): 
			AudioManager.MUSIC_CONFIG[music_name]["fade_duration"] = v
			fade_val.text = "%4.1f s" % v
		)
		row.add_child(fade_slider)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		queue_free()
		get_viewport().set_input_as_handled()

func _dump_configs():
	var file = FileAccess.open("res://audio_config_dump.txt", FileAccess.WRITE)
	if not file:
		print("Failed to open dump file.")
		return
	
	file.store_line("var SFX_CONFIG = {")
	for key in AudioManager.SFX_CONFIG.keys():
		file.store_line("\t\"%s\": %s," % [key, var_to_str(AudioManager.SFX_CONFIG[key])])
	file.store_line("}")
	file.store_line("\nvar MUSIC_CONFIG = {")
	for key in AudioManager.MUSIC_CONFIG.keys():
		file.store_line("\t\"%s\": %s," % [key, var_to_str(AudioManager.MUSIC_CONFIG[key])])
	file.store_line("}")
	file.close()
	print("--- SUCCESS ---")
	print("Saved audio configs directly to res://audio_config_dump.txt !")

func _drop_dummy():
	var p = get_local_player()
	if not p: return
	test_dummy_pos = p.global_position
	
	var old_marker = get_tree().get_root().get_node_or_null("AudioTestDummyMarker")
	if old_marker: old_marker.queue_free()
	
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 2.0, 0.5)
	mesh_inst.mesh = box
	mesh_inst.name = "AudioTestDummyMarker"
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.MAGENTA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	
	get_tree().get_root().add_child(mesh_inst)
	mesh_inst.global_position = test_dummy_pos
	print("Dropped Audio Test Dummy at ", test_dummy_pos)

func get_local_player() -> Node3D:
	if not multiplayer.has_multiplayer_peer(): return null
	var spawned = get_tree().get_root().find_child("SpawnedObjects", true, false)
	if spawned:
		return spawned.get_node_or_null(str(multiplayer.get_unique_id()))
	return null

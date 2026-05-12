extends "res://scripts/player.gd"

var is_charging = false
var charge_time_left = 0.0
var charge_cooldown_left = 0.0
const CHARGE_DURATION = 0.4
const CHARGE_SPEED = 20.0
const CHARGE_COOLDOWN = 3.0
var charge_direction = Vector3.ZERO
var charge_ui_ref: Control

func _ready():
	super._ready()
	if is_multiplayer_authority():
		# Cop uses first-person camera
		if spring_arm:
			spring_arm.spring_length = 0.0
		if has_node("MeshInstance3D"):
			$MeshInstance3D.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			
		# Wait one frame for PlayerCanvas to be created by base class
		await get_tree().process_frame
		var canvas = get_node_or_null("PlayerCanvas")
		if canvas:
			var charge_ui = Control.new()
			charge_ui.set_script(preload("res://scripts/dash_ui.gd"))
			charge_ui.ring_color = Color(0.2, 0.4, 1.0, 0.9)
			charge_ui.ready_color = Color(0.2, 0.4, 1.0, 0.9)
			charge_ui.custom_minimum_size = Vector2(40, 40)
			charge_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			charge_ui.position.x -= 60
			charge_ui.position.y -= 80
			charge_ui.name = "ChargeUI"
			charge_ui_ref = charge_ui
			canvas.add_child(charge_ui)

func _add_custom_mobile_ui(mobile_ui: Control, ui_scale: float):
	var charge_btn = load("res://scripts/mobile_button.gd").new()
	charge_btn.action_name = "dash" # Map to dash action
	charge_btn.button_text = "CHARGE"
	charge_btn.radius = 60.0 * ui_scale
	charge_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	charge_btn.offset_left = - (130 * ui_scale)
	charge_btn.offset_top = - (300 * ui_scale)
	charge_btn.offset_right = - (30 * ui_scale)
	charge_btn.offset_bottom = - (200 * ui_scale)
	mobile_ui.add_child(charge_btn)
	
	if charge_ui_ref:
		charge_ui_ref.reparent(charge_btn, false)
		charge_ui_ref.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _custom_physics_process(delta, direction):
	if charge_cooldown_left > 0:
		charge_cooldown_left -= delta
		
	if charge_ui_ref:
		if CHARGE_COOLDOWN > 0:
			charge_ui_ref.progress = clamp(1.0 - (charge_cooldown_left / CHARGE_COOLDOWN), 0.0, 1.0)
			
	if is_charging:
		charge_time_left -= delta
		if charge_time_left <= 0:
			is_charging = false
		else:
			velocity.x = charge_direction.x * CHARGE_SPEED
			velocity.z = charge_direction.z * CHARGE_SPEED
			_detect_capture()
			return

	if (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("dash")) and charge_cooldown_left <= 0:
		is_charging = true
		charge_time_left = CHARGE_DURATION
		charge_cooldown_left = CHARGE_COOLDOWN
		if direction != Vector3.ZERO:
			charge_direction = direction
		else:
			charge_direction = -camera.global_transform.basis.z.normalized()
			charge_direction.y = 0
			charge_direction = charge_direction.normalized()
			
	if not is_charging:
		super._custom_physics_process(delta, direction)

func _detect_capture():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		# Make sure it's a player, has the method, and is on the enemy team (team_index 0 is Thief)
		if collider is CharacterBody3D and collider.has_method("on_captured") and collider.get("team_index") != team_index:
			rpc_id(1, "request_capture", int(str(collider.name)))
			is_charging = false
			return

@rpc("any_peer", "call_local")
func request_capture(thief_id: int):
	if not multiplayer.is_server(): return
	
	# Host validates: check if the thief exists and is not already hypnotized
	var spawned = get_node_or_null("/root/World/main/SpawnedObjects")
	if not spawned: return
	
	var thief = spawned.get_node_or_null(str(thief_id))
	if thief and thief.has_method("on_captured"):
		# Validate distance to prevent latency cheating
		if global_position.distance_to(thief.global_position) < 4.0:
			thief.rpc("on_captured")

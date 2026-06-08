extends Area3D
class_name VentZone

@export var vent_radius: float = 1.5

var is_open: bool = false
@onready var visual_ring: Node3D = $VisualRing
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	GameManager.register_vent(self)
	
	_setup_visuals()
	
func _setup_visuals():
	var col = get_node_or_null("CollisionShape3D")
	if col and col.shape is CylinderShape3D:
		var scale_factor = col.global_transform.basis.get_scale().x
		if scale_factor > 0.0:
			col.shape.radius = vent_radius / scale_factor
		else:
			col.shape.radius = vent_radius
	
	if visual_ring:
		if visual_ring is DottedRing:
			visual_ring.radius = vent_radius
			visual_ring.set_alpha(0.0 if not is_open else visual_ring.max_alpha)
		elif visual_ring is MeshInstance3D:
			var scale_factor = visual_ring.global_transform.basis.get_scale().x
			var fixed_radius = vent_radius
			if scale_factor > 0.0:
				fixed_radius = vent_radius / scale_factor
				
			var mesh = visual_ring.mesh as CylinderMesh
			if mesh:
				mesh.top_radius = fixed_radius
				mesh.bottom_radius = fixed_radius
			
			var mat = visual_ring.get_surface_override_material(0)
			if mat:
				mat.albedo_color.a = 0.0 if not is_open else 0.5
		visual_ring.visible = is_open

func balance_radius_updated(new_radius: float):
	vent_radius = new_radius
	_setup_visuals()

@rpc("call_local", "reliable")
func open_vent():
	is_open = true
	if visual_ring:
		visual_ring.visible = true
		if visual_ring is DottedRing:
			visual_ring.fade_in(0.5)
	if animation_player.has_animation("open"):
		animation_player.play("open")

@rpc("call_local", "reliable")
func close_vent():
	is_open = false
	if visual_ring and visual_ring is DottedRing:
		visual_ring.set_alpha(0.0)
	if animation_player.has_animation("close"):
		animation_player.play("close")
	# visual_ring visibility will be toggled off at the end of the close animation

func _physics_process(delta):
	if not is_open:
		return
		
	# FIX: Make sure the multiplayer peer actually exists before checking is_server()
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or not multiplayer.is_server(): 
		return
	
	# Continuously scan for any body currently standing inside the vent zone
	for body in get_overlapping_bodies():
		if body is CharacterBody3D and body.get("team_index") == 0: # 0 is Thief
			if body.has_method("get_carried_artifact"):
				var artifact = body.get_carried_artifact()
				
				# If they are holding an artifact, cash it in instantly!
				if artifact and not artifact.is_queued_for_deletion():
					if "cash_contributed" in body:
						body.cash_contributed += artifact.cash_value
					
					GameManager.rpc("add_cash", artifact.cash_value)
					
					# Safely clear the Thief's hands before destroying the artifact
					body.set("carried_artifact", null)
					artifact.rpc("destroy_artifact")
					
					# Tell the Server to cycle to a new vent!
					GameManager.cycle_vent(name)

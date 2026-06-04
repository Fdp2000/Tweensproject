extends Area3D

func _ready():
	_update_sizes()
	if not Balance.balance_updated.is_connected(_update_sizes):
		Balance.balance_updated.connect(_update_sizes)

func _update_sizes():
	# Find the collision shape and apply the Balance radius
	var col = get_node_or_null("CollisionShape3D")
	if col and col.shape:
		# If it's a Sphere or Cylinder, update the radius
		if col.shape is SphereShape3D or col.shape is CylinderShape3D:
			var scale_factor = col.global_transform.basis.get_scale().x
			if scale_factor > 0.0:
				col.shape.radius = Balance.delivery_zone_radius / scale_factor
			else:
				col.shape.radius = Balance.delivery_zone_radius
		# If it's a Box, update the X and Z size (keeping Y height the same)
		elif col.shape is BoxShape3D:
			col.shape.size.x = Balance.delivery_zone_radius * 2.0
			col.shape.size.z = Balance.delivery_zone_radius * 2.0

	var ring = get_node_or_null("VisualRing")
	if ring and ring is CSGTorus3D:
		ring.scale = Vector3.ONE # Reset any editor scaling so the radius perfectly matches
		ring.outer_radius = Balance.delivery_zone_radius
		ring.inner_radius = Balance.delivery_zone_radius - 0.1
	elif ring is DottedRing:
		ring.radius = Balance.delivery_zone_radius

func _physics_process(delta):
	# FIX: Make sure the multiplayer peer actually exists before checking is_server()
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or not multiplayer.is_server(): 
		return
	
	# Continuously scan for any body currently standing inside the van zone
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

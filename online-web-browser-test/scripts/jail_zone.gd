extends Area3D

@onready var cell_center = $Marker3D

func _on_body_entered(body: Node3D):
	if not multiplayer.is_server(): return
	
	if body is CharacterBody3D and body.get("team_index") == 0:
		if body.get("is_hypnotized") and not body.get("is_jailed"):
			# Lock them up!
			body.rpc("on_jailed", cell_center.global_position)

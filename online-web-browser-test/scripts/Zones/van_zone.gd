extends Area3D

func _on_body_entered(body: Node3D):
	if not multiplayer.is_server(): return
	
	if body is CharacterBody3D and body.get("team_index") == 0: # 0 is Thief
		if body.has_method("get_carried_artifact"):
			var artifact = body.get_carried_artifact()
			if artifact:
				GameManager.rpc("add_cash", artifact.cash_value)
				
				if "cash_contributed" in body:
					body.cash_contributed += artifact.cash_value
				
				# Destroy artifact across all peers to prevent sync errors
				artifact.rpc("destroy_artifact")
				body.set("carried_artifact", null)

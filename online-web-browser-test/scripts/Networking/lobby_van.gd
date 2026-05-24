extends Area3D

var artifact_category = 0 # To prevent errors from interact logic if it checks
var is_carried = false

func _ready():
	add_to_group("artifact")
	
@rpc("any_peer", "call_local")
func request_pickup(requester_id: int):
	if multiplayer.is_server():
		# Only host can start game
		if requester_id == 1:
			if GameManager.current_state == GameManager.GameState.LOBBY:
				print("Host interacted with Van! Starting game...")
				GameManager.host_start_game()
			else:
				print("Game already started!")
		else:
			print("Only the host can start the game!")

@rpc("any_peer", "call_local")
func drop():
	pass

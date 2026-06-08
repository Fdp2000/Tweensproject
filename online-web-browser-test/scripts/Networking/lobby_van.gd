extends Area3D

var artifact_category = 0 # To prevent errors from interact logic if it checks
var is_carried = false
@export var outline_size: float = 4.0

var is_highlighted: bool = false:
	set(value):
		if is_highlighted != value:
			is_highlighted = value
			set_highlight(value)

var outline_mat: ShaderMaterial = null

func _ready():
	add_to_group("artifact")
	
func set_highlight(highlighted: bool):
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return # Only the host can interact with the Van
		
	var target = get_parent()
	if target == get_tree().get_root() or target.name == "PregameLobby" or target.name == "World":
		target = self
	_apply_visuals(target, highlighted)

func _apply_visuals(node: Node, highlighted: bool):
	if not outline_mat:
		outline_mat = ShaderMaterial.new()
		outline_mat.shader = preload("res://Assets/Shaders/HighlightShader/newOutline.gdshader")
		outline_mat.set_shader_parameter("outline_color", Color(1, 1, 1, 1))
		outline_mat.set_shader_parameter("outline_width", outline_size)
			
	if node is MeshInstance3D:
		if highlighted:
			node.material_overlay = outline_mat
		else:
			if node.material_overlay == outline_mat:
				node.material_overlay = null
					
	for child in node.get_children():
		if child == self: continue
		if child is Area3D: continue # Skip other interaction areas
		_apply_visuals(child, highlighted)
	
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

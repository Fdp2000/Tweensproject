extends Area3D

var artifact_category = 0 # To prevent errors from interact logic
var is_carried = false
@export var outline_size: float = 4.0
@export var custom_interact_radius: float = 5.0

var is_highlighted: bool = false:
	set(value):
		if is_highlighted != value:
			is_highlighted = value
			set_highlight(value)

var outline_mat: ShaderMaterial = null

func _ready():
	add_to_group("artifact")

func set_highlight(highlighted: bool):
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
		if child is Area3D: continue
		_apply_visuals(child, highlighted)
	
@rpc("any_peer", "call_local")
func request_pickup(requester_id: int):
	if multiplayer.is_server():
		rpc_id(requester_id, "execute_leave")

@rpc("any_peer", "call_local")
func drop():
	pass

@rpc("authority", "call_local")
func execute_leave():
	var client_ui = get_tree().get_root().find_child("ClientUI", true, false)
	if client_ui:
		if client_ui.client.rtc_mp:
			client_ui.client.rtc_mp.close()
		client_ui.client.stop()
		client_ui._disconnected()

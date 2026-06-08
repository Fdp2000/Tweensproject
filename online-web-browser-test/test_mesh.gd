@tool
extends SceneTree

func _init():
	var arr_mesh = ArrayMesh.new()
	print("Has surface_set_material? ", arr_mesh.has_method("surface_set_material"))
	var box = BoxMesh.new()
	print("BoxMesh has surface_set_material? ", box.has_method("surface_set_material"))
	quit()

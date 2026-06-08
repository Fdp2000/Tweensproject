@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("Please open PrototypeLevel.tscn!")
		return
		
	var restored_count = 0
	restored_count = _restore_recursive(root, restored_count)
	
	print("--------------------------------------------------")
	print("✅ AUTO-OCCLUSION RESTORE COMPLETE")
	print("Unhid %d meshes successfully! The level is back to normal." % restored_count)
	print("--------------------------------------------------")

func _restore_recursive(node: Node, count: int) -> int:
	if node.has_meta("auto_occlude_hidden"):
		node.visible = true
		node.remove_meta("auto_occlude_hidden")
		count += 1
		
	for child in node.get_children():
		count = _restore_recursive(child, count)
		
	return count

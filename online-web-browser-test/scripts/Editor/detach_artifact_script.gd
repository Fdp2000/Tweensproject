@tool
extends EditorScript

## HOW TO RUN:
## 1. Have your scene open in your 2D/3D viewport
## 2. Open this script in the Script editor
## 3. Go to File -> Run (or press Ctrl+Shift+X)

const ARTIFACT_SCRIPT_PATH = "res://scripts/Zones/artifact.gd"

func _run():
	var root = get_scene()
	if root == null:
		print("ERROR: Please open a scene and make it your active scene before running this script.")
		return
		
	var target_script = load(ARTIFACT_SCRIPT_PATH)
	if target_script == null:
		print("ERROR: Could not load script at " + ARTIFACT_SCRIPT_PATH)
		return
		
	print("--- STARTING SCRIPT DETACHMENT FOR: " + root.name + " ---")
	
	var detached_count = 0
	
	# Recursive function to find and detach the script
	var detach_scripts = func(node: Node, self_ref: Callable):
		# Check if the node has the specific script attached
		if node.get_script() == target_script:
			node.set_script(null)
			detached_count += 1
			
		# Continue searching down the tree
		for child in node.get_children():
			self_ref.call(child, self_ref)
			
	# Start the recursion from the root node
	detach_scripts.call(root, detach_scripts)
	
	print("SUCCESS! Detached 'artifact.gd' from " + str(detached_count) + " nodes.")
	print("--- Please save your scene (Ctrl+S) ---")

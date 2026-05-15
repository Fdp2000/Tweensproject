extends Node3D
## Attach this script to the PrototypeLevel root node.
## DEPRECATED: Runtime generation was causing massive load times.
## Collisions are now expected to be generated manually in the Editor.

func _ready():
	# Removed runtime collision generation to fix load times.
	pass

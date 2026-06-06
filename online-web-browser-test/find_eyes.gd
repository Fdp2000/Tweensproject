extends Node3D

func _ready():
	var eye_l = find_child("Eye_L", true, false)
	var eye_r = find_child("Eye_R", true, false)
	
	if eye_l and eye_l.mesh:
		var aabb = eye_l.mesh.get_aabb()
		var center = aabb.position + aabb.size / 2.0
		print("--- COPY THESE NUMBERS ---")
		print("Eye_L Pivot Position: ", center)
		
	if eye_r and eye_r.mesh:
		var aabb = eye_r.mesh.get_aabb()
		var center = aabb.position + aabb.size / 2.0
		print("Eye_R Pivot Position: ", center)
		print("--------------------------")

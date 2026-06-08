extends Node3D

const HEAVY_MATERIALS = [
	preload("res://Assets/Shaders/CamoShader/camoMaterial.tres"),
	preload("res://Assets/Shaders/celShader/celMaterial.tres"),
	preload("res://Assets/Shaders/celShader/goldCel.tres"),
	preload("res://Assets/Shaders/celShader/museumCel.tres"),
	preload("res://Assets/Shaders/HighlightShader/OutlineMat.tres"),
	preload("res://Assets/Shaders/HypnoShader/hypnoMat.tres"),
	preload("res://Assets/Shaders/HypnoShader/SolidhypnoMat.tres")
]

const HEAVY_PARTICLES = [
	preload("res://Assets/Particles/artifact_particles.tscn"),
	preload("res://Assets/Particles/smoke_particles.tscn"),
	preload("res://Assets/Particles/smoke_particles_captured.tscn"),
	preload("res://Assets/Particles/smoke_particles_Charge.tscn")
]

func _ready():
	# 1. Spawn a basic box mesh
	var box_mesh = BoxMesh.new()
	
	# 2. Attach every heavy material to a new instance of the box
	for mat in HEAVY_MATERIALS:
		if mat:
			var mi = MeshInstance3D.new()
			mi.mesh = box_mesh
			mi.material_override = mat
			# Position it 2 meters directly in front of the camera
			mi.position = Vector3(0, 0, -2.0) 
			add_child(mi)
			
	# 3. Spawn and trigger all particle systems
	for p_scene in HEAVY_PARTICLES:
		if p_scene:
			var p_instance = p_scene.instantiate()
			p_instance.position = Vector3(0, 0, -2.0)
			add_child(p_instance)
			
			# Force emission on the root or any child particle nodes
			if p_instance.has_method("set_emitting"):
				p_instance.emitting = true
				
			for child in p_instance.find_children("*", "GPUParticles3D", true, false):
				child.emitting = true
			for child in p_instance.find_children("*", "CPUParticles3D", true, false):
				child.emitting = true

	# 4. Wait exactly 3 frames to guarantee WebGL processes the render pass
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 5. The shaders are now fully cached in the browser! Delete the evidence.
	queue_free()

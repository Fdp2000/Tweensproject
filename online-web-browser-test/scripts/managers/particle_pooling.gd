extends Node3D

const ARTIFACT_PARTICLES = preload("uid://b4hha0q7y1chb")
const SMOKE_PARTICLES = preload("uid://8iaw24ps07vh")


func _ready() -> void:
	# Instantiating The Different Particles
	var shine_instance = ARTIFACT_PARTICLES.instantiate()
	var smoke_instance = SMOKE_PARTICLES.instantiate()
	
	# Add Particles Instance Node
	self.get_node("instantiatedParticles").add_child(shine_instance)
	self.get_node("instantiatedParticles").add_child(smoke_instance)
	
	# Emit Particles
	shine_instance.emitting = true
	smoke_instance.emitting = true
	
	
	# Wait For Timer, Then Delete Particles Again
	await get_tree().create_timer(5.0).timeout
	get_node("instantiatedParticles").queue_free()

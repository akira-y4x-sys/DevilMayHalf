extends Node3D

@onready var particles = $GPUParticles3D

func _ready():
	particles.restart()
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
	

extends Node3D

@onready var debris: GPUParticles3D = $Debris
@onready var fire: GPUParticles3D = $Fire
@onready var explosion_sound: AudioStreamPlayer3D = $ExplosionSound

func explode():
	# trigger particles
	debris.emitting = true
	fire.emitting   = true

	# play sound
	explosion_sound.play()

	# wait for the longest particle lifetime before cleaning up
	# use the sound length if it's longer
	var wait_time = max(debris.lifetime, fire.lifetime)
	await get_tree().create_timer(wait_time).timeout
	queue_free()
	

extends RigidBody3D

@export var explosion_delay  := 2.0
@export var explosion_damage := 25
@export var explosion_radius := 6.0   # must match Area3D sphere radius
@export var knockback_force  := 12.0  # how hard it pushes bodies away

@onready var explosion_area  = $Area3D

var can_explode := false
var thrower     = null


func _ready():
	await get_tree().create_timer(0.2).timeout
	can_explode = true
	await get_tree().create_timer(explosion_delay).timeout
	explode()

func set_velocity(v: Vector3):
	linear_velocity = v

func _on_area_3d_body_entered(body):
	if not can_explode:
		return
	if body == thrower:
		return
	explode()


# ─── EXPLOSION ───────────────────────────────────

func explode():
	can_explode = false

	var origin = global_transform.origin

	# damage + knockback all bodies in range
	for body in explosion_area.get_overlapping_bodies():
		if body == thrower:
			continue

		var to_body  = body.global_transform.origin - origin
		var distance = to_body.length()

		# falloff: full damage at center, zero at edge
		var falloff  = clamp(1.0 - (distance / explosion_radius), 0.0, 1.0)
		var damage   = int(explosion_damage * falloff)

		if body.has_method("take_damage") and damage > 0:
			body.take_damage(damage)

		# knockback — push body away from explosion
		if body is RigidBody3D:
			body.apply_central_impulse(to_body.normalized() * knockback_force * falloff)
		elif body is CharacterBody3D and body.has_method("get"):
			# for CharacterBody3D (player, enemies) add velocity directly
			if "velocity" in body:
				body.velocity += to_body.normalized() * knockback_force * falloff

	# visual flash — OmniLight that fades out quickly
	spawn_flash(origin)

	# particle burst
	spawn_particles(origin)

	queue_free()


func spawn_flash(pos: Vector3):
	var light           = OmniLight3D.new()
	get_tree().root.add_child(light)
	light.global_transform.origin = pos
	light.light_color             = Color(1.0, 0.6, 0.2)
	light.light_energy            = 8.0
	light.omni_range              = explosion_radius * 2.0

	# fade out over 0.3 seconds
	var tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)


func spawn_particles(pos: Vector3):
	var particles = CPUParticles3D.new()
	get_tree().root.add_child(particles)
	particles.global_transform.origin = pos

	particles.amount               = 24
	particles.one_shot             = true
	particles.explosiveness        = 1.0
	particles.lifetime             = 0.6
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 14.0
	particles.gravity              = Vector3(0, -4.0, 0)
	particles.spread               = 180.0
	particles.flatness             = 0.0
	particles.scale_amount_min     = 0.1
	particles.scale_amount_max     = 0.25
	particles.color                = Color(1.0, 0.5, 0.1, 1.0)

	particles.emitting = true

	get_tree().create_timer(1.0).timeout.connect(func():
		particles.queue_free()
	)
	

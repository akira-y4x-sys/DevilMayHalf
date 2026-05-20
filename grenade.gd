extends RigidBody3D

@export var explosion_delay  := 2.0
@export var explosion_damage := 25
@export var explosion_radius := 6.0
@export var knockback_force  := 12.0
@export var explosion_scene: PackedScene

@onready var explosion_area = $Area3D

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
	var origin  = global_transform.origin
	
	# damage + knockback (unchanged)
	for body in explosion_area.get_overlapping_bodies():
		if body == thrower:
			continue
		var to_body  = body.global_transform.origin - origin
		var distance = to_body.length()
		var falloff  = clamp(1.0 - (distance / explosion_radius), 0.0, 1.0)
		var damage   = int(explosion_damage * falloff)
		if body.has_method("take_damage") and damage > 0:
			body.take_damage(damage)
		if body is RigidBody3D:
			body.apply_central_impulse(to_body.normalized() * knockback_force * falloff)
		elif "velocity" in body:
			body.velocity += to_body.normalized() * knockback_force * falloff
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_tree().root.add_child(explosion)
		explosion.global_transform.origin = origin
		await get_tree().process_frame
		explosion.explode()
		for child in explosion.get_children():
			if child is GPUParticles3D:
				child.emitting = true

	spawn_flash(origin)
	spawn_fireball(origin)
	spawn_sparks(origin)
	spawn_smoke(origin)
	queue_free()

# ─── FLASH ───────────────────────────────────────

func spawn_flash(pos: Vector3):
	var light                     = OmniLight3D.new()
	get_tree().root.add_child(light)
	light.global_transform.origin = pos
	light.light_color             = Color(1.0, 0.7, 0.3)
	light.light_energy            = 12.0
	light.omni_range              = explosion_radius * 2.5
	var tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4)
	tween.tween_callback(light.queue_free)

# ─── FIREBALL (main burst) ────────────────────────

func spawn_fireball(pos: Vector3):
	var p = CPUParticles3D.new()
	get_tree().root.add_child(p)
	p.global_transform.origin  = pos
	p.amount                   = 32
	p.one_shot                 = true
	p.explosiveness            = 1.0
	p.lifetime                 = 0.5
	p.initial_velocity_min     = 4.0
	p.initial_velocity_max     = 10.0
	p.gravity                  = Vector3(0, 2.0, 0)  # floats upward slightly
	p.spread                   = 180.0
	p.flatness                 = 0.0
	p.scale_amount_min         = 0.3
	p.scale_amount_max         = 0.6
	p.color                    = Color(1.0, 0.45, 0.05, 1.0)
	await get_tree().process_frame
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func(): p.queue_free())

# ─── SPARKS ───────────────────────────────────────

func spawn_sparks(pos: Vector3):
	var p = CPUParticles3D.new()
	get_tree().root.add_child(p)
	p.global_transform.origin  = pos
	p.amount                   = 20
	p.one_shot                 = true
	p.explosiveness            = 1.0
	p.lifetime                 = 0.8
	p.initial_velocity_min     = 8.0
	p.initial_velocity_max     = 18.0
	p.gravity                  = Vector3(0, -9.8, 0)  # falls with gravity
	p.spread                   = 180.0
	p.flatness                 = 0.0
	p.scale_amount_min         = 0.04
	p.scale_amount_max         = 0.08
	p.color                    = Color(1.0, 0.9, 0.3, 1.0)  # bright yellow sparks
	await get_tree().process_frame
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): p.queue_free())

# ─── SMOKE ───────────────────────────────────────

func spawn_smoke(pos: Vector3):
	var p = CPUParticles3D.new()
	get_tree().root.add_child(p)
	p.global_transform.origin  = pos
	p.amount                   = 16
	p.one_shot                 = true
	p.explosiveness            = 0.7
	p.lifetime                 = 1.5
	p.initial_velocity_min     = 1.0
	p.initial_velocity_max     = 3.0
	p.gravity                  = Vector3(0, 1.5, 0)  # drifts upward
	p.spread                   = 60.0
	p.flatness                 = 0.3
	p.scale_amount_min         = 0.4
	p.scale_amount_max         = 0.8
	p.color                    = Color(0.3, 0.3, 0.3, 0.6)  # dark grey smoke
	await get_tree().process_frame
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(func(): p.queue_free())
	
	

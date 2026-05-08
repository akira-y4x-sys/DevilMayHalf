extends RigidBody3D

@export var explosion_delay := 2.0
@export var explosion_damage := 25

@onready var explosion_area = $Area3D

var can_explode := false
var thrower = null

func _ready():
	# small grace period (so it doesn't explode instantly on spawn)
	await get_tree().create_timer(0.2).timeout
	can_explode = true
	
	# explosion timer
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

func explode():
	print("BOOM")

	for body in explosion_area.get_overlapping_bodies():
		if body == thrower:
			continue
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage)

	queue_free()

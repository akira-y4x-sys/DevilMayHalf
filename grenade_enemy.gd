extends CharacterBody3D

@export var max_health := 180
@export var gravity        := 25.0
@export var move_speed := 3.0
@export var throw_cooldown := 2.5
@export var throw_force := 12.0
@export var throw_arc := 6.0
@export var grenade_scene: PackedScene

var player
var health := 180
var can_throw := true

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
func take_damage(amount: int):
	velocity += -transform.basis.z * 4.0
	health   -= amount
	if health <= 0:
		die()

func die():
	queue_free()
	
	
func _physics_process(delta):
		# mata o inimigo se cair no abismo
	if global_position.y < -20.0:
		queue_free()
		return

	if player == null:
		return
	
	if not player:
		return
	
	var direction = (player.global_transform.origin - global_transform.origin)
	var distance = direction.length()
	direction = direction.normalized()
	
	# Move toward player
	if distance > 8:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
	
	# Throw grenade
	if can_throw and distance < 20:
		throw_grenade()

func throw_grenade():
	can_throw = false
	
	var grenade = grenade_scene.instantiate()
	get_parent().add_child(grenade)
	
	var spawn_pos = global_transform.origin + Vector3(0, 1.5, 0)
	grenade.global_transform.origin = spawn_pos
	
	var target_dir = (player.global_transform.origin - spawn_pos).normalized()
	
	var velocity = target_dir * throw_force
	velocity.y += throw_arc
	
	grenade.set_velocity(velocity)
	grenade.thrower = self
		
	await get_tree().create_timer(throw_cooldown).timeout
	can_throw = true

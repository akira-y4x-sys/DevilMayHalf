extends CharacterBody3D

@export var max_health    := 180
@export var gravity       := 25.0
@export var move_speed    := 3.0
@export var throw_cooldown := 2.5
@export var throw_force   := 12.0
@export var throw_arc     := 6.0
@export var grenade_scene : PackedScene

var player
var health    := 180
var can_throw := true
var sees_player := false

func _ready():
	player = get_tree().get_first_node_in_group("player")

func take_damage(amount: int):
	velocity += -transform.basis.z * 4.0
	health   -= amount
	if health <= 0:
		die()

func die():
	queue_free()

# ─── LINE OF SIGHT ───────────────────────────────
# Igual ao grunt — raycast + campo de visão
func can_see_player() -> bool:
	if player == null:
		return false

	var to_player = player.global_transform.origin - global_transform.origin
	var distance  = to_player.length()

	# alcance máximo de visão
	if distance > 24.0:
		return false

	# campo de visão de ~120 graus (dot > -0.5 = quase semicírculo)
	var direction = to_player.normalized()
	var forward   = -global_transform.basis.z.normalized()
	if forward.dot(direction) < -0.5:
		return false

	# raycast — não enxerga através de paredes
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin + Vector3(0, 0.5, 0),
		player.global_transform.origin
	)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	return result and result.collider.is_in_group("player")

# ─── LOOP ────────────────────────────────────────
func _physics_process(delta):
	if global_position.y < -20.0:
		queue_free()
		return

	if player == null:
		return

	# GRAVIDADE — era isso que causava a flutuação
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0.0

	sees_player = can_see_player()

	var direction = (player.global_transform.origin - global_transform.origin)
	var distance  = direction.length()
	direction     = direction.normalized()

	if sees_player:
		# move em direção ao player se estiver longe
		if distance > 8.0:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0

		# lança granada se estiver no alcance
		if can_throw and distance < 20.0:
			throw_grenade()

		look_at(
			player.global_position * Vector3(1, 0, 1) + Vector3(0, global_position.y, 0),
			Vector3.UP
		)
	else:
		# para quando perde visão
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

func throw_grenade():
	can_throw = false
	var grenade   = grenade_scene.instantiate()
	get_parent().add_child(grenade)

	var spawn_pos = global_transform.origin + Vector3(0, 1.5, 0)
	grenade.global_transform.origin = spawn_pos

	var target_dir      = (player.global_transform.origin - spawn_pos).normalized()
	var grenade_velocity = target_dir * throw_force
	grenade_velocity.y  += throw_arc
	grenade.set_velocity(grenade_velocity)
	grenade.thrower = self

	get_tree().create_timer(throw_cooldown).timeout.connect(func():
		can_throw = true
	)
	

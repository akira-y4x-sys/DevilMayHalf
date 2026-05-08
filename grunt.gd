extends CharacterBody3D

@export var max_health     := 120
@export var move_speed     := 5.0
@export var lunge_force    := 9.0
@export var gravity        := 25.0
@export var speed          := 5.0
@export var acceleration   := 3.0
@export var lunge_damage   := 10
@export var attack_range   := 4.0
@export var attack_cooldown := 1.0
@export var stop_distance := 2.5

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var mat:  StandardMaterial3D = mesh.material_override

var health     := 120
var attack_dir := Vector3.ZERO
var can_attack := true
var player: CharacterBody3D
var sees_player := false

func _ready():
	health = max_health
	player = get_tree().get_first_node_in_group("player")

# ─── ATAQUE ──────────────────────────────────────

func attack(dir: Vector3):
	can_attack = false
	attack_dir = dir.normalized()

	# little wind-up (gives player time to react)
	await get_tree().create_timer(0.15).timeout

	var dist = global_position.distance_to(player.global_position)

	# CLOSE RANGE → melee swing (no dash)
	if dist < stop_distance + 0.5:
		try_melee_hit()

	# MID RANGE → lunge in locked direction
	else:
		velocity += attack_dir * lunge_force
		velocity.y = 2.5

	get_tree().create_timer(attack_cooldown).timeout.connect(func():
		can_attack = true
	)

func try_melee_hit():
	if player == null:
		return

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	# too far? miss
	if dist > attack_range:
		return

	var dir_to_player = to_player.normalized()

	# dot product = how aligned the player is with our attack direction
	var alignment = attack_dir.dot(dir_to_player)

	# if player moved sideways, this drops!
	if alignment > 0.5:
		if player.has_method("take_damage"):
			player.take_damage(lunge_damage)

# ─── DANO / MORTE ────────────────────────────────

func take_damage(amount: int):
	velocity += -transform.basis.z * 4.0
	health   -= amount
	if health <= 0:
		die()

func die():
	queue_free()


func can_see_player(player):
	var to_player = player.global_transform.origin - global_transform.origin
	var distance = to_player.length()

	if distance > 20.0:
		return false

	var direction = to_player.normalized()
	var forward = -global_transform.basis.z.normalized()

	var dot = forward.dot(direction)
	if dot < 0.3:
		return false

	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin,
		player.global_transform.origin
	)
	query.exclude = [self]

	var result = space.intersect_ray(query)

	if result and result.collider.is_in_group("player"):
		return true

	return false


# ─── LOOP ────────────────────────────────────────
func _physics_process(delta):
	# mata o inimigo se cair no abismo
	if global_position.y < -20.0:
		queue_free()
		return

	sees_player = can_see_player(player)
	if player == null:
		return

	var to_player      := player.global_position - global_position
	var distance       := to_player.length()
	var to_player_flat := Vector3(to_player.x, 0.0, to_player.z)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if not sees_player:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		return

	if sees_player and distance > stop_distance:
		var dir = to_player_flat.normalized()
		velocity.x = move_toward(velocity.x, dir.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * move_speed, acceleration * delta)
	else:
	# slow down when close instead of sliding into player
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if sees_player and distance <= attack_range and can_attack:
		attack(to_player_flat.normalized())

	if sees_player:
		look_at(player.global_position * Vector3(1,0,1) + Vector3(0, global_position.y, 0), Vector3.UP)
	move_and_slide()

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
@export var stop_distance  := 2.5

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var mat: StandardMaterial3D = mesh.material_override

var health      := 120
var attack_dir  := Vector3.ZERO
var can_attack  := true
var player: CharacterBody3D
var sees_player := false

# aggro: true quando tomou dano ou viu o player
# persegue mesmo sem linha de visão por um tempo
var is_aggroed  := false
var aggro_timer := 0.0
const AGGRO_DURATION := 8.0  # segundos de perseguição após perder visão/levar dano

func _ready():
	health = max_health
	player = get_tree().get_first_node_in_group("player")

# ─── ATAQUE ──────────────────────────────────────

func attack(dir: Vector3):
	if not can_attack:
		return
	can_attack  = false
	attack_dir  = dir.normalized()

	await get_tree().create_timer(0.15).timeout

	var dist = global_position.distance_to(player.global_position)
	if dist < stop_distance + 0.5:
		try_melee_hit()
	else:
		velocity  += attack_dir * lunge_force
		velocity.y = 2.5

	get_tree().create_timer(attack_cooldown).timeout.connect(func():
		can_attack = true
	)

func try_melee_hit():
	if player == null:
		return
	var to_player = player.global_position - global_position
	if to_player.length() > attack_range:
		return
	var dir_to_player = to_player.normalized()
	if attack_dir.dot(dir_to_player) > 0.5:
		if player.has_method("take_damage"):
			player.take_damage(lunge_damage)

# ─── DANO / MORTE ────────────────────────────────

func take_damage(amount: int):
	velocity += -transform.basis.z * 4.0
	health   -= amount

	# aggro ao tomar dano — mesmo sem ver o player
	is_aggroed  = true
	aggro_timer = AGGRO_DURATION

	if health <= 0:
		die()

func die():
	queue_free()

# ─── LINE OF SIGHT ───────────────────────────────

func can_see_player(p) -> bool:
	var to_player = p.global_transform.origin - global_transform.origin
	var distance  = to_player.length()

	if distance > 20.0:
		return false

	var direction = to_player.normalized()
	var forward   = -global_transform.basis.z.normalized()

	# visão periférica ~150 graus (dot > -0.25)
	# antes era 0.3 (~72 graus) — muito estreito
	if forward.dot(direction) < -0.25:
		return false

	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin,
		p.global_transform.origin
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

	if not is_on_floor():
		velocity.y -= gravity * delta

	# atualiza timer de aggro
	if is_aggroed:
		aggro_timer -= delta
		if aggro_timer <= 0:
			is_aggroed = false

	sees_player = can_see_player(player)

	# aggro ao ver o player
	if sees_player and not is_aggroed:
		is_aggroed  = true
		aggro_timer = AGGRO_DURATION

	var to_player      := player.global_position - global_position
	var distance       := to_player.length()
	var to_player_flat := Vector3(to_player.x, 0.0, to_player.z)

	if is_aggroed:
		if distance > stop_distance:
			var dir    = to_player_flat.normalized()
			velocity.x = move_toward(velocity.x, dir.x * move_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, dir.z * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

		if distance <= attack_range and can_attack:
			attack(to_player_flat.normalized())

		look_at(
			player.global_position * Vector3(1, 0, 1) + Vector3(0, global_position.y, 0),
			Vector3.UP
		)
	else:
		# sem aggro — para e ignora o player
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	move_and_slide()
	

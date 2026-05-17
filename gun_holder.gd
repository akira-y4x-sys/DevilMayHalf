extends Node3D

@export var guns: Array[PackedScene] = []

var current_index    : int     = -1
var current_gun      : Node3D  = null

# ─── WALL PROXIMITY ──────────────────────────────
var base_gun_position  := Vector3.ZERO
var gun_position_set   := false

# ─── BOB ─────────────────────────────────────────
@export var bob_frequency  := 6.0    # oscillation speed
@export var bob_amplitude  := 0.012  # up/down amount
@export var bob_side_mult  := 0.5    # side bob relative to vertical
var bob_timer          := 0.0

# ─── MOUSE SWAY ──────────────────────────────────
@export var mouse_sway_amount  := 0.04  # how much the gun lags
@export var mouse_sway_speed   := 6.0   # how fast it returns
var mouse_delta            := Vector2.ZERO
var sway_offset            := Vector3.ZERO

# ─── LANDING IMPACT ──────────────────────────────
@export var landing_impact_amount := 0.06  # how far it dips
@export var landing_impact_speed  := 10.0  # how fast it recovers
var impact_offset          := 0.0
var was_on_floor           := true

# ─── REFS ────────────────────────────────────────
var player: CharacterBody3D


func _ready():
	player = get_tree().get_first_node_in_group("player")
	if guns.size() > 0:
		switch_gun(0)


# ════════════════════════════════════════════════
# INPUT — capture mouse delta for sway
# ════════════════════════════════════════════════

func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			Key.KEY_1: switch_gun(0)
			Key.KEY_2: switch_gun(1)
			Key.KEY_3: switch_gun(2)


# ════════════════════════════════════════════════
# PROCESS — all sway/bob logic
# ════════════════════════════════════════════════

func _process(delta):
	if not current_gun or not player:
		return

	# store base position once per gun equip
	if not gun_position_set:
		base_gun_position = current_gun.position
		gun_position_set  = true

	var target_pos = base_gun_position

	# ── 1. WALL PROXIMITY ────────────────────────
	var cam   = get_parent()
	var space = get_world_3d().direct_space_state
	var from  = cam.global_transform.origin
	var to    = from + (-cam.global_transform.basis.z * 0.8)

	var query            = PhysicsRayQueryParameters3D.new()
	query.from           = from
	query.to             = to
	query.exclude        = [player, current_gun]
	query.collision_mask = 1

	var wall_result = space.intersect_ray(query)
	if wall_result:
		var wall_dist  = from.distance_to(wall_result.position)
		var push_back  = (0.8 - wall_dist) * 0.6
		target_pos.z  += push_back

	# ── 2. BOB ───────────────────────────────────
	var h_speed = Vector2(player.velocity.x, player.velocity.z).length()
	var is_moving = h_speed > 0.5 and player.is_on_floor()

	if is_moving:
		bob_timer += delta * bob_frequency
		var bob_y  =  sin(bob_timer) * bob_amplitude
		var bob_x  =  sin(bob_timer * 0.5) * bob_amplitude * bob_side_mult
		target_pos.y += bob_y
		target_pos.x += bob_x
	else:
		# smoothly kill bob when stopping
		bob_timer = lerp(bob_timer, round(bob_timer / PI) * PI, delta * 8.0)

	# ── 3. MOUSE SWAY ────────────────────────────
	var target_sway = Vector3(
		-mouse_delta.x * mouse_sway_amount,
		-mouse_delta.y * mouse_sway_amount,
		0.0
	)
	sway_offset = sway_offset.lerp(target_sway, delta * mouse_sway_speed)
	target_pos += sway_offset

	# consume mouse delta so it doesn't accumulate
	mouse_delta = mouse_delta.lerp(Vector2.ZERO, delta * mouse_sway_speed)

	# ── 4. LANDING IMPACT ────────────────────────
	var on_floor = player.is_on_floor()
	if on_floor and not was_on_floor:
		# just landed — calculate impact based on fall speed
		var fall_speed = abs(player.velocity.y)
		impact_offset  = -clamp(fall_speed * 0.008, 0.02, landing_impact_amount)
	was_on_floor = on_floor

	# recover impact offset
	impact_offset  = lerp(impact_offset, 0.0, delta * landing_impact_speed)
	target_pos.y  += impact_offset

	# ── APPLY ────────────────────────────────────
	current_gun.position = current_gun.position.lerp(target_pos, delta * 20.0)


# ════════════════════════════════════════════════
# WEAPON SWITCHING
# ════════════════════════════════════════════════

func switch_gun(index: int) -> void:
	if guns.size() == 0:
		return
	index = index % guns.size()
	if current_gun:
		current_gun.queue_free()
		current_gun      = null
		gun_position_set = false  # reset so base position is re-captured
	current_index = index
	var scene: PackedScene = guns[current_index]
	current_gun = scene.instantiate() as Node3D
	add_child(current_gun)
	current_gun.transform = Transform3D.IDENTITY
	if current_gun.has_method("on_equip"):
		current_gun.call("on_equip")

func fire_current():
	if not current_gun:
		return
	if "is_automatic" in current_gun and current_gun.is_automatic:
		if Input.is_action_pressed("fire"):
			current_gun.shoot()
	else:
		if Input.is_action_just_pressed("fire"):
			current_gun.shoot()

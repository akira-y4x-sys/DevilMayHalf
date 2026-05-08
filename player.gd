extends CharacterBody3D

# ─── MOVEMENT TUNING ─────────────────────────────
@export var ground_speed    := 7.0
@export var crouch_speed    := 3.5

@export var ground_accel    := 15.0   # alto para resposta imediata no chão
@export var air_accel       := 1.0    # baixo no ar — mas SEM friction = bhop funciona
@export var friction        := 6.0

@export var gravity         := 20.0
@export var jump_force      := 5.5

# WALL RUN
@export var wall_run_gravity    := 12.0
@export var wall_run_speed      := 12.0
@export var wall_run_pull       := 2.0
@export var max_wall_run_time   := 0.2

# SLIDE
@export var slide_friction      := 6.0
@export var min_slide_speed     := 9.0

# FOV
@export var base_fov    := 75.0
@export var max_fov     := 80.0
@export var fov_speed   := 3.0

# CAMERA ROLL
@export var wall_run_roll_angle := 10.0
@export var roll_speed          := 8.0

# STEP / BHOP
@export var step_height         := 0.5

# ─── CAMERA / INPUT ─────────────────────────────
@export var mouse_sens  := 0.15
var cam_pitch           := 0.0

@onready var cam_pivot  := $CameraPivot
@onready var cam        := $CameraPivot/Camera3D
@onready var gun_holder := $CameraPivot/Camera3D/GunHolder

# ─── CROUCH ─────────────────────────────────────
@onready var collider   := $CollisionShape3D
@onready var capsule    := collider.shape as CapsuleShape3D

@export var stand_height    := 2.0
@export var crouch_height   := 1.0

# ─── GUN SWAY ───────────────────────────────────
var sway_amount     := 1.5
var sway_speed      := 16.0
var sway_smooth     := 16.0
var sway_x          := 0.0
var sway_y          := 0.0

var is_crouching    := false

# ─── FOOTSTEPS ──────────────────────────────────
@onready var footstep_player = $FootstepPlayer
var step_sounds = [
	preload("res://sounds/footstep1.wav"),
	preload("res://sounds/footstep2.wav"),
	preload("res://sounds/footstep3.wav"),
	preload("res://sounds/footstep4.wav")
]
var step_timer      := 0.0
var step_interval   := 0.42

# ─── ESTADO GERAL ───────────────────────────────
var is_wall_running := false
var wall_run_timer  := 0.0
var wall_normal     := Vector3.ZERO
var is_sliding      := false
var current_roll    := 0.0

# Controla se o jump deste frame deve pular o friction
var _jumped_this_frame := false


# ════════════════════════════════════════════════
# LOOP PRINCIPAL
# ════════════════════════════════════════════════

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	_jumped_this_frame = false

	handle_gravity(delta)
	handle_jump()          # seta _jumped_this_frame = true se pulou
	handle_wall_run(delta)
	handle_slide(delta)
	handle_movement(delta) # friction só roda se não pulou neste frame
	handle_crouch(delta)
	handle_footsteps(delta)
	handle_speed_fov(delta)
	handle_camera_roll(delta)
	try_step()
	move_and_slide()

	# Gun sway
	var input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	sway_x = lerp(sway_x, input_x * sway_amount, delta * sway_smooth)
	cam_pivot.rotation = cam_pivot.rotation.lerp(
		Vector3(deg_to_rad(sway_y * 2.0), 0.0, deg_to_rad(sway_x * -2.0)),
		delta * sway_speed
	)


# ════════════════════════════════════════════════
# FÍSICA ESTILO QUAKE (CPM)
# ════════════════════════════════════════════════

func get_wish_dir() -> Vector3:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back")  - Input.get_action_strength("move_forward")
	)
	if input.length() == 0:
		return Vector3.ZERO
	return (transform.basis * Vector3(input.x, 0, input.y)).normalized()

func handle_gravity(delta):
	if is_wall_running:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0.0

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		_jumped_this_frame = true   # pula o friction neste frame → bhop funciona

func handle_movement(delta):
	var wish_dir   = get_wish_dir()
	var wish_speed = crouch_speed if is_crouching else ground_speed

	# ── Aceleração CPM ──────────────────────────────────────────────────────
	# Quake calcula quanto da velocidade atual já aponta para wish_dir.
	# Só adiciona o que falta — isso permite air-strafe e bunny hop real.
	if wish_dir != Vector3.ZERO:
		var current_speed = velocity.dot(wish_dir)       # componente útil
		var add_speed     = wish_speed - current_speed   # quanto falta

		if add_speed > 0:
			var accel = ground_accel if is_on_floor() else air_accel
			var accel_speed = min(accel * wish_speed * delta, add_speed)
			velocity += wish_dir * accel_speed

	# ── Cap de velocidade horizontal no chão ────────────────────────────────
	# Sem isso, zigzag e círculos acumulam velocidade infinita porque
	# velocity.dot(wish_dir) fica negativo, inflando o add_speed além do limite.
	# No ar o cap é removido de propósito — é o que permite o bhop acumular speed.
	if is_on_floor() and not is_sliding:
		var h_vel        = Vector3(velocity.x, 0.0, velocity.z)
		var max_speed    = wish_speed if wish_dir != Vector3.ZERO else ground_speed
		if h_vel.length() > max_speed:
			var capped   = h_vel.normalized() * max_speed
			velocity.x   = capped.x
			velocity.z   = capped.z

	# ── Friction ─────────────────────────────────────────────────────────────
	# Só aplica no chão, sem slide, sem wall run, e NÃO no frame do pulo.
	# Remover o friction no frame do pulo é o segredo do bhop do Quake.
	if is_on_floor() and not is_sliding and not is_wall_running and not _jumped_this_frame:
		if wish_dir == Vector3.ZERO:
			var speed = velocity.length()
			if speed > 0.0:
				var drop      = speed * friction * delta
				var new_speed = max(speed - drop, 0.0)
				velocity     *= new_speed / speed


# ════════════════════════════════════════════════
# WALL RUN
# ════════════════════════════════════════════════

func get_wall_run_normal() -> Vector3:
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		if abs(col.get_normal().y) < 0.2:
			return col.get_normal()
	return Vector3.ZERO

func handle_wall_run(delta):
	if is_on_floor():
		is_wall_running = false
		wall_run_timer  = 0.0
		return

	var wish_dir = get_wish_dir()
	var normal   = get_wall_run_normal()

	if normal != Vector3.ZERO and wish_dir != Vector3.ZERO:
		if not is_wall_running:
			is_wall_running = true
			wall_run_timer  = max_wall_run_time
			wall_normal     = normal

	if is_wall_running:
		wall_run_timer -= delta
		if wall_run_timer <= 0:
			is_wall_running = false
			return

		velocity.y -= wall_run_gravity * delta

		var wall_dir = wall_normal.cross(Vector3.UP).normalized()
		if wall_dir.dot(wish_dir) < 0:
			wall_dir = -wall_dir

		velocity.x = move_toward(velocity.x, wall_dir.x * wall_run_speed, wall_run_pull * delta)
		velocity.z = move_toward(velocity.z, wall_dir.z * wall_run_speed, wall_run_pull * delta)


# ════════════════════════════════════════════════
# SLIDE
# ════════════════════════════════════════════════

func handle_slide(delta):
	var h_speed = Vector2(velocity.x, velocity.z).length()

	is_sliding = is_on_floor() and Input.is_action_pressed("crouch") and h_speed > min_slide_speed

	if is_sliding:
		velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, slide_friction * delta)


# ════════════════════════════════════════════════
# CROUCH
# ════════════════════════════════════════════════

@warning_ignore("unused_parameter")
func handle_crouch(delta):
	if Input.is_action_pressed("crouch"):
		is_crouching = true
	else:
		is_crouching = not can_stand()

	var target_height = crouch_height if is_crouching else stand_height
	capsule.height    = lerp(capsule.height, target_height, 0.2)

func can_stand() -> bool:
	var from  = global_transform.origin
	var to    = from + Vector3.UP * (stand_height - crouch_height)
	var query = PhysicsRayQueryParameters3D.new()
	query.from    = from
	query.to      = to
	query.exclude = [self]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ════════════════════════════════════════════════
# STEP (escada suave)
# ════════════════════════════════════════════════

func try_step():
	if not is_on_floor():
		return
	var h_vel = Vector3(velocity.x, 0, velocity.z)
	if h_vel.length() < 0.1:
		return
	var motion    = h_vel * get_physics_process_delta_time()
	var collision = move_and_collide(motion, true)
	if not collision:
		return
	var step_up = Vector3(0, step_height, 0)
	if move_and_collide(step_up, true):
		return
	if move_and_collide(motion, true):
		move_and_collide(-step_up)
		return
	move_and_collide(-step_up)


# ════════════════════════════════════════════════
# CÂMERA
# ════════════════════════════════════════════════

func handle_camera_roll(delta):
	var target_roll := 0.0
	if is_wall_running:
		var side   = sign(wall_normal.dot(transform.basis.x))
		target_roll = -side * wall_run_roll_angle
	current_roll          = lerp(current_roll, target_roll, delta * roll_speed)
	cam.rotation_degrees.z = current_roll

func handle_speed_fov(delta):
	var h_speed    = Vector2(velocity.x, velocity.z).length()
	var target_fov = lerp(base_fov, max_fov, clamp(h_speed / (ground_speed * 2.0), 0.0, 1.0))
	cam.fov        = lerp(cam.fov, target_fov, delta * 8.0)


# ════════════════════════════════════════════════
# FOOTSTEPS
# ════════════════════════════════════════════════

func handle_footsteps(delta):
	var speed = Vector2(velocity.x, velocity.z).length()
	if speed > 0.1 and is_on_floor():
		step_timer -= delta
		if step_timer <= 0:
			footstep_player.stream   = step_sounds.pick_random()
			footstep_player.volume_db = randf_range(-2, 0)
			footstep_player.play()
			step_timer = step_interval
	else:
		step_timer = 0.0


# ════════════════════════════════════════════════
# INPUT
# ════════════════════════════════════════════════

func _input(event):
	if event is InputEventMouseMotion:
		var ratio = Vector2(
			DisplayServer.window_get_size().x / ProjectSettings.get_setting("display/window/size/viewport_width"),
			DisplayServer.window_get_size().y / ProjectSettings.get_setting("display/window/size/viewport_height")
		)
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens * ratio.x))
		cam_pitch = clamp(cam_pitch - event.relative.y * mouse_sens * ratio.y, -89, 89)
		cam.rotation_degrees.x = cam_pitch

func _process(_delta):
	if Input.is_action_pressed("fire"):
		gun_holder.fire_current()

# ─── STATS ───────────────────────────────────────
@export var max_health := 100
@export var max_armor  := 100

var health := 100
var armor  := 0      # começa sem armor, pega via pickup

# ─── REFERÊNCIAS ─────────────────────────────────
@onready var hud := get_tree().get_first_node_in_group("hud")

# ─── DANO ────────────────────────────────────────

func take_damage(amount: int):
	# Armor absorve 2/3 do dano (padrão Quake)
	if armor > 0:
		var absorbed  = min(int(amount * 0.66), armor)
		armor        -= absorbed
		amount       -= absorbed

	health -= amount
	hud.update_stats(health, armor)

	if health <= 0:
		die()

func heal(amount: int):
	health = min(health + amount, max_health)
	hud.update_stats(health, armor)

func add_armor(amount: int):
	armor = min(armor + amount, max_armor)
	hud.update_stats(health, armor)

func die():
	# por enquanto só printa — você pode adicionar respawn aqui depois
	print("player morreu")

# ─── MUNIÇÃO ─────────────────────────────────────
# dicionário indexado por nome de arma — fácil de expandir
var ammo := {
	"pistol":   50,
	"shotgun":  20,
}

var ammo_max := {
	"pistol":   200,
	"shotgun":  50,
}

func use_ammo(weapon: String, amount: int = 1) -> bool:
	if not ammo.has(weapon):
		return true   # arma sem munição (ex: faca) sempre pode atirar

	if ammo[weapon] <= 0:
		return false  # sem bala

	ammo[weapon] -= amount
	hud.update_ammo(ammo[weapon])
	return true

func add_ammo(weapon: String, amount: int):
	if not ammo.has(weapon):
		return
	ammo[weapon] = min(ammo[weapon] + amount, ammo_max[weapon])
	hud.update_ammo(ammo[weapon])

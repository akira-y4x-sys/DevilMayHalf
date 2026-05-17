extends Node3D

@onready var muzzle = $MuzzlePoint
@onready var sound  = $GunSound
@onready var flash  = $MuzzleFlash

@export var is_automatic  := false
@export var tracer_scene  : PackedScene
@export var impact_scene : PackedScene

const PELLETS   := 12
const SPREAD    := 3.0
const DAMAGE    := 18
const RANGE     := 300.0

var can_shoot   := true
var shoot_delay := 0.45
var player      = null

func _ready():
	player = get_tree().get_first_node_in_group("player")

func shoot():
	if not can_shoot:
		return
	if player and not player.use_ammo("shotgun", 1):
		return
	can_shoot = false
	fire()
	cast_pellets()
	await get_tree().create_timer(shoot_delay).timeout
	can_shoot = true

func cast_pellets():
	var space = get_world_3d().direct_space_state
	var cam   = player.get_node("CameraPivot/Camera3D")
	for i in range(PELLETS):
		var dir  = get_spread_direction()
		var from = cam.global_transform.origin
		var to   = from + dir * RANGE

		var query     = PhysicsRayQueryParameters3D.new()
		query.from    = from
		query.to      = to
		query.exclude = [self]

		var result = space.intersect_ray(query)
		if result:
			var hit = result.collider

			if hit.has_method("take_damage"):
				hit.take_damage(DAMAGE)

		spawn_impact(result.position, result.normal)

		var hit_pos = result.position if result else (from + dir * RANGE)
		spawn_tracer(muzzle.global_transform.origin, dir, hit_pos)

func spawn_impact(position: Vector3, normal: Vector3):
	if not impact_scene:
		return
	var impact = impact_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_transform.origin = position + normal * 0.1

	# rotaciona o impacto para apontar na direção da normal da superfície
	var up = Vector3.UP
	if abs(normal.dot(Vector3.UP)) > 0.99:
		up = Vector3.FORWARD
	impact.look_at(position + normal, up)

func get_spread_direction() -> Vector3:
	var cam        = player.get_node("CameraPivot/Camera3D")
	var spread_rad = deg_to_rad(SPREAD)
	var angle_x    = randf_range(-spread_rad, spread_rad)
	var angle_y    = randf_range(-spread_rad, spread_rad)
	var base_dir   = -cam.global_transform.basis.z
	base_dir = base_dir.rotated(cam.global_transform.basis.x, angle_x)
	base_dir = base_dir.rotated(cam.global_transform.basis.y, angle_y)
	return base_dir.normalized()

func spawn_tracer(from: Vector3, direction: Vector3, hit_pos: Vector3):
	if not tracer_scene:
		return
	var tracer = tracer_scene.instantiate()
	get_tree().root.add_child(tracer)
	tracer.init(from, direction, hit_pos)

func fire():
	flash.visible = true
	sound.play()
	get_tree().create_timer(0.05).timeout.connect(func():
		flash.visible = false
	)
	

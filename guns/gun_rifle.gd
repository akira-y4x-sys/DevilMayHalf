extends Node3D

@onready var muzzle = $MuzzleFlash
@onready var sound  = $GunSound
@onready var flash  = $MuzzleFlash
@onready var anim = $blockbench_export/AnimationPlayer
@onready var ammo_text = $AmmoText
@export var ammo_type := "rifle"

@export var is_automatic  := true
@export var tracer_scene  : PackedScene

const DAMAGE    := 20
const RANGE     := 300.0

var can_shoot   := true
var shoot_delay := 0.10
var player      = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	update_ammo_display()

func update_ammo_display():
	if not player:
		return

	var ammo = player.get_ammo(ammo_type)
	ammo_text.text = str(ammo)

	if ammo <= 10:
		ammo_text.modulate = Color.RED
	elif ammo <= 30:
		ammo_text.modulate = Color.YELLOW
	else:
		ammo_text.modulate = Color.CYAN

func shoot():
	if not can_shoot:
		return
	if player and not player.use_ammo("rifle", 1):
		return

	update_ammo_display()
	can_shoot = false

	var space = get_world_3d().direct_space_state
	var from  = muzzle.global_transform.origin
	var dir   = -muzzle.global_transform.basis.z
	var to    = from + dir * RANGE

	var query     = PhysicsRayQueryParameters3D.new()
	query.from    = from
	query.to      = to
	query.exclude = [self]

	var result = space.intersect_ray(query)
	if result:
		var hit = result.collider
		if hit.has_method("take_damage"):
			hit.take_damage(DAMAGE)

	var hit_pos = result.position if result else (from + dir * RANGE)
	spawn_tracer(from, dir, hit_pos)
	fire()

	await get_tree().create_timer(shoot_delay).timeout
	can_shoot = true

func spawn_tracer(from: Vector3, direction: Vector3, hit_pos: Vector3):
	if not tracer_scene:
		return
	var tracer = tracer_scene.instantiate()
	get_tree().root.add_child(tracer)
	tracer.init(from, direction, hit_pos)

func fire():
	anim.play("shoot")
	flash.visible = true
	sound.play()
	get_tree().create_timer(0.05).timeout.connect(func():
		flash.visible = false
	)

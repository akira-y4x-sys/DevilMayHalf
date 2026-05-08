extends Node3D

var speed      := 60.0
var lifetime   := 0.15
var timer      := 0.0
var target_pos := Vector3.ZERO
var has_target := false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready():
	var mat = mesh_instance.material_override
	if mat:
		mesh_instance.material_override = mat.duplicate()

func init(from: Vector3, direction: Vector3, hit_pos: Vector3):
	global_position = from
	look_at(from + direction, Vector3.UP)
	target_pos = hit_pos
	has_target = true

func _process(delta):
	timer += delta
	position -= transform.basis.z * speed * delta

	if has_target:
		var dist = global_position.distance_to(target_pos)
		if dist < 0.3:

			queue_free()
			return

	# fade out
	var t = 1.0 - clamp(timer / lifetime, 0.0, 1.0)
	var mat = mesh_instance.material_override
	if mat:
		mat.emission_energy_multiplier = t * 4.0

	if timer >= lifetime:
		queue_free()

extends Area3D

enum PickupType { HEALTH, AMMO, ARMOR }

@export var type        : PickupType = PickupType.HEALTH
@export var amount      : int        = 25
@export var ammo_weapon : String     = "pistol"  # only used if type == AMMO
@export var respawn     : bool       = false
@export var respawn_time: float      = 30.0

# optional — assign a MeshInstance3D or Node3D to hide on pickup
@onready var mesh = $blockbench_export

var picked_up := false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D):
	if picked_up:
		return
	if not body.is_in_group("player"):
		return

	# check if player actually needs this pickup
	if not _player_needs(body):
		return

	picked_up = true
	_apply(body)

	# hide the mesh
	if mesh:
		mesh.visible = false

	if respawn:
		get_tree().create_timer(respawn_time).timeout.connect(func():
			picked_up    = false
			if mesh:
				mesh.visible = true
		)
	else:
		queue_free()


func _player_needs(player) -> bool:
	match type:
		PickupType.HEALTH:
			return player.health < player.max_health
		PickupType.ARMOR:
			return player.armor < player.max_armor
		PickupType.AMMO:
			if player.ammo.has(ammo_weapon):
				return player.ammo[ammo_weapon] < player.ammo_max[ammo_weapon]
	return false


func _apply(player):
	match type:
		PickupType.HEALTH:
			player.heal(amount)
		PickupType.ARMOR:
			player.add_armor(amount)
		PickupType.AMMO:
			player.add_ammo(ammo_weapon, amount)

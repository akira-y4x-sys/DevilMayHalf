extends Node3D

@export var guns: Array[PackedScene] = []    # drag your pistol.tscn, shotgun.tscn here
var current_index: int = -1
var current_gun: Node3D = null

func _ready():
	# spawn first gun automatically if we have any
	if guns.size() > 0:
		switch_gun(0)

func switch_gun(index: int) -> void:
	if guns.size() == 0:
		return

	# clamp/wrap
	index = index % guns.size()

	# remove old gun
	if current_gun:
		current_gun.queue_free()
		current_gun = null

	current_index = index
	# instantiate new gun and parent it to this holder
	var scene: PackedScene = guns[current_index]
	current_gun = scene.instantiate() as Node3D
	add_child(current_gun)

	# reset transform so it sits at the holder origin
	current_gun.transform = Transform3D.IDENTITY

	# optional: call an 'on_equip' if the gun implements it
	if current_gun.has_method("on_equip"):
		current_gun.call("on_equip")

func _input(event):
	# number keys (1,2,3...) switch weapons
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			Key.KEY_1:
				switch_gun(0)
			Key.KEY_2:
				switch_gun(1)
			Key.KEY_3:
				switch_gun(2)

# call this from player input when firing (or forward input to the current gun)
func fire_current():
	if not current_gun:
		return

	if "is_automatic" in current_gun and current_gun.is_automatic:
		if Input.is_action_pressed("fire"):
			current_gun.shoot()
	else:
		if Input.is_action_just_pressed("fire"):
			current_gun.shoot()

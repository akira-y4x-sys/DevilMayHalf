extends CanvasLayer

# Adicione este nó ao grupo "hud" no editor do Godot

@onready var health_label := $MarginContainer/HBoxContainer/HealthLabel
@onready var armor_label  := $MarginContainer/HBoxContainer/ArmorLabel
@onready var ammo_label   := $MarginContainer/HBoxContainer/AmmoLabel

func update_stats(health: int, armor: int):
	health_label.text = str(max(health, 0))
	armor_label.text  = str(max(armor, 0))

func update_ammo(ammo: int):
	ammo_label.text = str(max(ammo, 0))

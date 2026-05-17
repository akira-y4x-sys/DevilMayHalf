extends CanvasLayer

# Adicione este nó ao grupo "hud" no editor do Godot

@onready var health_label := $MarginContainer/HBoxContainer/HealthLabel
@onready var armor_label  := $MarginContainer/HBoxContainer/ArmorLabel
@onready var ammo_label   := $MarginContainer/HBoxContainer/AmmoLabel
@onready var death_fade := $DeathFade

func fade_out(callback: Callable):
	var tween = create_tween()
	tween.tween_property(death_fade, "modulate:a", 1.0, 0.6)
	tween.tween_callback(callback)

func fade_in():
	var tween = create_tween()
	tween.tween_property(death_fade, "modulate:a", 0.0, 0.6)

func update_stats(health: int, armor: int):
	health_label.text = str(max(health, 0))
	armor_label.text  = str(max(armor, 0))

func update_ammo(ammo: int):
	ammo_label.text = str(max(ammo, 0))

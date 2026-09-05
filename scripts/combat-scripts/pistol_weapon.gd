class_name PistolWeapon
extends "res://scripts/combat-scripts/weapon_base.gd"


func _init() -> void:
	max_damage = 5.0
	min_damage = 2.0
	falloff_start_distance = 10.0
	falloff_end_distance = 30.0
	maximum_hit_distance = 50.0
	close_stationary_hit_chance = 0.95
	close_moving_hit_chance = 0.80
	minimum_hit_chance = 0.0
	accuracy_falloff_start_distance = 10.0

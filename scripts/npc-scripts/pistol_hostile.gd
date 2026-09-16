class_name PistolHostile
extends "res://scripts/npc-scripts/ranged_hostile.gd"
## Pistol presentation. Allegiance and stats are configured by enemy scenes.

@onready var pistol_shot_audio: AudioStreamPlayer3D = get_node_or_null("PistolShot")

# Compatibility for existing pistol diagnostics/tests.
var pistol_weapon: WeaponBase:
	get: return weapon
	set(value): weapon = value
var pistol_shot_origin_height: float:
	get: return shot_origin_height
	set(value): shot_origin_height = value
var pistol_target_height: float:
	get: return shot_target_height
	set(value): shot_target_height = value


func _ready() -> void:
	if weapon == null:
		weapon = preload("res://scripts/combat-scripts/pistol_weapon.gd").new()
	super()
	animation_controller.connect(&"pistol_reload_finished", _on_reload_finished)


func _play_shot() -> void:
	animation_controller.call("play_pistol_shot")


func _play_reload() -> void:
	animation_controller.call("play_pistol_reload")


func _is_shot_playing() -> bool:
	return animation_controller.call("is_pistol_shooting")


func _is_reload_playing() -> bool:
	return animation_controller.call("is_pistol_reloading")


func _play_shot_audio() -> void:
	if pistol_shot_audio != null:
		pistol_shot_audio.play()


func _handle_pistol_combat(delta: float) -> void:
	_handle_ranged_combat(delta)


func _resolve_pistol_shot() -> void:
	_resolve_shot()

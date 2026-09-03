extends RefCounted

signal health_changed(current_health: float, max_health: float)
signal depleted(damage_info)

var max_health: float
var current_health: float


func _init(initial_max_health: float = 100.0) -> void:
	max_health = maxf(initial_max_health, 1.0)
	current_health = max_health


func apply_damage(damage_info) -> bool:
	if is_depleted() or damage_info == null:
		return false

	var damage_amount: float = maxf(float(damage_info.amount), 0.0)
	if damage_amount <= 0.0:
		return false

	current_health = maxf(current_health - damage_amount, 0.0)
	health_changed.emit(current_health, max_health)
	if is_depleted():
		depleted.emit(damage_info)
	return true


func is_depleted() -> bool:
	return current_health <= 0.0

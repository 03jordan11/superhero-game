class_name Vehicle
extends RigidBody3D

signal destroyed

@export var max_health: float = 100.0
@export var health_label_height: float = 3.0

var health: float = 100.0
var is_destroyed: bool = false
var destruction_impact_speed: float = 0.0
var health_label: Label3D


func _ready() -> void:
	health = max_health
	_create_health_label()
	_update_health_label()


func take_damage(damage: float, impact_speed: float = 0.0) -> bool:
	if is_destroyed:
		return false

	health = maxf(health - damage, 0.0)
	_update_health_label()
	if health > 0.0:
		return false

	is_destroyed = true
	destruction_impact_speed = impact_speed
	destroyed.emit()
	return true


func destroy() -> bool:
	return take_damage(health)


func _create_health_label() -> void:
	health_label = Label3D.new()
	health_label.position = Vector3.UP * health_label_height
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 48
	health_label.outline_size = 6
	health_label.modulate = Color(1.0, 0.9, 0.2)
	add_child(health_label)


func _update_health_label() -> void:
	if health_label != null:
		health_label.text = str(roundi(health))

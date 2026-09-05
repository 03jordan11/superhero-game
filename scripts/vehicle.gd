class_name Vehicle
extends RigidBody3D

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/health_component.gd")
const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")

signal destroyed(impact_speed: float)

@export var max_health: float = 100.0
@export var health_label_height: float = 3.0

var is_destroyed: bool = false
var destruction_impact_speed: float = 0.0
var health_label: Label3D
var health_component
var is_thrown_impact_armed: bool = false
var last_thrown_impact_speed: float = 0.0
var thrown_impact_source: Node3D


func _ready() -> void:
	health_component = HEALTH_COMPONENT_SCRIPT.new(max_health)
	health_component.health_changed.connect(_on_health_changed)
	health_component.depleted.connect(_on_health_depleted)
	add_to_group(&"explodable")
	var explosion_controller: Node = (
		get_tree().get_first_node_in_group(&"explosion_controller")
	)
	if explosion_controller != null and explosion_controller.has_method("register_explodable"):
		explosion_controller.call("register_explodable", self)
	_create_health_label()
	_update_health_label()


func apply_damage(damage_info) -> bool:
	if is_destroyed or not health_component.apply_damage(damage_info):
		return false
	return true


func arm_thrown_impact(launch_speed: float, source: Node3D) -> void:
	var minimum_impact_speed := _get_explosion_minimum_impact_speed()
	if launch_speed < minimum_impact_speed:
		return

	contact_monitor = true
	max_contacts_reported = 8
	is_thrown_impact_armed = true
	last_thrown_impact_speed = launch_speed
	thrown_impact_source = source


func _physics_process(_delta: float) -> void:
	if not is_thrown_impact_armed:
		return
	if is_destroyed:
		_clear_thrown_impact()
		return

	var minimum_impact_speed := _get_explosion_minimum_impact_speed()
	if last_thrown_impact_speed < minimum_impact_speed:
		_clear_thrown_impact()
		return

	if get_contact_count() > 0:
		var impact_source: Node3D = (
			thrown_impact_source if is_instance_valid(thrown_impact_source) else null
		)
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			get_current_health(),
			global_position,
			Vector3.ZERO,
			&"none",
			impact_source,
			last_thrown_impact_speed
		)
		apply_damage(damage_info)
		_clear_thrown_impact()
		return

	last_thrown_impact_speed = linear_velocity.length()


func _clear_thrown_impact() -> void:
	is_thrown_impact_armed = false
	last_thrown_impact_speed = 0.0
	thrown_impact_source = null


func _get_explosion_minimum_impact_speed() -> float:
	var explosion_controller := get_tree().get_first_node_in_group(&"explosion_controller")
	if explosion_controller == null:
		return INF
	return float(explosion_controller.get("minimum_impact_speed"))


func get_current_health() -> float:
	return health_component.current_health


func get_max_health() -> float:
	return health_component.max_health


func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_update_health_label()


func _on_health_depleted(damage_info) -> void:
	is_destroyed = true
	destruction_impact_speed = damage_info.impact_speed
	destroyed.emit(destruction_impact_speed)


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
		health_label.text = str(roundi(health_component.current_health))

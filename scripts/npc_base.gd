class_name NPCBase
extends CharacterBody3D

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/health_component.gd")

@export var max_health: float = 100.0
@export var knockback_speed: float = 8.0
@export var knockback_deceleration: float = 8.0
@export var chest_hit_stun_duration: float = 0.75
@export var animation_controller_path: NodePath

var is_dead: bool = false
var health_component

var is_hit_reacting: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var chest_hit_stun_remaining: float = 0.0
var is_waiting_for_chest_hit_stun: bool = false
var knockback_stun_remaining: float = 0.0
var is_waiting_for_knockback_stun: bool = false

@onready var animation_controller: Node = get_node_or_null(animation_controller_path)
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	health_component = HEALTH_COMPONENT_SCRIPT.new(max_health)
	health_component.health_changed.connect(_on_health_changed)
	health_component.depleted.connect(_on_health_depleted)
	if animation_controller == null:
		push_error("%s is missing its NPC animation controller." % name)
	_update_health_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if is_hit_reacting:
		_process_hit_reaction(delta)
		move_and_slide()
		return

	_process_behavior(delta)
	move_and_slide()


func apply_damage(damage_info) -> bool:
	if is_dead or not health_component.apply_damage(damage_info):
		return false
	if is_dead:
		return true

	_on_damage_received(damage_info)
	is_hit_reacting = true
	is_waiting_for_chest_hit_stun = false
	is_waiting_for_knockback_stun = false
	knockback_velocity = Vector3.ZERO
	match damage_info.reaction:
		&"knockback":
			is_waiting_for_knockback_stun = true
			knockback_stun_remaining = chest_hit_stun_duration * 2.0
			_apply_knockback_from(damage_info.impact_origin, damage_info.impact_direction)
			_play_animation_method(&"play_knockback")
		&"ground_slam":
			is_waiting_for_knockback_stun = true
			knockback_stun_remaining = chest_hit_stun_duration * 2.0
			_apply_knockback_from(damage_info.impact_origin)
			_play_animation_method(&"play_ground_slam_knockback")
		_:
			is_waiting_for_chest_hit_stun = true
			chest_hit_stun_remaining = chest_hit_stun_duration
			_play_animation_method(&"play_hit")
	return true


func get_current_health() -> float:
	return health_component.current_health


func get_max_health() -> float:
	return health_component.max_health


func _process_behavior(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _on_damage_received(_damage_info) -> void:
	pass


func _on_died() -> void:
	pass


func _process_hit_reaction(delta: float) -> void:
	velocity.x = knockback_velocity.x
	velocity.z = knockback_velocity.z
	knockback_velocity = knockback_velocity.move_toward(
		Vector3.ZERO,
		knockback_deceleration * delta
	)
	if is_waiting_for_chest_hit_stun:
		if _is_animation_method_playing(&"is_chest_hit_animation_playing"):
			return

		chest_hit_stun_remaining = maxf(chest_hit_stun_remaining - delta, 0.0)
		if chest_hit_stun_remaining > 0.0:
			return

		is_waiting_for_chest_hit_stun = false
		is_hit_reacting = false
		return

	if is_waiting_for_knockback_stun:
		if _is_animation_method_playing(&"is_hit_playing"):
			return

		knockback_stun_remaining = maxf(knockback_stun_remaining - delta, 0.0)
		if knockback_stun_remaining > 0.0:
			return

		is_waiting_for_knockback_stun = false
		is_hit_reacting = false
		return

	if not _is_animation_method_playing(&"is_hit_playing"):
		is_hit_reacting = false


func _apply_knockback_from(
	impact_origin: Vector3,
	impact_direction: Vector3 = Vector3.ZERO
) -> void:
	var face_impact_direction := impact_origin - global_position
	face_impact_direction.y = 0.0
	if impact_direction.length_squared() > 0.01:
		face_impact_direction = -impact_direction
		face_impact_direction.y = 0.0
	elif face_impact_direction.length_squared() < 0.01:
		face_impact_direction = -global_transform.basis.z
		face_impact_direction.y = 0.0

	face_impact_direction = face_impact_direction.normalized()
	look_at(global_position + face_impact_direction, Vector3.UP)
	var back_direction := global_transform.basis.z.normalized()
	knockback_velocity = back_direction * knockback_speed


func _die() -> void:
	is_dead = true
	is_hit_reacting = false
	is_waiting_for_chest_hit_stun = false
	is_waiting_for_knockback_stun = false
	knockback_velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	_on_died()
	_play_animation_method(&"play_death")
	_update_health_label()


func _update_health_label() -> void:
	health_label.text = str(roundi(health_component.current_health))


func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_update_health_label()


func _on_health_depleted(_damage_info) -> void:
	_die()


func _play_animation_method(method_name: StringName) -> void:
	if animation_controller != null and animation_controller.has_method(method_name):
		animation_controller.call(method_name)
		return
	push_error("%s animation controller is missing %s()." % [name, method_name])


func _is_animation_method_playing(method_name: StringName) -> bool:
	if animation_controller != null and animation_controller.has_method(method_name):
		return bool(animation_controller.call(method_name))
	return false

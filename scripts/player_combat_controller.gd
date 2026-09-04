class_name PlayerCombatController
extends Node

const PUNCH_ANIMATIONS := ["Punch_01", "Punch_02", "Punch_03"]
const UPPERCUT_PUNCH_INDEX := 2
const DAMAGE_INFO_SCRIPT = preload("res://scripts/damage_info.gd")

var animation_controller: PlayerAnimationController

@export var punch_forward_speed: float = 8.0
@export var punch_forward_delay: float = 0.25
@export var punch_forward_duration: float = 0.08
@export var punch_hit_delay: float = 0.2
@export var punch_hit_distance: float = 1.6
@export var punch_hit_radius: float = 0.75
@export var regular_hit_damage_multiplier: int = 2
@export_range(0.0, 1.0, 0.01) var combo_input_window: float = 0.6
@export var uppercut_launch_velocity: float = 12.0
@export var uppercut_launch_delay: float = 0.25
@export var uppercut_forward_speed: float = 14.0
@export var uppercut_forward_duration: float = 0.15

var punch_time: float = 0.0
var is_punch_active: bool = false
var combo_punch_index: int = 0
var is_next_punch_queued: bool = false
var has_uppercut_launched: bool = false
var has_punch_hit: bool = false

func setup(target_animation_controller: PlayerAnimationController) -> void:
	animation_controller = target_animation_controller


func request_punch() -> void:
	if animation_controller == null:
		return

	if not animation_controller.is_fighting:
		_start_punch(0)
	elif animation_controller.is_fighting_animation_in_combo_window(combo_input_window):
		is_next_punch_queued = true


func update_punch_momentum(
	body: CharacterBody3D,
	delta: float,
	strength: int,
	movement_speed_multiplier: float = 1.0
) -> void:
	if not is_punch_active:
		return

	if animation_controller.has_fighting_animation_finished():
		if is_next_punch_queued:
			_start_punch((combo_punch_index + 1) % PUNCH_ANIMATIONS.size(), true)
		else:
			is_punch_active = false
		return

	if not animation_controller.is_fighting:
		is_punch_active = false
		return

	punch_time += delta
	if not has_punch_hit and punch_time >= punch_hit_delay:
		has_punch_hit = _try_hit_target(body, strength)

	var push_end_time := punch_forward_delay + punch_forward_duration
	if punch_time >= punch_forward_delay and punch_time <= push_end_time:
		var forward := -body.transform.basis.z.normalized()
		body.velocity.x = forward.x * punch_forward_speed * movement_speed_multiplier
		body.velocity.z = forward.z * punch_forward_speed * movement_speed_multiplier

	_apply_uppercut_motion(body, movement_speed_multiplier)


func _apply_uppercut_motion(body: CharacterBody3D, movement_speed_multiplier: float) -> void:
	if combo_punch_index != UPPERCUT_PUNCH_INDEX:
		return
	if punch_time < uppercut_launch_delay:
		return

	if not has_uppercut_launched:
		body.velocity.y = maxf(body.velocity.y, uppercut_launch_velocity)
		has_uppercut_launched = true

	if punch_time > uppercut_launch_delay + uppercut_forward_duration:
		return

	var forward := -body.transform.basis.z.normalized()
	body.velocity.x = forward.x * uppercut_forward_speed * movement_speed_multiplier
	body.velocity.z = forward.z * uppercut_forward_speed * movement_speed_multiplier


func _start_punch(punch_index: int, is_combo_continuation: bool = false) -> void:
	var animation_name: String = PUNCH_ANIMATIONS[punch_index]
	var did_start := (
		animation_controller.continue_fighting_animation(animation_name)
		if is_combo_continuation
		else animation_controller.play_fighting_animation(animation_name)
	)
	if not did_start:
		return

	combo_punch_index = punch_index
	is_next_punch_queued = false
	has_uppercut_launched = false
	has_punch_hit = false
	punch_time = 0.0
	is_punch_active = true


func _try_hit_target(body: CharacterBody3D, strength: int) -> bool:
	var hit_shape := SphereShape3D.new()
	hit_shape.radius = punch_hit_radius
	var forward := -body.global_transform.basis.z.normalized()
	var impact_origin := body.global_position + Vector3.UP + forward * punch_hit_distance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hit_shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		impact_origin
	)
	query.exclude = [body.get_rid()]
	var hit_results: Array[Dictionary] = body.get_world_3d().direct_space_state.intersect_shape(query)

	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if collider == null or not collider.has_method("apply_damage"):
			continue

		var hit_reaction: StringName = (
			&"knockback" if combo_punch_index == UPPERCUT_PUNCH_INDEX else &"chest"
		)
		var damage: float = regular_hit_damage_multiplier * strength
		var is_explodable: bool = (
			collider is Node and (collider as Node).is_in_group(&"explodable")
		)
		if combo_punch_index == UPPERCUT_PUNCH_INDEX and not is_explodable:
			damage *= 2.0
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			damage,
			impact_origin,
			forward,
			hit_reaction,
			body
		)
		collider.call("apply_damage", damage_info)
		return true

	return false

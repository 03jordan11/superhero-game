class_name PlayerCombatController
extends Node

const PUNCH_ANIMATIONS := ["Punch_01", "Punch_02", "Punch_03"]
const UPPERCUT_PUNCH_INDEX := 2

var animation_controller: PlayerAnimationController

@export var punch_forward_speed: float = 8.0
@export var punch_forward_delay: float = 0.25
@export var punch_forward_duration: float = 0.08
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

func setup(target_animation_controller: PlayerAnimationController) -> void:
	animation_controller = target_animation_controller


func request_punch() -> void:
	if animation_controller == null:
		return

	if not animation_controller.is_fighting:
		_start_punch(0)
	elif animation_controller.is_fighting_animation_in_combo_window(combo_input_window):
		is_next_punch_queued = true


func update_punch_momentum(body: CharacterBody3D, delta: float) -> void:
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

	var push_end_time := punch_forward_delay + punch_forward_duration
	if punch_time >= punch_forward_delay and punch_time <= push_end_time:
		var forward := -body.transform.basis.z.normalized()
		body.velocity.x = forward.x * punch_forward_speed
		body.velocity.z = forward.z * punch_forward_speed

	_apply_uppercut_motion(body)


func _apply_uppercut_motion(body: CharacterBody3D) -> void:
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
	body.velocity.x = forward.x * uppercut_forward_speed
	body.velocity.z = forward.z * uppercut_forward_speed


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
	punch_time = 0.0
	is_punch_active = true

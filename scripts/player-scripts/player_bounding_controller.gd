class_name PlayerBoundingController
extends Node

## Landing timing and momentum for Bounding. Driven by the player physics loop.
@export_range(0.05, 0.5, 0.01) var landing_window: float = 0.25
@export_range(0.0, 0.25, 0.01) var input_buffer: float = 0.12
@export_range(1.0, 100.0, 1.0) var minimum_horizontal_speed: float = 16.0
@export_range(1.0, 100.0, 1.0) var minimum_downward_speed: float = 12.0
@export_range(0.1, 0.99, 0.01) var momentum_retention: float = 0.9
@export_range(0.1, 10.0, 0.1) var air_drag: float = 1.0

var window_remaining: float = 0.0
var buffer_remaining: float = 0.0
var launched_this_tick: bool = false
var _consume_until_release: bool = false
var _buffered_landing: bool = false
@onready var player: PlayerCharacter = get_parent()


func _ready() -> void:
	get_node("/root/GameSettings").input_bindings.changed.connect(reset)
	get_node("/root/GameSettings").input_bindings.controller_disconnected.connect(reset)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()


func reset() -> void:
	window_remaining = 0.0
	buffer_remaining = 0.0
	launched_this_tick = false
	_consume_until_release = false
	_buffered_landing = false


func _allowed() -> bool:
	return (
		player.abilities.is_unlocked(PlayerAbilities.BOUNDING)
		and not player.is_flying and not player.is_ground_slamming
		and not player.ground_slam_impact_pending and not player.is_wall_running
		and not player.is_dead and not player.is_knocked_out
		and not player.combat_controller.is_action_locked()
	)


func begin_tick(delta: float) -> void:
	launched_this_tick = false
	if not _allowed():
		reset()
		return
	window_remaining = maxf(window_remaining - delta, 0.0)
	buffer_remaining = maxf(buffer_remaining - delta, 0.0)
	if not player.is_on_floor():
		window_remaining = 0.0
		_buffered_landing = false


func qualifies(landing_velocity: Vector3) -> bool:
	return (
		Vector2(landing_velocity.x, landing_velocity.z).length() >= minimum_horizontal_speed
		and -landing_velocity.y >= minimum_downward_speed
	)


func after_move(was_grounded: bool, incoming_velocity: Vector3, excluded: bool) -> void:
	if excluded or not _allowed():
		reset()
		return
	if player.is_on_floor() and not was_grounded:
		window_remaining = landing_window if qualifies(incoming_velocity) else 0.0
		# Latch a timely tap at contact, before the next tick can expire it.
		_buffered_landing = window_remaining > 0.0 and buffer_remaining > 0.0
		# Collision-resolved momentum is used for launch, never a cached speed
		# that could restore velocity lost to a wall on this landing.
		if window_remaining == 0.0:
			buffer_remaining = 0.0


func handle_jump(input: PlayerInputSnapshot) -> bool:
	launched_this_tick = false
	if not _allowed():
		return false
	if _consume_until_release:
		if not input.jump_pressed:
			_consume_until_release = false
		return true
	if player.is_on_floor():
		if window_remaining > 0.0 and (input.jump_just_pressed or _buffered_landing):
			var launched := _launch()
			_consume_until_release = launched and input.jump_pressed
			return launched
	elif input.jump_just_pressed and _landing_is_close():
		# Near a qualifying landing, the tap belongs to Bounding instead of
		# consuming Air Jump. Farther from the floor, Air Jump stays immediate.
		buffer_remaining = input_buffer
		return true
	return false


func _landing_is_close() -> bool:
	if input_buffer <= 0.0 or not qualifies(player.velocity):
		return false
	var hit := KinematicCollision3D.new()
	var motion := player.velocity * input_buffer + Vector3.DOWN * player.gravity * input_buffer * input_buffer * 0.5
	if not player.test_move(player.global_transform, motion, hit):
		return false
	return hit.get_normal().dot(player.up_direction) >= cos(player.floor_max_angle)


func _launch() -> bool:
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal.length() < minimum_horizontal_speed:
		window_remaining = 0.0
		buffer_remaining = 0.0
		return false
	var full_jump := player.movement_motor.get_charged_jump_velocity(
		Vector3.ZERO, -player.transform.basis.z, 1.0,
		player.min_jump_velocity, player.max_jump_velocity,
		player.max_forward_jump_boost,
		player.status_effects.get_movement_speed_multiplier(),
		player.charged_jump_output_multiplier
	)
	player.velocity = horizontal * clampf(momentum_retention, 0.0, 0.99)
	player.velocity.y = full_jump.y
	player.is_jump_active = true
	player.jump_hold_time = 0.0
	player.jump_charge = 0.0
	player.is_charging_jump = false
	player.jump_charge_changed.emit(0.0, player.max_jump_charge_time)
	window_remaining = 0.0
	buffer_remaining = 0.0
	_buffered_landing = false
	launched_this_tick = true
	return true


func preserve_momentum(direction: Vector3, target_speed: float, acceleration: float, delta: float) -> bool:
	if not _allowed() or player.is_charging_jump:
		return false
	if player.is_on_floor() and window_remaining <= 0.0:
		return false
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var speed := horizontal.length()
	if speed < minimum_horizontal_speed or player.status_effects.get_movement_speed_multiplier() < 1.0:
		return false
	# Coasting loses a little speed even with no input. Steering uses the
	# existing acceleration, so reversing direction brakes instead of snapping.
	var coast_speed := maxf(speed - air_drag * delta, 0.0)
	if direction.is_zero_approx():
		direction = horizontal.normalized()
	var next := horizontal.move_toward(direction * maxf(target_speed, coast_speed), acceleration * delta)
	player.velocity.x = next.x
	player.velocity.z = next.z
	return true

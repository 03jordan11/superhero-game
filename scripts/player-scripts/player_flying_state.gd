class_name PlayerFlyingState
extends PlayerState

## Owns flight eligibility, lifecycle, movement, orientation, and collision exit.

var _last_published_speed: float = -1.0
var _last_published_max_speed: float = -1.0
var _button_pending := false
var _hold_time := 0.0
var _charge_eligible := false
var surge_remaining := 0.0
var is_boosting := false


# Also called while grounded/airborne so holding F never toggles flight early.
func handle_flight_input(delta: float, input: PlayerInputSnapshot) -> void:
	if not player.abilities.is_unlocked(PlayerAbilities.FLIGHT_SURGE):
		cancel_charge()
		if input.toggle_flight_just_pressed: player._toggle_flight_state()
		return
	if not _can_charge_here():
		cancel_charge()
		if input.toggle_flight_just_pressed: player._toggle_flight_state()
		return
	if input.toggle_flight_just_pressed:
		_button_pending = true
		_hold_time = 0.0
		_charge_eligible = player.stamina.is_full() and surge_remaining <= 0.0
	if not _button_pending: return
	# A suppressed input snapshot (menus, focus loss) must cancel, never launch.
	if not input.flight_pressed and not input.flight_just_released:
		cancel_charge()
		return
	if input.flight_pressed:
		_hold_time += delta
		_charge_eligible = _charge_eligible and player.stamina.is_full()
		if _hold_time >= player.flight_charge_hold_threshold:
			player.is_charging_flight = _charge_eligible
			player.flight_charge_changed.emit(true, _charge_ratio(), _charge_eligible)
	if input.flight_just_released:
		var was_tap := _hold_time < player.flight_charge_hold_threshold
		var launch := not was_tap and _charge_eligible and player.stamina.is_full()
		var ratio := _charge_ratio()
		var direction := Vector3.UP if player.is_on_floor() else player.superhero_character.global_basis.z.normalized()
		cancel_charge()
		if was_tap:
			player._toggle_flight_state()
		elif launch:
			_launch_surge(direction, ratio)


func _can_charge_here() -> bool:
	return player.abilities.is_unlocked(PlayerAbilities.FLIGHT) and not (
		player.is_dead or player.is_knocked_out or player.is_ground_slamming
		or player.is_wall_running or player.is_charging_jump
		or player.combat_controller.is_action_locked()
	)


func _charge_ratio() -> float:
	return clampf((_hold_time - player.flight_charge_hold_threshold) / maxf(player.flight_charge_time, 0.001), 0.0, 1.0)


func cancel_charge() -> void:
	var was_pending := _button_pending
	_button_pending = false
	_hold_time = 0.0
	_charge_eligible = false
	if player != null:
		player.is_charging_flight = false
		if was_pending: player.flight_charge_changed.emit(false, 0.0, false)


func _launch_surge(direction: Vector3, ratio: float) -> void:
	if not player.is_flying and not state_machine.transition_to(&"FlyingState"): return
	if not player.stamina.spend_full_bar(): return
	var speed := lerpf(player.flight_surge_min_speed, player.flight_surge_max_speed, ratio)
	player.velocity = direction * speed * player.status_effects.get_movement_speed_multiplier()
	player.current_flight_speed = player.velocity.length()
	surge_remaining = player.flight_surge_duration
	_publish_flight_speed(true)


func can_enter(_previous_state: PlayerState, _context: Dictionary = {}) -> bool:
	return (
		player.abilities != null
		and player.abilities.is_unlocked(PlayerAbilities.FLIGHT)
		and not player.is_ground_slamming
		and not player.is_knocked_out
		and not player.is_dead
		and not player.hostile_grab.blocks_motion()
	)


func enter(_previous_state: PlayerState, _context: Dictionary = {}) -> void:
	player.is_flying = true
	player.velocity.y = 0.0
	player.current_flight_speed = _get_walk_speed()
	player.jump_charge = 0.0
	player.jump_hold_time = 0.0
	player.is_charging_jump = false
	player.is_jump_active = false
	player.landing_impact_controller.reset_normal_landing_tracking()
	player.jump_charge_changed.emit(0.0, player.max_jump_charge_time)
	_publish_flight_speed(true)


func exit(_next_state: PlayerState) -> void:
	is_boosting = false
	cancel_charge()
	surge_remaining = 0.0
	player.is_flying = false
	player.current_ground_speed = _get_walk_speed()
	player.flight_speed_changed.emit(0.0, _get_run_speed(), false)


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	is_boosting = false
	if surge_remaining > 0.0:
		surge_remaining = maxf(surge_remaining - delta, 0.0)
		# Preserve the launch impulse before returning to ordinary exhausted flight.
		player.current_flight_speed = player.velocity.length()
		_update_visual_rotation(delta)
		_publish_flight_speed()
		return
	if player.is_charging_flight:
		player.velocity = player.movement_motor.approach_hover_velocity(player.velocity, player.flight_stop_deceleration, 1.0, delta)
		player.current_flight_speed = player.velocity.length()
		# Retain the character's facing direction for the launch, even at a hover.
		_publish_flight_speed()
		return
	var vertical_input := 0.0
	if input.jump_pressed:
		vertical_input += 1.0
	if input.descend_pressed:
		vertical_input -= 1.0

	var flight_direction := player.movement_motor.get_flight_direction(
		input.movement,
		vertical_input,
		player.camera.global_transform.basis
	)
	var has_flight_input := flight_direction.length_squared() > 0.0
	is_boosting = has_flight_input and input.sprint_pressed and player.abilities.is_unlocked(PlayerAbilities.FLIGHT_BOOST) and player.stamina.request_boost(true)
	var speed_multiplier := player.status_effects.get_movement_speed_multiplier()
	var attribute_speed_multiplier := _get_speed_attribute_multiplier() if is_boosting else 1.0
	var input_strength := minf(maxf(input.movement.length(), absf(vertical_input)), 1.0)
	var current_base_flight_speed := _get_walk_speed() * speed_multiplier * input_strength
	var current_max_flight_speed := _get_run_speed() * speed_multiplier * input_strength

	if has_flight_input:
		player.current_flight_speed = player.movement_motor.approach_flight_speed(
			player.current_flight_speed,
			current_base_flight_speed,
			current_max_flight_speed,
			is_boosting,
			player.flight_acceleration,
			player.flight_deceleration,
			attribute_speed_multiplier,
			delta
		)
		player.velocity = flight_direction * player.current_flight_speed
	else:
		player.velocity = player.movement_motor.approach_hover_velocity(
			player.velocity,
			player.flight_stop_deceleration,
			attribute_speed_multiplier,
			delta
		)
		if player.velocity.length() <= player.flight_hover_speed_threshold:
			player.velocity = Vector3.ZERO
		player.current_flight_speed = player.velocity.length()

	_update_visual_rotation(delta)
	_publish_flight_speed()


func post_physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	if (
		player.current_flight_speed < _get_run_speed() * player.flight_knockout_speed_percent
		or player.get_slide_collision_count() <= 0
	):
		return

	var collision := player.get_slide_collision(0)
	var context := {
		"cause": &"flight_collision",
		"collision_normal": collision.get_normal(),
		"collision_position": collision.get_position(),
		"impact_speed": player.current_flight_speed,
	}
	if not state_machine.transition_to(&"KnockedDownState", context):
		push_error("Player could not enter KnockedDownState from a flight collision.")


func _update_visual_rotation(delta: float) -> void:
	var flight_direction := player.velocity.normalized()
	# Hover/cruise retain an upright silhouette, including vertical movement.
	# The horizontal rocket pose aligns fully with velocity only during fast flight.
	if not is_boosting and surge_remaining <= 0.0:
		flight_direction.y = 0.0
		flight_direction = flight_direction.normalized()
	var target_rotation: Quaternion
	if flight_direction.length_squared() == 0.0:
		target_rotation = player.global_transform.basis.get_rotation_quaternion() * (
			Basis.from_euler(
				player.superhero_character_default_rotation
			).get_rotation_quaternion()
		)
	else:
		var reference_up := Vector3.UP
		if absf(flight_direction.dot(reference_up)) > 0.98:
			reference_up = Vector3.FORWARD
		var right := reference_up.cross(flight_direction).normalized()
		var up := flight_direction.cross(right).normalized()
		target_rotation = Basis(right, up, flight_direction).get_rotation_quaternion()

	var current_rotation := (
		player.superhero_character.global_transform.basis.get_rotation_quaternion()
	)
	var rotation_weight := minf(player.flight_turn_speed * delta, 1.0)
	var character_transform := player.superhero_character.global_transform
	character_transform.basis = Basis(
		current_rotation.slerp(target_rotation, rotation_weight)
	)
	player.superhero_character.global_transform = character_transform


func _publish_flight_speed(force: bool = false) -> void:
	var current_speed := player.velocity.length()
	var max_speed := _get_run_speed()
	if (
		not force
		and is_equal_approx(current_speed, _last_published_speed)
		and is_equal_approx(max_speed, _last_published_max_speed)
	):
		return
	_last_published_speed = current_speed
	_last_published_max_speed = max_speed
	player.flight_speed_changed.emit(current_speed, max_speed, true)

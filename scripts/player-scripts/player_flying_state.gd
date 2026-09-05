class_name PlayerFlyingState
extends PlayerState

## Owns flight eligibility, lifecycle, movement, orientation, and collision exit.

var _last_published_speed: float = -1.0
var _last_published_max_speed: float = -1.0


func can_enter(_previous_state: PlayerState, _context: Dictionary = {}) -> bool:
	return (
		player.abilities != null
		and player.abilities.is_unlocked(PlayerAbilities.FLIGHT)
		and not player.is_ground_slamming
		and not player.is_knocked_out
		and not player.is_dead
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
	player.is_flying = false
	player.current_ground_speed = _get_walk_speed()
	player.flight_speed_changed.emit(0.0, _get_run_speed(), false)


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
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
	var speed_multiplier := player.status_effects.get_movement_speed_multiplier()
	var attribute_speed_multiplier := _get_speed_attribute_multiplier()
	var current_base_flight_speed := _get_walk_speed() * speed_multiplier
	var current_max_flight_speed := _get_run_speed() * speed_multiplier

	if has_flight_input:
		player.current_flight_speed = player.movement_motor.approach_flight_speed(
			player.current_flight_speed,
			current_base_flight_speed,
			current_max_flight_speed,
			input.sprint_pressed,
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

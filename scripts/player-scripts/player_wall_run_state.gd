class_name PlayerWallRunState
extends PlayerState

## Owns wall-run eligibility, velocity, wall probing, jumping, and exit.


func can_enter(_previous_state: PlayerState, context: Dictionary = {}) -> bool:
	var input := context.get("input_snapshot") as PlayerInputSnapshot
	if (
		player.abilities == null
		or not player.abilities.is_unlocked(PlayerAbilities.WALL_RUN)
		or player.is_flying
		or player.is_ground_slamming
		or player.is_knocked_out
		or player.is_dead
		or player.is_wall_running
		or input == null
		or not input.sprint_pressed
		or input.movement.length_squared() == 0.0
		or not context.has("collision_normal")
	):
		return false

	var collision_normal: Vector3 = context["collision_normal"]
	return collision_normal != Vector3.ZERO and absf(collision_normal.y) < 0.7


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player.is_wall_running = true
	player.wall_run_normal = context["collision_normal"]
	player.wall_run_has_left_ground = false
	player.velocity = _get_wall_run_velocity(context["input_snapshot"])


func exit(_next_state: PlayerState) -> void:
	player.is_wall_running = false
	player.wall_run_has_left_ground = false


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	if input.movement.length_squared() == 0.0:
		_finish_wall_run()
		player.velocity = player.movement_motor.apply_gravity(
			player.velocity,
			player.gravity,
			delta
		)
		return

	if input.jump_just_pressed:
		player.velocity = (
			player.wall_run_normal * player.wall_jump_push
			+ Vector3.UP * player.wall_jump_velocity
		)
		player.is_jump_active = true
		_finish_wall_run()
		return

	var current_wall_normal := _get_wall_collision_normal()
	if (
		current_wall_normal == Vector3.ZERO
		or current_wall_normal.dot(player.wall_run_normal)
			< player.wall_run_corner_normal_threshold
	):
		_finish_wall_run()
		player.velocity = player.movement_motor.apply_gravity(
			player.velocity,
			player.gravity,
			delta
		)
		return

	player.wall_run_normal = current_wall_normal
	player.velocity = _get_wall_run_velocity(input)


func post_physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	if not player.is_on_floor():
		player.wall_run_has_left_ground = true
	elif player.wall_run_has_left_ground:
		_finish_wall_run()


func _get_wall_run_velocity(input: PlayerInputSnapshot) -> Vector3:
	var lateral_input := input.lateral_movement
	if not input.sprint_pressed:
		lateral_input = 0.0

	return player.movement_motor.get_wall_run_velocity(
		player.wall_run_normal,
		player.transform.basis.x,
		lateral_input,
		player.wall_run_speed,
		player.wall_run_stick_speed,
		player.wall_run_side_speed,
		_get_speed_attribute_multiplier(),
		player.status_effects.get_movement_speed_multiplier()
	)


func _get_wall_collision_normal() -> Vector3:
	for collision_index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(collision_index)
		var collision_normal := collision.get_normal()
		if absf(collision_normal.y) < 0.7:
			return collision_normal
	return Vector3.ZERO


func _finish_wall_run() -> void:
	var destination := &"GroundedState" if player.is_on_floor() else &"AirborneState"
	if not state_machine.transition_to(destination):
		push_error("Player could not leave WallRunState.")

class_name PlayerGroundSlamState
extends PlayerState

## Owns ground-slam eligibility, descent, impact detection, and exit.


func can_enter(_previous_state: PlayerState, context: Dictionary = {}) -> bool:
	if (
		player.abilities == null
		or not player.abilities.is_unlocked(PlayerAbilities.GROUND_SLAM)
		or player.is_ground_slamming
		or player.is_knocked_out
		or player.is_dead
		or (not player.is_flying and not player.is_jump_active)
		or not context.has("target_position")
	):
		return false

	var target_position: Vector3 = context["target_position"]
	return (
		player.global_position.y - target_position.y
		>= player.ground_slam_minimum_height
	)


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player.is_flying = false
	player.is_jump_active = false
	player.is_ground_slamming = true
	player.ground_slam_target = context["target_position"]
	player.current_flight_speed = 0.0
	player.jump_charge = 0.0
	player.jump_hold_time = 0.0
	player.is_charging_jump = false


func exit(_next_state: PlayerState) -> void:
	player.is_ground_slamming = false


func physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	player.velocity = player.movement_motor.get_ground_slam_velocity(
		player.global_position,
		player.ground_slam_target,
		player.ground_slam_speed,
		_get_speed_attribute_multiplier()
	)


func post_physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	if not (
		player.is_on_floor()
		or player.get_slide_collision_count() > 0
		or player.global_position.distance_to(player.ground_slam_target) <= 0.1
	):
		return
	_finish_ground_slam()


func _finish_ground_slam() -> void:
	player.ground_slam_impact_pending = true
	player.velocity = Vector3.ZERO
	var destination := &"GroundedState" if player.is_on_floor() else &"AirborneState"
	if not state_machine.transition_to(destination):
		push_error("Player could not leave GroundSlamState.")

class_name PlayerJumpChargingState
extends PlayerNormalMovementState

## Owns charged-jump eligibility and lifecycle.


func can_enter(previous_state: PlayerState, _context: Dictionary = {}) -> bool:
	return (
		previous_state is PlayerGroundedState
		and player.abilities != null
		and player.abilities.is_unlocked(PlayerAbilities.POWER_JUMP)
		and not player.combat_controller.is_action_locked()
		and not player.is_flying
		and not player.is_ground_slamming
		and not player.is_wall_running
		and not player.is_knocked_out
		and not player.is_dead
	)


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player.is_charging_jump = true
	player.jump_charge = minf(
		player.jump_charge + float(context.get("initial_charge_delta", 0.0)),
		player.max_jump_charge_time
	)
	_publish_movement_changes(true)


func exit(_next_state: PlayerState) -> void:
	_reset_jump_charge()

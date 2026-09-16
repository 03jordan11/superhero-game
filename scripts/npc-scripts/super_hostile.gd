class_name SuperHostile
extends "res://scripts/npc-scripts/melee_hostile.gd"
## Shares the melee queue, but owns an exclusive turn until death or target loss.

func wants_exclusive_melee_turn() -> bool:
	return true

func receive_alert(target: Node3D) -> void:
	# Ally alerts/damage cannot redirect an active super off its duel target.
	if has_attack_slot and is_instance_valid(combat_target) and _can_target(combat_target) and target != combat_target:
		return
	super(target)

func _reset_combat_actions() -> void:
	if not has_attack_slot or is_dead or not is_instance_valid(combat_target) or not _can_target(combat_target):
		super()
		return
	# Combo pauses and hit reactions interrupt swings, not the exclusive turn.
	melee_state = MeleeState.APPROACH
	combo_length = 0
	punches_started = 0
	punch_elapsed = 0.0
	punch_resolved = true
	recovery_remaining = combo_recovery_time

func _handle_combat(delta: float) -> void:
	if not is_instance_valid(combat_target):
		combat_target = null
	if not has_attack_slot or not _can_target(combat_target):
		super(delta)
		return
	# Distance, cover and jumping do not surrender a living super's turn.
	if _can_see_target(combat_target):
		_remember_target_position()
	_face_combat_target()
	_update_combat(delta)

func _update_combat(delta: float) -> void:
	if not has_attack_slot:
		super(delta)
		return
	recovery_remaining = maxf(recovery_remaining - delta, 0.0)
	if melee_state == MeleeState.ATTACK:
		_update_attack(delta)
		return
	if _in_punch_range() and _can_see_target(combat_target):
		if recovery_remaining <= 0.0:
			_start_combo()
		else:
			_hold_position()
	elif absf(combat_target.global_position.y - global_position.y) <= attack_height_tolerance:
		_move_toward_point(combat_target.global_position, approach_speed, delta)
	else:
		_hold_position()

extends RefCounted
## Frost clocks use game seconds, independently of the victim's action slowdown.
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const ICE = preload("res://effects/frozen_ice.gd")
var frozen := false
var buildup := 0.0
var remaining := 0.0
var melee_hits := 0
var freeze_seconds := 3.0
var thaw_rate := 1.0
var frozen_seconds := 5.0
var breath_damage := 5.0
var frozen_damage := 10.0
var minimum_speed := 0.15
var enemy
var source: Node3D
var effect: MeshInstance3D
var _exposure := 0.0
var _tick_time := 0.0
var _animation: AnimationPlayer
var _base_animation_speed := 1.0
var _previous_state := 0

func receive(victim, instigator: Node3D, seconds: float, tuning: Node) -> void:
	if victim.is_dead or victim.is_grabbed or victim.is_thrown or seconds <= 0.0: return
	if victim.electrified.active: victim.electrified.cancel()
	if enemy == null:
		enemy = victim
		_animation = enemy.animation_controller.animation_player
		_base_animation_speed = _animation.speed_scale
		if not is_instance_valid(enemy.combat_target): enemy.receive_alert(instigator)
	source = instigator
	freeze_seconds = tuning.super_freeze_seconds if victim is SuperHostile else tuning.freeze_seconds
	thaw_rate = tuning.thaw_rate
	frozen_seconds = tuning.frozen_seconds
	breath_damage = tuning.damage_per_second
	frozen_damage = tuning.frozen_damage_per_second
	minimum_speed = tuning.minimum_action_speed
	_exposure += seconds

func action_speed() -> float:
	if frozen: return 0.0
	return lerpf(1.0, minimum_speed, clampf(buildup / maxf(freeze_seconds, 0.001), 0.0, 1.0))

func update(delta: float) -> void:
	if enemy == null or delta <= 0.0: return
	if enemy.is_dead or enemy.is_grabbed or enemy.is_thrown:
		cancel()
		return
	var contact := minf(_exposure, delta)
	_exposure = 0.0
	var outside := delta - contact
	if contact > 0.0:
		if not frozen:
			var building := minf(contact, maxf(0.0, freeze_seconds - buildup))
			buildup += building
			_damage(breath_damage * building, &"frost_breath")
			if enemy == null: return # Lethal damage clears the status synchronously.
			contact -= building
			if buildup >= freeze_seconds - 0.00001: _freeze()
		if frozen:
			# Refresh only expiry, not damage ticks or the melee hit counter.
			remaining = frozen_seconds
			_frozen_ticks(contact)
			if enemy == null: return
	if frozen:
		var frozen_time := minf(outside, remaining)
		remaining = maxf(0.0, remaining - frozen_time)
		_frozen_ticks(frozen_time)
		if enemy == null: return
		if remaining <= 0.00001: cancel()
	else:
		buildup = maxf(0.0, buildup - outside * thaw_rate)
	if enemy != null:
		enemy.action_speed = action_speed()
		_animation.speed_scale = _base_animation_speed * action_speed()
		if buildup <= 0.0 and not frozen: cancel()

func _freeze() -> void:
	frozen = true
	remaining = frozen_seconds
	_tick_time = 0.0
	melee_hits = 0
	_previous_state = enemy.current_state
	enemy._reset_combat_actions()
	enemy.velocity = Vector3.ZERO
	enemy.knockback_velocity = Vector3.ZERO
	enemy.is_hit_reacting = false
	enemy.is_waiting_for_chest_hit_stun = false
	enemy.is_waiting_for_knockback_stun = false
	enemy.current_state = enemy.State.FROZEN
	effect = ICE.new()
	enemy.add_child(effect)
	effect.encase(enemy)

func _frozen_ticks(seconds: float) -> void:
	_tick_time += seconds
	while frozen and _tick_time >= 1.0 - 0.00001:
		_tick_time -= 1.0
		_damage(frozen_damage, &"frozen")

func _damage(amount: float, kind: StringName) -> void:
	if amount <= 0.0: return
	var info = DAMAGE.new(amount, enemy.global_position, Vector3.ZERO, &"none", source if is_instance_valid(source) else null)
	info.damage_type = kind
	enemy.health_component.apply_damage(info)

func melee_hit() -> void:
	if not frozen: return
	melee_hits += 1
	if melee_hits >= 3: cancel()
	elif is_instance_valid(effect): effect.hit(melee_hits)

func cancel() -> void:
	if is_instance_valid(_animation): _animation.speed_scale = _base_animation_speed
	if is_instance_valid(enemy):
		enemy.action_speed = 1.0
		if frozen and enemy.current_state == enemy.State.FROZEN: enemy.current_state = _previous_state
	if is_instance_valid(effect): effect.shatter()
	effect = null
	frozen = false
	buildup = 0.0
	remaining = 0.0
	_exposure = 0.0
	_tick_time = 0.0
	melee_hits = 0
	enemy = null
	source = null
	_animation = null

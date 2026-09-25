extends RefCounted
## A timed immobilization, advanced by the hostile's scaled physics clock.
const EFFECT = preload("res://effects/electrified.tscn")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var active := false
var elapsed := 0.0
var duration := 2.5
var tick_damage := 15.0
var end_damage := 10.0
var next_tick := 1.0
var enemy
var source: Node3D
var effect: Node3D
var _animation: AnimationPlayer
var _animation_speed := 1.0
var _previous_state: int

func begin(victim, instigator: Node3D, seconds: float, per_tick: float, on_end: float) -> bool:
	if active or victim.is_dead or victim.is_grabbed or victim.is_thrown: return false
	victim.frost.cancel()
	enemy = victim
	source = instigator
	duration = seconds
	tick_damage = per_tick
	end_damage = on_end
	elapsed = 0.0
	next_tick = 1.0
	_previous_state = enemy.current_state
	enemy._reset_combat_actions()
	enemy.velocity = Vector3.ZERO
	enemy.knockback_velocity = Vector3.ZERO
	enemy.is_hit_reacting = false
	enemy.is_waiting_for_chest_hit_stun = false
	enemy.is_waiting_for_knockback_stun = false
	_animation = enemy.animation_controller.animation_player
	_animation_speed = _animation.speed_scale
	_animation.speed_scale = 0.0
	enemy.current_state = enemy.State.ELECTRIFIED
	active = true
	effect = EFFECT.instantiate()
	enemy.add_child(effect)
	var collision: CollisionShape3D = enemy.get_node_or_null("CollisionShape3D")
	if collision != null and collision.shape is CapsuleShape3D:
		effect.scale = Vector3.ONE * (collision.shape.height / 1.75)
	effect.start()
	return true

func update(delta: float) -> void:
	if not active: return
	elapsed = minf(elapsed + delta, duration)
	# Catch every whole-second tick, even if a long frame crosses two boundaries.
	while active and next_tick <= elapsed and next_tick < duration:
		next_tick += 1.0
		_damage(tick_damage)
	if active and elapsed >= duration:
		_damage(end_damage)
		cancel()

func _damage(amount: float) -> void:
	var info = DAMAGE.new(amount, enemy.global_position, Vector3.ZERO, &"none", source if is_instance_valid(source) else null)
	info.damage_type = &"reactive_shock"
	# Status ticks must neither cancel themselves as a player attack nor flinch
	# the frozen victim. Health depletion still runs the normal death/reward path.
	enemy.health_component.apply_damage(info)

func cancel() -> void:
	if not active: return
	active = false
	if is_instance_valid(_animation): _animation.speed_scale = _animation_speed
	if is_instance_valid(effect):
		effect.hide()
		effect.queue_free()
	effect = null
	if is_instance_valid(enemy) and enemy.current_state == enemy.State.ELECTRIFIED:
		enemy.current_state = _previous_state
	source = null

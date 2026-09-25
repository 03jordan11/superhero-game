class_name PlayerStamina
extends Node
## Boost requests come from movement states; drain uses actual movement after collisions.
signal changed(current: float, maximum: float, exhausted: bool)

@export_range(0.1, 100.0, 0.1) var stamina_per_resilience: float = 10.0
@export_range(0.1, 100.0, 0.1) var drain_per_second: float = 20.0
@export_range(0.1, 100.0, 0.1) var regeneration_per_second: float = 20.0
@export_range(0.0, 10.0, 0.1) var regeneration_delay: float = 1.0
@export_range(0.01, 1.0, 0.01) var exhaustion_recovery_fraction: float = 0.2

var current: float = 0.0
var maximum: float = 1.0
var exhausted: bool = false
var running_drain_multiplier: float = 1.0
var _recovery_delay: float = 0.0
var _boost_requested: bool = false
var _sprint_requested: bool = false
var _flight_boost: bool = false
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	maximum = maxf(float(player.stats.resilience) * stamina_per_resilience, 1.0)
	current = maximum
	player.stats.stat_changed.connect(_on_stat_changed)

func _on_stat_changed(id: StringName, _value: int) -> void:
	if id != PlayerStats.RESILIENCE: return
	maximum = maxf(float(player.stats.resilience) * stamina_per_resilience, 1.0)
	# Added capacity refills through normal regeneration, not repeated stat edits.
	current = minf(current, maximum)
	_refresh_exhaustion()
	changed.emit(current, maximum, exhausted)

func can_boost() -> bool:
	return not exhausted and current > 0.0

func is_full() -> bool:
	return not exhausted and current >= maximum

func spend_full_bar() -> bool:
	if not is_full(): return false
	current = 0.0
	exhausted = true
	_recovery_delay = regeneration_delay
	changed.emit(current, maximum, exhausted)
	return true

func restore_full() -> void:
	current = maximum
	exhausted = false
	_recovery_delay = 0.0
	begin_tick()
	changed.emit(current, maximum, exhausted)


func spend_fraction(fraction: float) -> bool:
	var cost := maximum * clampf(fraction, 0.0, 1.0)
	if current < cost: return false
	current = maxf(0.0, current - cost)
	_recovery_delay = regeneration_delay
	_refresh_exhaustion()
	changed.emit(current, maximum, exhausted)
	return true

func begin_tick(sprint_requested: bool = false) -> void:
	_boost_requested = false
	_flight_boost = false
	_sprint_requested = sprint_requested

func request_boost(is_flight: bool) -> bool:
	_sprint_requested = true
	if not can_boost(): return false
	_boost_requested = true
	_flight_boost = is_flight
	return true

func finish_tick(delta: float, displacement: Vector3, grounded: bool) -> void:
	if player.is_dead or delta <= 0.0: return
	if player.is_dodging or player.anticipation.active():
		_recovery_delay = regeneration_delay
		return
	# Ordinary airborne movement freezes both the bar and recovery delay.
	# Flight keeps its existing boost drain and unboosted regeneration.
	if not grounded and not player.is_flying: return
	var previous := current
	var was_exhausted := exhausted
	var distance := displacement.length() if _flight_boost else Vector2(displacement.x, displacement.z).length()
	if _boost_requested and distance > 0.001 * delta:
		var rate := drain_per_second * (1.0 if _flight_boost else running_drain_multiplier)
		current = maxf(current - maxf(rate, 0.0) * delta, 0.0)
		_recovery_delay = regeneration_delay
	elif _sprint_requested:
		# Exhaustion, coasting and blocked movement cannot recharge a held boost.
		_recovery_delay = regeneration_delay
	else:
		var recovery_time := maxf(delta - _recovery_delay, 0.0)
		_recovery_delay = maxf(_recovery_delay - delta, 0.0)
		current = minf(current + regeneration_per_second * recovery_time, maximum)
	_refresh_exhaustion()
	if not is_equal_approx(previous, current) or was_exhausted != exhausted:
		changed.emit(current, maximum, exhausted)

func _refresh_exhaustion() -> void:
	if current <= 0.0: exhausted = true
	elif exhausted and current >= maximum * exhaustion_recovery_fraction: exhausted = false

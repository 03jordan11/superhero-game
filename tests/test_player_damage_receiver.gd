extends SceneTree

const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")

var received_slowdown_multiplier := 0.0
var death_requested := false


func _initialize() -> void:
	var receiver := PlayerDamageReceiver.new()
	var status_effects := PlayerStatusEffects.new()
	var combat_controller := PlayerCombatController.new()
	var animation_controller := PlayerAnimationController.new()
	receiver.setup(100.0, status_effects, combat_controller, animation_controller)

	receiver.hit_slowdown_requested.connect(
		func(speed_multiplier: float) -> void:
			received_slowdown_multiplier = speed_multiplier
	)
	receiver.death_requested.connect(
		func(_damage_info) -> void:
			death_requested = true
	)

	var regular_damage = DAMAGE_INFO_SCRIPT.new(20.0)
	assert(receiver.apply_damage(regular_damage, false, 0.0, false))
	assert(is_equal_approx(receiver.get_current_health(), 80.0))
	assert(is_equal_approx(received_slowdown_multiplier, 0.5))
	assert(is_equal_approx(status_effects.get_movement_speed_multiplier(), 0.5))
	assert(not death_requested)

	var fatal_damage = DAMAGE_INFO_SCRIPT.new(80.0)
	assert(receiver.apply_damage(fatal_damage, false, 0.0, false))
	assert(is_equal_approx(receiver.get_current_health(), 0.0))
	assert(death_requested)
	assert(not receiver.apply_damage(DAMAGE_INFO_SCRIPT.new(1.0), false, 0.0, false))

	receiver.free()
	status_effects.free()
	combat_controller.free()
	animation_controller.free()
	print("PASS: PlayerDamageReceiver health and damage consequences")
	quit()

extends SceneTree


func _initialize() -> void:
	var status_effects := PlayerStatusEffects.new()
	assert(is_equal_approx(status_effects.get_movement_speed_multiplier(), 1.0))

	status_effects.hit_slowdown_duration = 0.5
	status_effects.hit_slowdown_multiplier = 0.5
	assert(is_equal_approx(status_effects.apply_hit_slowdown(), 0.5))
	assert(is_equal_approx(status_effects.hit_slowdown_remaining, 0.5))

	status_effects.update(0.2)
	assert(is_equal_approx(status_effects.hit_slowdown_remaining, 0.3))
	assert(is_equal_approx(status_effects.get_movement_speed_multiplier(), 0.5))

	status_effects.update(0.3)
	assert(is_equal_approx(status_effects.hit_slowdown_remaining, 0.0))
	assert(is_equal_approx(status_effects.get_movement_speed_multiplier(), 1.0))

	status_effects.hit_slowdown_duration = -1.0
	status_effects.hit_slowdown_multiplier = 2.0
	assert(is_equal_approx(status_effects.apply_hit_slowdown(), 1.0))
	assert(is_equal_approx(status_effects.hit_slowdown_remaining, 0.0))

	status_effects.free()
	print("PASS: PlayerStatusEffects hit-slowdown timing and multiplier")
	quit()

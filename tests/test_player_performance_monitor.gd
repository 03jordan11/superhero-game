extends SceneTree

const MONITOR = preload("res://scripts/ui-scripts/player_performance_monitor.gd")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	preload("res://tests/player_test_support.gd").unlock_current_powers(main.get_node("Player"))
	current_scene = main
	assert(main.has_node("PerformanceMonitors/CombatPerformanceMonitor"))
	var monitor := main.get_node("PerformanceMonitors/PlayerPerformanceMonitor")
	monitor.set_process(false) # Explicit sample boundaries for this test.
	await physics_frame
	await physics_frame
	var player := main.get_node("Player") as PlayerCharacter
	assert(MONITOR.begin(main.get_node("SuperCity")) == 0)
	assert(MONITOR.begin(player) > 0)
	var previous_health := player.get_current_health()
	assert(player.apply_damage(DAMAGE.new(1.0, Vector3.ZERO)))
	assert(is_equal_approx(player.get_current_health(), previous_health - 1.0))
	main.get_node("PerformanceHUD")._update_performance_label()
	var first: Dictionary = monitor.collect_sample()
	assert(first.player.present)
	assert(first.hud.has("GameplayHUD") and first.hud.has("PerformanceHUD"))
	assert(first.hud.has("PauseMenu") and first.hud.has("DeveloperMenu"))
	assert(first.cpu_timings.player_physics.calls > 0)
	assert(first.cpu_timings.player_damage.calls == 1)
	assert(first.cpu_timings.performance_hud.calls > 0)
	assert(first.cpu_timings.player_move_and_slide.calls > 0)
	assert(first.cpu_timings.player_animation_logic.calls > 0)
	assert(monitor.collect_sample().cpu_timings.is_empty())
	monitor.enabled = false
	assert(MONITOR.begin() == 0)
	main.get_node("PerformanceHUD")._update_performance_label()
	assert(monitor.collect_sample().cpu_timings.is_empty())
	monitor.enabled = true
	main.get_node("PerformanceHUD")._update_performance_label()
	assert(monitor.collect_sample().cpu_timings.performance_hud.calls == 1)
	main.free()
	assert(MONITOR.begin() == 0)
	print("PASS: Player timing, HUD coverage, sample reset, enable/disable and teardown")
	quit()

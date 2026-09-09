extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	var monitor := main.get_node("PerformanceMonitors/CombatPerformanceMonitor")
	monitor.enabled = false
	monitor.set_process(false) # This test owns the sample boundaries.
	var player := main.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(4.0, 1.0, -86.0)
	for hostile in get_nodes_in_group(&"hostile"):
		hostile.receive_alert(player)
	await create_timer(5.0).timeout
	var first: Dictionary = monitor.collect_sample()
	print("[CombatPerf test] ", JSON.stringify(first))
	assert(first.hostile_states.get("COMBAT", 0) > 0)
	assert(first.hostile_states.get("COMBAT", 0) + first.hostile_states.get("SEARCH", 0) == 5)
	assert(first.hostile_ms_per_tick > 0.0)
	assert(first.target_ground_ms_per_tick > 0.0)
	for hostile in get_nodes_in_group(&"hostile"):
		assert(hostile.debug_physics_usec == 0)
		assert(hostile.debug_ground_query_usec == 0)
	await create_timer(5.0).timeout
	var second: Dictionary = monitor.collect_sample()
	print("[CombatPerf test] ", JSON.stringify(second))
	assert(second.hostile_ms_per_tick > 0.0)
	main.free()
	print("PASS: Combat diagnostic sampling and counter reset")
	quit()

extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var scene := Node3D.new()
	var environment := WorldEnvironment.new()
	environment.name = "Daylight"
	scene.add_child(environment)
	for light_name in ["Sun", "Moon"]:
		var light := DirectionalLight3D.new()
		light.name = light_name
		scene.add_child(light)
	var cycle := Node.new()
	cycle.set_script(load("res://scripts/day_night_cycle.gd"))
	scene.add_child(cycle)
	root.add_child(scene)
	cycle.set_process(false)
	cycle.set_time(12.0)
	check(scene.get_node("Sun").visible and not scene.get_node("Moon").visible, "Noon uses sunlight only")
	check(scene.get_node("Sun").global_basis.z.y > 0.8, "Sun disc and light direction match")
	var day_energy: float = environment.environment.ambient_light_energy
	cycle.set_time(0.0)
	check(not scene.get_node("Sun").visible and scene.get_node("Moon").visible, "Midnight uses moonlight only")
	check(environment.environment.ambient_light_energy > 0.0 and environment.environment.ambient_light_energy < day_energy, "Night retains readable ambient light")
	var night_rotation: Basis = cycle._material.get_shader_parameter("star_rotation")
	cycle.set_time(2.0)
	var later_rotation: Basis = cycle._material.get_shader_parameter("star_rotation")
	check(not night_rotation.is_equal_approx(later_rotation), "Celestial sphere rotates during night")
	cycle.set_time(24.0)
	check(is_zero_approx(cycle.time_of_day), "24:00 wraps to midnight")
	check(night_rotation.is_equal_approx(cycle._material.get_shader_parameter("star_rotation")), "Sky rotation is continuous across midnight")
	cycle.set_time(-1.0)
	check(is_equal_approx(cycle.time_of_day, 23.0), "Negative time wraps safely")
	cycle.set_time(NAN)
	check(is_equal_approx(cycle.time_of_day, 23.0), "Invalid input cannot poison the sky")
	cycle.set_time(23.99)
	cycle.day_length_minutes = 1.0
	cycle._process(1.0)
	check(is_equal_approx(cycle.time_of_day, 0.39), "Clock advances across midnight at configured rate")
	cycle.cycle_running = false
	cycle._process(2.0)
	check(is_equal_approx(cycle.time_of_day, 0.39), "Stopped clock stays fixed")
	cycle.cycle_running = true
	cycle.set_process(true)
	paused = true
	await process_frame
	await process_frame
	check(is_equal_approx(cycle.time_of_day, 0.39), "SceneTree pause freezes the clock")
	paused = false
	scene.free()
	# Real-scene integration: ensure Main does not add competing daylight.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	check(main.get_node("WorldEnvironment").environment == null, "Main has no competing environment")
	var old_fill := main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	check(old_fill == null or not old_fill.visible, "Main has no static fill sun at night")
	check(get_nodes_in_group(&"day_night_cycle").size() == 1, "Exactly one active city clock")
	var commands = main.get_node("DeveloperMenu").commands
	var main_cycle = main.get_node("SuperCity/DayNightCycle")
	commands.execute("time night")
	check(is_zero_approx(main_cycle.time_of_day), "Console night preset")
	commands.execute("time sunset")
	check(is_equal_approx(main_cycle.time_of_day, 18.0), "Console sunset preset")
	for invalid in ["time -1", "time 25", "time nan", "time speed -1", "time speed inf", "time speed 61", "time night extra"]:
		commands.execute(invalid)
	check(is_equal_approx(main_cycle.time_of_day, 18.0) and is_equal_approx(main_cycle.time_scale, 1.0), "Invalid console values leave state intact")
	commands.execute("time pause")
	check(not main_cycle.cycle_running, "Console can hold a screenshot time")
	commands.execute("time speed 20")
	commands.execute("time resume")
	check(main_cycle.cycle_running and is_equal_approx(main_cycle.time_scale, 20.0), "Console accelerates and resumes")
	main.free()
	print("Day/night cycle: %d failures" % failures)
	quit(0 if failures == 0 else 1)

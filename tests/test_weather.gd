extends SceneTree
var failures := 0
var weather: Node
var scene: Node3D
var hero: PlayerCharacter
var cycle: Node
var thunder_count := 0

func _initialize() -> void:
	create_timer(60, true, false, true).timeout.connect(func(): push_error("Weather timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func make_world(outdoors: bool) -> void:
	scene = Node3D.new()
	var environment := WorldEnvironment.new()
	environment.name = "Daylight"
	scene.add_child(environment)
	if outdoors:
		for name in ["Sun", "Moon"]:
			var light := DirectionalLight3D.new()
			light.name = name
			scene.add_child(light)
		cycle = Node.new()
		cycle.set_script(load("res://scripts/day_night_cycle.gd"))
		scene.add_child(cycle)
	else:
		scene.add_to_group(&"weather_indoors")
	hero = load("res://scenes/player.tscn").instantiate()
	scene.add_child(hero)
	root.add_child(scene)
	current_scene = scene
	hero.position = Vector3(0, 1, 0)
	hero.set_physics_process(false)
	hero.set_process_input(false)
	if outdoors:
		cycle.cycle_running = false
		cycle.set_time(12.0)
	box(Vector3(0, -0.5, 0), Vector3(100, 1, 100))

func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	scene.add_child(body)
	body.position = at
	return body

func run() -> void:
	weather = root.get_node("Weather")
	weather.set_physics_process(false)
	weather.thunder_played.connect(func(): thunder_count += 1)
	make_world(true)
	await physics_frame
	await physics_frame
	var commands = load("res://scripts/ui-scripts/developer_commands.gd").new(hero)
	check(commands.execute("weather").contains("clear"), "Weather starts clear")
	check(commands.execute("weather lightning").contains("first"), "Clear sky cannot force a storm strike")
	var sun_energy: float = scene.get_node("Sun").light_energy
	commands.execute("weather thunderstorm")
	check(weather.is_thunderstorm() and weather.storm_amount == 0, "Command starts a transition without snapping")
	weather._physics_process(3)
	check(is_equal_approx(weather.storm_amount, 0.5), "Storm blends halfway over three seconds")
	weather._physics_process(3)
	cycle._update_environment()
	check(weather.storm_amount == 1 and scene.get_node("Sun").light_energy < sun_energy, "Storm dims daylight")
	check(cycle.time_of_day == 12, "Weather preserves solar time")
	check(weather._rain.visible and weather._rain_audio.playing, "Outdoor storm presents rain and audio")
	for invalid in ["weather snow", "weather thunderstorm extra", "weather clear extra"]: commands.execute(invalid)
	check(weather.is_thunderstorm(), "Invalid commands leave weather unchanged")
	check(commands.execute("help weather").contains("thunderstorm") and "weather clear" in commands.COMPLETIONS, "Weather help and autocomplete are registered")
	weather.pending_thunder.clear()
	weather.lightning_distance_min = 1029
	weather.lightning_distance_max = 1029
	weather.next_lightning = 100
	check(weather.trigger_lightning() and weather.flash > 0, "Lightning starts with a flash")
	weather.next_lightning = 100
	weather.advance_weather(2.9)
	check(thunder_count == 0, "Thunder waits for distance delay")
	weather.advance_weather(0.11)
	check(thunder_count == 1, "Thunder follows the lightning after three seconds")
	weather.advance_weather(1)
	check(thunder_count == 1, "Strike plays thunder exactly once")
	var roof := box(Vector3(0, 4, 0), Vector3(40, 0.5, 40))
	await physics_frame
	weather._probe_remaining = 0
	weather._physics_process(1)
	check(weather.sheltered and weather.indoor_amount == 1, "Overhead roof muffles outdoor sound")
	check(is_equal_approx(weather._filter.cutoff_hz, 850), "Shelter applies low-pass filtering")
	check(weather._rain.heights.get_pixel(4, 4).r >= 4, "Rain height map clips below roofs")
	roof.free()
	await physics_frame
	weather._probe_remaining = 0
	weather._physics_process(1)
	check(not weather.sheltered and weather.indoor_amount == 0, "Leaving shelter restores outdoor audio")
	weather.trigger_lightning()
	weather.set_physics_process(true)
	paused = true
	var remaining: float = weather.pending_thunder[0].remaining
	var rain_time: float = weather._rain.elapsed
	await create_timer(0.1, true, false, true).timeout
	check(weather.pending_thunder[0].remaining == remaining and weather._rain.elapsed == rain_time, "Pause freezes rain/lightning timers")
	paused = false
	weather.set_physics_process(false)
	scene.free()
	make_world(false)
	await physics_frame
	weather._physics_process(1)
	check(weather.is_thunderstorm() and weather.storm_amount == 1, "Storm survives scene replacement")
	check(not weather._rain.visible and weather._rain_audio.playing and weather.indoor_amount == 1, "Indoor rain is audible and muffled without visible drops")
	weather.pending_thunder.clear()
	weather.trigger_lightning()
	weather.next_lightning = 100
	weather.advance_weather(3.1)
	check(thunder_count >= 2, "Delayed thunder remains audible indoors")
	scene.free()
	make_world(true)
	await physics_frame
	weather._physics_process(1)
	cycle._update_environment()
	check(weather.is_thunderstorm() and weather._rain.visible, "Returning outside resumes the same storm")
	scene.add_to_group(&"combat_arena")
	weather._physics_process(0.1)
	check(weather.is_thunderstorm() and not weather._rain.visible and not weather._rain_audio.playing, "Simulation suppresses presentation without clearing weather")
	scene.remove_from_group(&"combat_arena")
	weather.trigger_lightning()
	weather.set_weather(&"clear")
	check(weather.pending_thunder.is_empty() and weather.flash == 0, "Clear cancels queued thunder and flashes")
	weather._physics_process(6)
	cycle._update_environment()
	check(not weather.is_thunderstorm() and weather.storm_amount == 0 and not weather._rain.visible and not weather._rain_audio.playing, "Clear completes visual/audio cleanup")
	check(is_equal_approx(scene.get_node("Sun").light_energy, sun_energy), "Clear restores original solar lighting")
	weather.set_weather(&"thunderstorm")
	weather.advance_weather(3600)
	check(weather.is_thunderstorm(), "Manual storm has no automatic expiry")
	weather.set_weather(&"clear")
	weather.advance_weather(6)
	scene.free()
	await process_frame
	print("WEATHER_TEST failures=", failures)
	quit(1 if failures else 0)

extends SceneTree

const SOUND_MANAGER = preload("res://scripts/sound_manager.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.001, "%s: expected %s, got %s" % [message, expected, actual])

func run() -> void:
	var manager = SOUND_MANAGER.new()
	near(manager.calculate_target_gain(Vector3.ZERO), 1.0, "Street volume")
	near(manager.calculate_target_gain(Vector3(0, 20, 0)), 1.0, "Height fade start")
	near(manager.calculate_target_gain(Vector3(0, 110, 0)), 0.5, "Height fade midpoint")
	near(manager.calculate_target_gain(Vector3(0, 200, 0)), 0.0, "Height fade end")
	near(manager.calculate_target_gain(Vector3(1500, 0, 0)), 1.0, "City edge")
	near(manager.calculate_target_gain(Vector3(1600, 0, 0)), 0.5, "Outside city midpoint")
	near(manager.calculate_target_gain(Vector3(1700, 0, 0)), 0.0, "Outside city silent")
	near(manager.calculate_target_gain(Vector3(1560, 0, 1080)), 0.5, "City corner uses shortest distance")
	near(manager.calculate_target_gain(Vector3(-546, 0, 0)), 1.0, "Park edge")
	near(manager.calculate_target_gain(Vector3(-516, 0, 0)), 0.575, "Park fade midpoint")
	near(manager.calculate_target_gain(Vector3(-292, 0, 0)), 0.15, "Park interior")
	near(manager.calculate_target_gain(Vector3(-292, 110, 0)), 0.075, "Park and height combine")
	manager.park_fade_enabled = false
	near(manager.calculate_target_gain(Vector3(-292, 0, 0)), 1.0, "Park toggle")
	manager.street_height = 50.0
	near(manager.calculate_target_gain(Vector3(0, 160, 0)), 0.5, "Street height offset")
	manager.height_fade_start = 200.0
	manager.height_fade_end = 20.0
	near(manager.calculate_target_gain(Vector3(0, 300, 0)), 0.0, "Reversed thresholds stay finite")
	manager.ambience_enabled = false
	near(manager.calculate_target_gain(Vector3.ZERO), 0.0, "Disabled ambience")
	manager.free()

	# Exercise the actual scene's sound branch without starting unrelated city systems.
	var scene: Node = load("res://scenes/super_city.tscn").instantiate()
	var sound: Node = scene.get_node("Sound")
	scene.remove_child(sound)
	scene.free()
	var city := Node3D.new()
	root.add_child(city)
	city.position = Vector3(100, 15, -80)
	city.rotation.y = 0.7
	city.add_child(sound)
	var ambience = sound.get_node("CityAmbiances")
	ambience.set_process(false)
	check(ambience.get_script() == SOUND_MANAGER, "Actual CityAmbiances uses sound_manager")
	check(ambience.playing and ambience.stream.loop, "Ambience starts and loops")
	near(ambience.pitch_scale, 0.8, "Authored pitch preserved")
	var imported_stream = load("res://assets/audio/ambiance/city_ambiance.mp3")
	check(ambience.stream != imported_stream and not imported_stream.loop, "Looping does not modify the shared stream")
	ambience._process(2.0)
	near(ambience.volume_linear, 0.0, "Missing hero stays silent")
	var hero := Node3D.new()
	root.add_child(hero)
	hero.add_to_group(&"player")
	hero.global_position = city.to_global(Vector3.ZERO)
	ambience._process(0.9)
	near(ambience.volume_linear, 0.5, "Late hero smoothly fades in in city coordinates")
	ambience._process(0.9)
	near(ambience.volume_linear, 1.0, "Fade in completes")
	hero.global_position = city.to_global(Vector3(0, 250, 0))
	ambience._process(0.6)
	near(ambience.volume_linear, 0.5, "Height fade is temporally smoothed")
	ambience._process(0.6)
	near(ambience.volume_linear, 0.0, "Height becomes silent")
	check(ambience.playing, "Silent ambience keeps playing without restarting the loop")
	hero.free()
	ambience._process(1.0)
	near(ambience.volume_linear, 0.0, "Deleted hero stays silent")
	hero = Node3D.new()
	root.add_child(hero)
	hero.add_to_group(&"player")
	hero.global_position = city.to_global(Vector3.ZERO)
	ambience.fade_in_seconds = 0.0
	ambience.base_volume_db = -6.0
	ambience._process(0.01)
	near(ambience.volume_linear, db_to_linear(-6.0), "Replacement hero and live base volume")
	hero.free()
	city.free()
	print("Sound manager checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

extends SceneTree


func _initialize() -> void:
	_test_resource_calculations()
	_test_progression_overflow()
	_test_player_compatibility.call_deferred()


func _test_resource_calculations() -> void:
	var stats := PlayerStats.new()
	stats.strength = 0
	stats.speed = 0
	stats.resilience = 0
	assert(stats.strength == 1)
	assert(stats.speed == 1)
	assert(stats.resilience == 1)
	assert(stats.get_max_health(100.0) == 100.0)
	assert(stats.get_run_speed(20.0, 5.0) == 20.0)
	assert(stats.get_walk_speed(20.0, 5.0, 0.5) == 10.0)
	assert(stats.get_speed_multiplier(20.0, 5.0) == 1.0)
	assert(is_equal_approx(stats.get_flight_knockdown_chance(0.9, 10), 0.9))
	assert(stats.level == 1)
	assert(stats.experience == 0)
	assert(stats.get_experience_to_next_level() == 100)
	stats.add_experience(100)
	assert(stats.level == 2)
	assert(stats.experience == 0)
	assert(stats.get_experience_to_next_level() == 200)
	stats.add_experience(250)
	assert(stats.level == 3)
	assert(stats.experience == 50)
	assert(stats.get_experience_to_next_level() == 400)

	stats.speed = 10
	assert(stats.get_run_speed(20.0, 5.0) == 65.0)
	stats.speed = 100
	assert(stats.get_run_speed(20.0, 5.0) == 515.0)
	assert(is_equal_approx(stats.get_speed_multiplier(20.0, 5.0), 25.75))

	stats.resilience = 10
	assert(stats.get_max_health(100.0) == 1000.0)
	assert(stats.get_flight_knockdown_chance(0.9, 10) == 0.0)
	stats.resilience = 100
	assert(stats.get_flight_knockdown_chance(0.9, 10) == 0.0)


func _test_player_compatibility() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)
	preload("res://tests/player_test_support.gd").unlock_current_powers(main.get_node("Player"))

	var player := main.get_node("Player") as CharacterBody3D
	var stats := player.get("stats") as PlayerStats
	assert(stats != null)
	assert(player.get("strength") == 10)
	assert(stats.strength == 10)
	assert(player.get("resilience") == 10)
	assert(stats.resilience == 10)
	assert(player.call("get_max_health") == 1000.0)

	player.set("speed", 20)
	assert(stats.speed == 20)
	assert(stats.get_run_speed(20.0, 5.0) == 115.0)
	stats.speed = 30
	assert(player.get("speed") == 30)

	stats.resilience = 5
	assert(player.get("resilience") == 5)
	assert(player.call("get_max_health") == 500.0)

	print("PASS: PlayerStats calculations and Player compatibility")
	quit()


func _test_progression_overflow() -> void:
	var stats := PlayerStats.new()
	stats.level = 57
	assert(stats.get_experience_to_next_level() == 7205759403792793600)
	stats.add_experience(PlayerStats.MAX_PROGRESSION_VALUE)
	assert(stats.level == 58)
	assert(stats.experience == 2017612633061982207)
	assert(stats.get_experience_to_next_level() == PlayerStats.MAX_PROGRESSION_VALUE)
	stats.add_experience(PlayerStats.MAX_PROGRESSION_VALUE)
	assert(stats.level == 59)
	assert(stats.experience == 2017612633061982207)
	stats.level = PlayerStats.MAX_PROGRESSION_VALUE
	stats.add_experience(PlayerStats.MAX_PROGRESSION_VALUE)
	assert(stats.level == PlayerStats.MAX_PROGRESSION_VALUE)
	assert(stats.experience == PlayerStats.MAX_PROGRESSION_VALUE)
	stats.add_experience(1)
	stats.add_experience(0)
	assert(stats.experience == PlayerStats.MAX_PROGRESSION_VALUE)
	var saves: Node = load("res://scripts/save_manager.gd").new()
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify({"level": stats.level}))
	assert(saves._get_int(round_trip, "level", 1) == PlayerStats.MAX_PROGRESSION_VALUE)
	assert(saves._get_int({"level": INF}, "level", 1) == 1)
	assert(saves._get_int({"level": NAN}, "level", 1) == 1)
	saves.free()

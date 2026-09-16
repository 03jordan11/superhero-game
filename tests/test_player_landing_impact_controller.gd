extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)
	preload("res://tests/player_test_support.gd").unlock_current_powers(main.get_node("Player"))

	var player := main.get_node("Player") as PlayerCharacter
	var controller := (
		player.get_node("PlayerLandingImpactController")
		as PlayerLandingImpactController
	)
	var categories: Array[String] = []
	controller.landing_classified.connect(func(category: String): categories.append(category))
	assert(controller != null)
	assert(controller.player == player)

	controller.observe_normal_airborne(-25.0)
	assert(controller.was_airborne)
	assert(controller.max_downward_speed == 25.0)
	controller.resolve_normal_landing()
	assert(not controller.was_airborne)
	assert(controller.max_downward_speed == 0.0)
	assert(categories.back() == "Heavy")

	controller.observe_normal_airborne(-40.0)
	controller.resolve_normal_landing()
	assert(categories.back() == "Super")

	print("PASS: PlayerLandingImpactController tracking and classification")
	quit()

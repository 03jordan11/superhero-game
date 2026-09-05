extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as PlayerCharacter
	var controller := (
		player.get_node("PlayerLandingImpactController")
		as PlayerLandingImpactController
	)
	var hud := player.get_node("ChargeUI") as PlayerHud
	assert(controller != null)
	assert(controller.player == player)

	controller.observe_normal_airborne(-25.0)
	assert(controller.was_airborne)
	assert(controller.max_downward_speed == 25.0)
	controller.resolve_normal_landing()
	assert(not controller.was_airborne)
	assert(controller.max_downward_speed == 0.0)
	assert(hud.landing_label.text == "Landing: Heavy")

	controller.observe_normal_airborne(-40.0)
	controller.resolve_normal_landing()
	assert(hud.landing_label.text == "Landing: Super")

	print("PASS: PlayerLandingImpactController tracking and classification")
	quit()

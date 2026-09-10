extends SceneTree

const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)
	preload("res://tests/player_test_support.gd").unlock_current_powers(main.get_node("Player"))

	var player := main.get_node("Player") as PlayerCharacter
	var hud := player.get_node("ChargeUI") as PlayerHud
	hud.show()
	var vehicle_interactor := (
		player.get_node("PlayerVehicleInteractor")
		as PlayerVehicleInteractor
	)
	var landing_controller := (
		player.get_node("PlayerLandingImpactController")
		as PlayerLandingImpactController
	)

	player.jump_charge_changed.emit(0.75, 1.5)
	assert(hud.charge_bar.value == 50.0)
	assert(hud.charge_label.text == "Power Jump: 50%")

	player.ground_speed_changed.emit(15.0, 10.0, 20.0)
	assert(hud.sprint_speed_bar.value == 50.0)
	assert(hud.sprint_speed_label.text == "Sprint Speed: 50%")

	player.flight_speed_changed.emit(30.0, 40.0, true)
	assert(hud.flight_speed_bar.value == 75.0)
	assert(hud.flight_speed_label.text == "Flight Speed: 75%")
	player.flight_speed_changed.emit(30.0, 40.0, false)
	assert(hud.flight_speed_bar.value == 0.0)

	vehicle_interactor.throw_charge_changed.emit(true, 0.6, 1.2)
	assert(hud.vehicle_throw_charge_bar.visible)
	assert(hud.vehicle_throw_charge_bar.value == 50.0)
	vehicle_interactor.throw_charge_changed.emit(false, 0.0, 1.2)
	assert(not hud.vehicle_throw_charge_bar.visible)

	landing_controller.landing_classified.emit("Super")
	assert(hud.landing_label.text == "Landing: Super")

	var starting_health := player.get_current_health()
	assert(player.apply_damage(DAMAGE_INFO_SCRIPT.new(25.0)))
	assert(hud.health_bar.value == starting_health - 25.0)
	assert(
		hud.health_label.text
		== "Health: %d / %d" % [starting_health - 25.0, player.get_max_health()]
	)

	hud.hide()
	var previous_charge_text := hud.charge_label.text
	var previous_health_text := hud.health_label.text
	var previous_landing_text := hud.landing_label.text
	player.jump_charge_changed.emit(1.2, 1.5)
	player.flight_speed_changed.emit(10.0, 40.0, true)
	player.ground_speed_changed.emit(20.0, 10.0, 20.0)
	vehicle_interactor.throw_charge_changed.emit(true, 0.9, 1.2)
	landing_controller.landing_classified.emit("Heavy")
	player.stats.add_experience(125)
	player.apply_damage(DAMAGE_INFO_SCRIPT.new(10.0))
	assert(hud.charge_label.text == previous_charge_text)
	assert(hud.health_label.text == previous_health_text)
	assert(hud.landing_label.text == previous_landing_text)
	assert(hud.experience_label.text == "Level 1: 0 / 100 XP")
	hud.show()
	assert(hud.charge_label.text == "Power Jump: 80%")
	assert(hud.flight_speed_bar.value == 25.0)
	assert(hud.sprint_speed_bar.value == 100.0)
	assert(is_equal_approx(hud.vehicle_throw_charge_bar.value, 75.0))
	assert(hud.vehicle_throw_charge_bar.visible)
	assert(hud.health_bar.value == player.get_current_health())
	assert(hud.experience_label.text == "Level 2: 25 / 200 XP")
	assert(hud.landing_label.text == "Landing: Heavy")
	print("PASS: PlayerHud events, hidden controls stay unchanged, and showing refreshes all readouts")
	quit()

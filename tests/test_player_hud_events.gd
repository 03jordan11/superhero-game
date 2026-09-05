extends SceneTree

const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as PlayerCharacter
	var hud := player.get_node("ChargeUI") as PlayerHud
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

	print("PASS: PlayerHud event subscriptions and presentation updates")
	quit()

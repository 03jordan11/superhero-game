extends SceneTree

class TestInput extends Node:
	var snapshot := PlayerInputSnapshot.new()
	func capture() -> PlayerInputSnapshot: return snapshot
	func is_sprint_requested() -> bool: return snapshot.sprint_pressed
	func is_power_aim_requested() -> bool: return false

const STEP := 1.0 / 60.0
var failures := 0

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Rescue test timed out"); quit(1))
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle(patient: RescuePatient) -> void:
	for tick in 60: patient._physics_process(STEP)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000, 1, 2000)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var hospital := load("res://assets/buildings/hospital/hospital.tscn").instantiate() as Node3D
	hospital.position.x = 500
	hospital.rotation.y = PI / 2.0
	world.add_child(hospital)
	var zone := hospital.get_node("RescueDropOff") as HospitalRescueZone
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	player.position.y = 0.1
	world.add_child(player)
	player.set_physics_process(false)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	var input := TestInput.new()
	player.add_child(input)
	player.input_controller = input
	await physics_frame
	await physics_frame
	var rescue := load("res://scenes/encounters/rescue.tscn").instantiate() as RescueEncounter
	world.add_child(rescue)
	rescue.random_number_generator.seed = 42
	rescue.debug_waypoint = true
	check(rescue.start_encounter(player), "Rescue spawns on random clear ground with a hospital")
	rescue.set_physics_process(false)
	rescue.cleanup_delay = 0
	var patient := rescue.patient
	patient.set_physics_process(false)
	settle(patient)
	check(patient.is_on_floor() and not patient.is_dead and not patient.animation_controller.animation_player.is_playing(), "Protected living patient rests on ground in paused death pose")
	check(not patient.apply_damage(preload("res://scripts/combat-scripts/damage_info.gd").new(9999)) and patient.get_current_health() > 0, "Patient ignores lethal damage")
	check(rescue.remaining_time == 120 and rescue.get_waypoint_position() == patient.global_position, "Two-minute timer and initial patient waypoint")
	var hud := player.get_node("RescueTimerHUD")
	hud._process(0)
	check(hud.visible and hud.timer_label.text.contains("02:00"), "Timer begins at 02:00")
	check(zone.ring.material_override.emission_energy_multiplier == 3, "Hospital ring glows during daytime")
	player.position = patient.global_position + Vector3(0, 0.1, 2)
	for tick in 20: player._profiled_physics_process(STEP)
	input.snapshot.vehicle_interact_just_pressed = true
	player._profiled_physics_process(STEP)
	input.snapshot.vehicle_interact_just_pressed = false
	check(player.rescue_carrier.has_patient() and player.is_carrying(), "E picks up injured civilian")
	check(patient.skeleton.find_bone("Hips") >= 0, "Imported patient has the carry anchor bone")
	check(patient.get_carry_anchor_position().distance_to(player.to_global(player.rescue_carrier.carry_offset)) < 0.01, "Posed body is centered at the chest carry anchor")
	check(not player.rescue_carrier.try_pick_up() and not player.vehicle_interactor.try_pick_up_vehicle(), "All pickups reject occupied hands")
	check(rescue.get_waypoint_position() == zone.global_position and rescue.get_waypoint_priority() == 1, "Carrying prioritizes hospital waypoint")
	rescue._physics_process(1)
	var landing := player.landing_impact_controller
	landing.was_on_floor = false
	landing.max_effect_downward_speed = 10
	landing.update_after_move(true, false, 50, 1)
	check(rescue.remaining_time == 119, "Soft landing has no penalty")
	landing.was_on_floor = false
	landing.max_effect_downward_speed = 25
	landing.update_after_move(true, false, 50, 1)
	landing.update_after_move(true, false, 50, 1)
	check(rescue.remaining_time == 114, "Actual hard landing costs five seconds exactly once")
	hud._process(0)
	check(hud.detail_label.text.contains("5 seconds"), "Penalty feedback displays its cost")
	landing.was_on_floor = false
	landing.max_effect_downward_speed = 0
	landing.update_after_move(true, true, 50, 1)
	check(rescue.remaining_time == 109, "Ground slam also costs five seconds")
	input.snapshot.vehicle_interact_just_pressed = true
	player._profiled_physics_process(STEP)
	input.snapshot.vehicle_interact_just_pressed = false
	check(not player.is_carrying() and patient.get_parent() == rescue, "E sets down without grabbing anything else on the same press")
	patient.set_physics_process(false)
	settle(patient)
	check(rescue.get_waypoint_position() == patient.global_position and rescue.get_waypoint_priority() == 0, "Waypoint returns to dropped civilian")
	landing.hard_landing_effect_spawned.emit()
	check(rescue.remaining_time == 109, "Landing unladen has no rescue penalty")
	var car := RigidBody3D.new()
	world.add_child(car)
	player.vehicle_interactor.held_vehicle = car
	check(not player.rescue_carrier.try_pick_up(), "Holding a car prevents picking up a person")
	player.vehicle_interactor.held_vehicle = null
	car.free()
	player.position = patient.global_position + Vector3(0, 0.1, 2)
	check(player.rescue_carrier.try_pick_up(), "Dropped civilian can be picked up again")
	check(player.state_machine.transition_to(&"FlyingState"), "Flight remains available while carrying")
	player.position.y = 40
	player.rescue_carrier.drop_patient()
	check(patient.global_position.y > 35, "Midair drop does not teleport civilian to ground")
	patient.set_physics_process(false)
	for tick in 300: patient._physics_process(STEP)
	check(patient.is_on_floor() and patient.get_current_health() > 0, "Protected civilian settles safely after an airborne drop")
	rescue._physics_process(200)
	hud._process(0)
	check(rescue.remaining_time == 0 and rescue.state == BaseEncounter.EncounterState.ACTIVE and hud.timer_label.text.contains("00:00"), "Zero timer is clamped and cannot fail rescue")
	player.position = patient.global_position + Vector3(0, 0.1, 2)
	check(player.rescue_carrier.try_pick_up(), "Patient still recoverable after timer expires")
	player.position = zone.global_position + Vector3(0, 0, 1.8)
	player.rotation = Vector3.ZERO
	rescue._physics_process(0)
	check(rescue.state == BaseEncounter.EncounterState.ACTIVE, "Entering green circle while carrying does not auto-complete")
	var money := player.stats.money
	var goodwill := player.stats.good_will
	var level := player.stats.level
	player.rescue_carrier.drop_patient()
	patient.set_physics_process(false)
	settle(patient)
	rescue._physics_process(0)
	rescue.complete_encounter()
	check(rescue.state == BaseEncounter.EncounterState.COMPLETED, "Setting patient down in hospital completes rescue")
	check(player.stats.money == money + 100 and player.stats.good_will == goodwill + 10 and player.stats.level == level + 1, "100 XP, $100 and 10 Good Will awarded once, even after timeout")
	hud._process(0)
	check(not hud.visible, "Completion hides timer")
	var saves := root.get_node("SaveManager")
	var saved: Dictionary = saves._get_player_save_data(player)
	player.stats.money = 0
	player.stats.good_will = 0
	saves._apply_player_save_data(player, saved)
	check(player.stats.money == money + 100 and player.stats.good_will == goodwill + 10, "Money and Good Will survive save-data round trip")
	saved.stats.erase("good_will")
	saves._apply_player_save_data(player, saved)
	check(player.stats.good_will == 0, "Older saves default Good Will to zero")
	world.free()
	print("Rescue encounter: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

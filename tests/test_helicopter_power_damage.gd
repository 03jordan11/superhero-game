extends SceneTree
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var aircraft: Node3D

func _initialize() -> void:
	create_timer(40, true, false, true).timeout.connect(func(): push_error("Aircraft powers test timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func reset(power: StringName) -> void:
	hero.get_node("PlayerPowerController").select_active_power(power)
	hero.laser_eyes.cancel_input()
	hero.laser_eyes.heat = 0.0
	hero.laser_eyes.overheated = false
	hero.laser_eyes._require_release = false
	aircraft.health_component.current_health = 100.0
	hero.camera.top_level = true
	hero.camera.global_position = hero.global_position + Vector3(0, 2, 4)
	var hull: CollisionShape3D = aircraft._solids[0]
	hero.camera.look_at(hull.global_transform * hull.shape.get_debug_mesh().get_aabb().get_center())

func input(special := false) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.aim_power_pressed = true
	value.activate_power_pressed = not special
	value.secondary_power_pressed = special
	return value

func run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	hero.set_physics_process(false)
	hero.set_process_input(false)
	hero.global_position = Vector3(0, 14, 0)
	hero.get_node("PlayerPowerController").progression.apply_save_data({"schema_version": 2, "upgrades": {"laser_eyes": 0, "fire": 3, "electricity": 3, "ice": 1, "flight": 0}})
	aircraft = arena.spawn_enemy(&"helicopter")
	aircraft.set_physics_process(false)
	aircraft.gun.set_physics_process(false)
	aircraft.global_position = Vector3(0, 15, -8)
	await physics_frame
	await physics_frame
	for selected in [&"laser_eyes", &"electricity", &"ice", &"fire"]:
		reset(selected)
		hero.laser_eyes.update_power(0.2, input(selected == &"fire"))
		var amount := 100.0 - float(aircraft.get_current_health())
		print("AIRCRAFT_POWER ", selected, " damage=", amount)
		check(amount > 0.0, String(selected) + " aimed beam/breath damages the real helicopter")
		if selected == &"ice": check(is_equal_approx(amount, 1.0), "Frost deals only five damage per second")
		check(aircraft.velocity == Vector3.ZERO and aircraft.flight.velocity == Vector3.ZERO, "Power does not displace aircraft")
		check(aircraft.get("frost") == null and aircraft.get("electrified") == null, "Aircraft does not gain frozen/electrified states")
		check(not aircraft.has_node("IcePreparation") and not aircraft.has_node("ElectrifiedPreparation"), "No ice or shock effect attached to aircraft")
	# Launch both normal and charged projectiles through their real swept hit path.
	for charge in [0.0, 1.0]:
		reset(&"fire")
		var fire: PlayerFire = hero.get_node("PlayerFire")
		fire._cooldown = 0
		check(fire.launch(charge), "Fireball launches")
		var ball: Node3D = get_nodes_in_group(&"fireball_projectiles").back()
		ball.set_physics_process(false)
		var hull: CollisionShape3D = aircraft._solids[0]
		ball.advance_to(hull.global_transform * hull.shape.get_debug_mesh().get_aabb().get_center())
		check(aircraft.get_current_health() < 100.0, "Fireball damages aircraft, charge=" + str(charge))
		await process_frame
	reset(&"fire")
	root.get_node("Weather").external_combustion_cooldown_remaining = 0.0
	hero.laser_eyes.heat = 100
	# Place the aircraft root inside the eight-meter spherical blast.
	aircraft.global_position = hero.global_position + Vector3(0, 3, -4)
	var old_position := aircraft.global_position
	check(hero.external_combustion.erupt(), "Combustion erupts")
	check(aircraft.get_current_health() == 30 and aircraft.global_position == old_position and aircraft.flight.velocity == Vector3.ZERO, "Combustion deals seventy damage without knockback")
	reset(&"electricity")
	aircraft.global_position = Vector3(0, 18, -8)
	var ground := Vector3(0, 0, -8)
	hero.lightning_strike.apply_strike_damage(ground)
	check(aircraft.get_current_health() == 75, "Lightning hits aircraft above the ground circle for twenty-five direct damage")
	await create_timer(0.1).timeout
	check(aircraft.get_current_health() == 75, "Lightning adds no Electrified tick damage")
	aircraft.global_position.x = 5
	hero.lightning_strike.apply_strike_damage(ground)
	check(aircraft.get_current_health() == 75, "Lightning excludes aircraft outside the strike radius")
	# Cover still blocks breath and sky strikes.
	aircraft.global_position = Vector3(0, 15, -8)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 8, 0.5)
	shape.shape = box
	wall.add_child(shape)
	arena.add_child(wall)
	wall.global_position = Vector3(0, 16, -4)
	await physics_frame
	for selected in [&"fire", &"ice"]:
		reset(selected)
		hero.laser_eyes.update_power(0.2, input(selected == &"fire"))
		check(aircraft.get_current_health() == 100, "Cover blocks " + String(selected) + " breath")
	wall.global_position = Vector3(0, 25, -8)
	box.size = Vector3(12, 0.5, 12)
	await physics_frame
	hero.lightning_strike.apply_strike_damage(ground)
	check(aircraft.get_current_health() == 100, "Overhead cover blocks sky lightning")
	wall.free()
	hero.laser_eyes.cancel_input()
	root.get_node("SlowMotion").cancel_all()
	arena.free()
	await process_frame
	print("HELICOPTER_POWER_DAMAGE_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

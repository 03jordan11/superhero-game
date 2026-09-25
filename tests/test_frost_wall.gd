extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var power: PlayerFrostWall
var cooldowns: Node
var slow: Node

func _initialize() -> void:
	create_timer(45, true, false, true).timeout.connect(func(): push_error("Frost Wall timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func input(held := false, pressed := false, released := false, aim := true) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.aim_power_pressed = aim
	value.secondary_power_pressed = held
	value.secondary_power_just_pressed = pressed
	value.secondary_power_just_released = released
	return value

func reset(tier := 2) -> void:
	for wall in get_nodes_in_group(&"frost_walls"): wall.free()
	power.cancel()
	slow.cancel_all()
	hero.revive_for_respawn()
	hero.get_node("PlayerPowerController").progression.apply_save_data({"schema_version": 2, "upgrades": {"ice": tier, "flight": 0, "electricity": 3}})
	hero.get_node("PlayerPowerController").select_active_power(&"ice")
	cooldowns.frost_wall_cooldown_remaining = 0.0
	hero.laser_eyes.heat = 0.0
	hero.laser_eyes.overheated = false
	hero.global_position = Vector3(0, 0.05, 0)
	hero.camera.top_level = true
	hero.camera.global_position = Vector3(0, 3, 4)
	hero.camera.look_at(Vector3(0, 0, -10))
	power.tick(0.01, input())

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

func run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	hero.set_physics_process(false)
	hero.set_process_input(false)
	hero.camera.reparent(arena)
	power = hero.frost_wall
	cooldowns = root.get_node("Weather")
	cooldowns.set_physics_process(false)
	slow = root.get_node("SlowMotion")
	slow.set_process(false)
	await physics_frame
	reset(1)
	power.tick(0.01, input(true, true))
	check(not power.casting, "Requires Frost tier two")
	reset()
	power.tick(0.01, input(true, true, false, false))
	check(not power.casting, "Q without Aim does nothing")
	reset()
	power.tick(0.01, input(true))
	check(not power.casting, "Held Q does not start a new cast")
	reset()
	check(not power.aimed_ground().is_empty(), "Camera finds supported arena ground")
	power.tick(0.01, input(true, true))
	slow._advance(0.1)
	check(power.aiming and power._marker.visible and Engine.time_scale == 0.5 and AudioServer.playback_speed_scale == 0.5, "Aim marker and half-speed game/audio")
	check(power._marker.mesh.size == Vector2(8, 2), "Preview matches footprint")
	var hp := hero.get_current_health()
	var bullet = DAMAGE.new(7, Vector3.ZERO, Vector3.FORWARD, &"knockback")
	bullet.damage_type = &"bullet"
	hero.apply_damage(bullet)
	check(hero.get_current_health() == hp - 7 and power.casting and not hero.animation_controller.is_hit_reacting and hero.status_effects.hit_slowdown_remaining == 0, "Bullets damage but cannot interrupt")
	var victims: Array[HostileBase] = []
	var health: Array[float] = []
	for i in 4:
		var victim: HostileBase = arena.spawn_enemy([&"melee_thug", &"pistol_thug", &"rifle_thug", &"super_thug"][i])
		victim.set_physics_process(false)
		victim.global_position = Vector3((i - 1.5) * 2.0, 0.05, -10 + (0.75 if i % 2 == 0 else -0.75))
		victims.append(victim)
		health.append(victim.get_current_health())
	var outside: HostileBase = arena.spawn_enemy(&"super_thug")
	outside.set_physics_process(false)
	outside.global_position = Vector3(5, 0.05, -10)
	var outside_hp := outside.get_current_health()
	await physics_frame
	power.tick(0.01, input(false, false, true))
	check(get_nodes_in_group(&"frost_walls").size() == 1, "Release erects a wall")
	if get_nodes_in_group(&"frost_walls").is_empty(): quit(1); return
	var wall: StaticBody3D = get_nodes_in_group(&"frost_walls")[0]
	wall.set_physics_process(false)
	check(wall.dimensions == Vector3(8, 4, 2) and cooldowns.frost_wall_cooldown_remaining == 300 and hero.laser_eyes.heat == 20, "Dimensions, cooldown and heat cost")
	for i in 4:
		check(victims[i].get_current_health() == health[i] - 50, "Deals fifty damage to each variant")
		check(victims[i].velocity.y == 8 and victims[i].knockback_velocity.z < -11, "Launches upward and away, including supers")
	check(outside.get_current_health() == outside_hp, "Does not damage outside footprint")
	slow._advance(0.25)
	check(Engine.time_scale > 0.5 and Engine.time_scale < 1, "Release eases back to normal")
	slow._advance(0.25)
	await physics_frame
	check(ray(Vector3(3.5, 3.5, -8), Vector3(3.5, 3.5, -12)).get("collider") == wall, "Extended wall blocks high shots from player side")
	check(ray(Vector3(3.5, 3.5, -12), Vector3(3.5, 3.5, -8)).get("collider") == wall, "Extended wall blocks high shots from enemy side")
	check(not wall.has_method("apply_damage"), "Wall has no destructible health")
	hero.global_position = Vector3(0, 1.1, -8)
	check(hero.test_move(hero.global_transform, Vector3(0, 0, -4)), "Wall blocks player movement")
	outside.global_position = Vector3(0, 0.05, -12)
	check(outside.test_move(outside.global_transform, Vector3(0, 0, 4)), "Wall blocks enemy movement")
	# Exercise actual launch integration so the solid wall cannot pin the victims.
	for tick in 25:
		for victim in victims: victim._physics_process(1.0 / 60.0)
		wall._physics_process(1.0 / 60.0)
		await physics_frame
	for victim in victims:
		check(victim.global_position.y > 1 and victim.global_position.z < -11.3, "Victim travels up and clear of the wall")
		check(not victim.get_collision_exceptions().has(wall), "Collision restored after launch clears wall")
	hero.get_node("GameplayHUD")._refresh_cooldowns()
	check(hero.get_node("GameplayHUD/Cooldowns/FrostWall").text == "Frost Wall - 300 seconds", "Cooldown has dedicated HUD text")
	wall.elapsed = 5.9
	wall._physics_process(0.05)
	check(not wall.is_queued_for_deletion() and wall.collision_layer == 1, "Solid until six game seconds")
	wall._physics_process(0.06)
	check(wall.is_queued_for_deletion() and wall.collision_layer == 0, "Expires after six game seconds")
	await process_frame
	for victim in victims: victim.free()
	outside.free()
	power.tick(0.6, input())
	power.tick(0.01, input(true, true))
	check(not power.casting, "Cooldown blocks recast")
	reset()
	hero.state_machine.transition_to(&"FlyingState")
	hero.global_position.y = 12
	hero.camera.global_position = Vector3(0, 14, 4)
	hero.camera.look_at(Vector3(0, 0, -10))
	power.tick(0.01, input(true, true))
	hero.apply_damage(bullet)
	check(power.aiming and hero.is_flying and hero.velocity == Vector3.ZERO and not power.target.is_empty(), "Flight casting hovers and ignores bullet reactions")
	power.tick(0.01, input(false, false, true))
	check(cooldowns.frost_wall_cooldown_remaining == 300 and hero.is_flying, "Flight release casts normally")
	reset()
	hero.camera.look_at(Vector3(0, 0, -60))
	check(power.aimed_ground().is_empty(), "Beyond fifty meters rejected")
	hero.camera.look_at(hero.camera.global_position + Vector3(0, 1, -0.1))
	check(power.aimed_ground().is_empty(), "Sky aim rejected")
	power.tick(0.01, input(true, true))
	power.tick(0.01, input(false, false, true))
	check(cooldowns.frost_wall_cooldown_remaining == 0 and hero.laser_eyes.heat == 0, "Invalid release costs nothing")
	reset()
	power.tick(0.01, input(true, true))
	power.tick(0.01, input(true, false, false, false))
	check(not power.casting and cooldowns.frost_wall_cooldown_remaining == 0, "Releasing Aim cancels")
	reset()
	power.tick(0.01, input(true, true))
	hero.get_node("PlayerPowerController").select_active_power(&"electricity")
	check(not power.casting, "Switching power cancels")
	reset()
	power.tick(0.01, input(true, true))
	paused = true
	slow._process(0)
	check(not power.casting and Engine.time_scale == 1 and AudioServer.playback_speed_scale == 1, "Pause cancels and restores time")
	paused = false
	reset()
	# Aircraft intersecting the actual wall volume take damage, never launch/status.
	var aircraft: Node3D = arena.spawn_enemy(&"helicopter")
	aircraft.set_physics_process(false)
	aircraft.gun.set_physics_process(false)
	aircraft.global_position += Vector3(0, 1.5, -10) - aircraft.get_damage_center()
	await physics_frame
	await physics_frame
	power.tick(0.01, input(true, true))
	power.tick(0.01, input(false, false, true))
	check(aircraft.get_current_health() == 50 and aircraft.velocity == Vector3.ZERO and aircraft.flight.velocity == Vector3.ZERO, "Wall damages overlapping helicopter without launching it")
	aircraft.free()
	reset()
	# Solid cover in the wall volume makes the placement invalid.
	var obstacle := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1, 2, 1)
	obstacle.add_child(shape)
	arena.add_child(obstacle)
	obstacle.global_position = Vector3(3.5, 1, -10)
	await physics_frame
	check(power.aimed_ground().is_empty(), "Cannot place through a solid object at the edge of the footprint")
	obstacle.free()
	reset()
	hero.laser_eyes.heat = 85
	hero.laser_eyes._cooldown = 1
	power.tick(0.01, input(true, true))
	power.tick(0.01, input(false, false, true))
	check(cooldowns.frost_wall_cooldown_remaining == 300 and hero.laser_eyes.overheated and not power.casting, "Crossing full Heat casts the wall and resolves normal overheat")
	reset()
	power.tick(0.01, input(true, true))
	hero.apply_damage(DAMAGE.new(10000))
	check(hero.is_dead and not power.casting, "Lethal damage still cancels casting")
	reset()
	power.tick(0.01, input(true, true))
	slow._advance(0.1)
	arena.free()
	check(Engine.time_scale == 1 and AudioServer.playback_speed_scale == 1, "Scene exit restores speed")
	print("FROST_WALL_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

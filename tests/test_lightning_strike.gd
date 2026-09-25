extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var power: PlayerLightningStrike
var weather: Node

func _initialize() -> void:
	create_timer(60, true, false, true).timeout.connect(func(): Engine.time_scale = 1; push_error("Lightning test timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func input(held := false, pressed := false, released := false) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.secondary_power_pressed = held
	value.secondary_power_just_pressed = pressed
	value.secondary_power_just_released = released
	return value

func reset() -> void:
	power.cancel()
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	hero.revive_for_respawn()
	hero.global_position = Vector3(0, 1, 0)
	hero.velocity = Vector3.ZERO
	hero.get_node("PlayerPowerController").progression.apply_save_data({"schema_version": 2, "upgrades": {"electricity": 3, "flight": 0}})
	hero.get_node("PlayerPowerController").select_active_power(&"electricity")
	weather.set_weather(&"thunderstorm")
	weather.lightning_strike_cooldown_remaining = 0
	weather.thunderstorm_cooldown_remaining = 290
	for i in 4:
		hero.velocity.y = -2
		hero.move_and_slide()
	power.tick(0.01, input())
	hero.camera.top_level = true
	hero.camera.global_position = Vector3(0, 3, 4)
	hero.camera.look_at(Vector3(0, 0, -10))

func tap() -> void:
	power.tick(0.01, input(true, true))
	power.tick(0.10, input(false, false, true))
	power.tick(0.25, input())

func enemy(kind: StringName, position: Vector3) -> HostileBase:
	var victim := arena.spawn_enemy(kind) as HostileBase
	victim.set_physics_process(false)
	victim.global_position = position
	return victim

func run() -> void:
	# Keep these action-timing regressions deterministic; eased transitions have their own tests.
	root.get_node("SlowMotion").ease_in_seconds = 0.0
	root.get_node("SlowMotion").ease_out_seconds = 0.0
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	hero.set_physics_process(false)
	hero.set_process_input(false)
	power = hero.lightning_strike
	weather = root.get_node("Weather")
	weather.set_physics_process(false)
	await physics_frame
	reset()
	check(hero.is_on_floor() and power.eligible(), "Grounded hero is eligible")
	check(power.strike_radius == 4.5 and power.target_range == 50 and power.aiming_time_scale == 0.5, "Default radius, range and time scale match spec")
	hero.get_node("PlayerPowerController").progression.apply_save_data({"upgrades": {"electricity": 2}})
	tap()
	check(not power.casting and weather.lightning_strike_cooldown_remaining == 0, "Tier 2 cannot call Lightning Strike")
	reset()
	weather.set_weather(&"clear")
	tap()
	check(not power.casting, "Clear weather blocks Lightning Strike")
	reset()
	hero.get_node("PlayerPowerController").select_active_power(&"fire")
	tap()
	check(not power.casting, "Another selected element blocks Lightning Strike")
	reset()
	hero.state_machine.transition_to(&"FlyingState")
	tap()
	check(not power.casting, "Flight blocks strike even while close to ground")
	reset()
	hero.position.y = 6
	hero.velocity.y = -1
	hero.move_and_slide()
	tap()
	check(not power.casting, "Ordinary airborne state also blocks strike")
	reset()
	hero.laser_eyes.overheated = true
	tap()
	check(not power.casting, "Heat lockout blocks activation")
	reset()
	# Every thug variant receives guaranteed Electrified, including gun users/supers.
	var victims: Array[HostileBase] = []
	var health: Array[float] = []
	var kinds: Array[StringName] = [&"melee_thug", &"pistol_thug", &"rifle_thug", &"super_thug"]
	for i in kinds.size():
		var angle := i * TAU / 4
		var victim := enemy(kinds[i], Vector3(sin(angle) * 2.0, 0, cos(angle) * 2.0))
		victims.append(victim)
		health.append(victim.get_current_health())
	var outer_ring := enemy(&"melee_thug", Vector3(4.4, 0, 0))
	var outside := enemy(&"melee_thug", Vector3(4.6, 0, 0))
	var high := enemy(&"melee_thug", Vector3(0, 6, 0))
	var helicopter: Node3D = arena.spawn_enemy(&"helicopter")
	helicopter.set_physics_process(false)
	var helicopter_hp: float = helicopter.health_component.current_health
	var hero_hp := hero.get_current_health()
	await physics_frame
	tap()
	check(power.impacted and power.radial and Engine.time_scale == 1.0, "Quick tap emits a self pulse with no slow motion")
	check(power.target.position.distance_to(Vector3.ZERO) < 0.1, "Tap circle is centered on the hero's ground point")
	for i in victims.size():
		check(victims[i].get_current_health() == health[i] - 25 and victims[i].electrified.active, String(kinds[i]) + " receives exactly 25 impact and Electrified")
		victims[i].electrified.update(2.5)
		check(victims[i].get_current_health() == health[i] - 65 and not victims[i].electrified.active, "Full strike damage is 65")
	check(outside.get_current_health() == 100 and high.get_current_health() == 100, "Outside radius and other elevations are unaffected")
	check(outer_ring.get_current_health() == 75 and outer_ring.electrified.active, "Expanded circle hits a thug inside the new 4.5m radius")
	check(helicopter.health_component.current_health == helicopter_hp and hero.get_current_health() == hero_hp, "Distant helicopter outside the strike and caster are unaffected")
	check(hero.laser_eyes.heat == 100 and hero.laser_eyes.overheated and not hero.is_knocked_out, "Strike fills Heat with lockout but no explosion/knockdown")
	check(weather.lightning_strike_cooldown_remaining == 60 and weather.thunderstorm_cooldown_remaining == 290, "One-minute cooldown is independent of summon cooldown")
	check(power._effect.active and power._effect.lifetime == 1.0, "Ground discharge lasts one second")
	var effect_origin: Vector3 = power._effect.global_position
	hero.position.x += 1
	check(power._effect.global_position == effect_origin, "Discharge remains fixed in the world after the hero moves")
	hero.position.x -= 1
	power._effect._process(1.01)
	check(not power._effect.visible, "Ground effect disappears after one second")
	power.tick(1.0, input())
	hero.laser_eyes.heat = 0
	hero.laser_eyes.overheated = false
	power.tick(0.01, input())
	tap()
	check(not power.casting, "Cooldown blocks repeated casts")
	weather.advance_weather(60)
	power.tick(0.1, input(true))
	check(not power.casting, "Held Q never recasts when cooldown expires")
	# Targets and cover. Drop enemies before using the camera ray.
	for child in arena.opponents.get_children(): child.free()
	reset()
	await physics_frame
	check(not power.aimed_ground().is_empty() and power.aimed_ground().position.distance_to(Vector3(0, 0, -10)) < 0.1, "Camera center selects ground under the reticle")
	hero.camera.look_at(Vector3(0, 0, -35))
	check(not power.aimed_ground().is_empty(), "Targets beyond the former 30m range are valid")
	hero.camera.look_at(Vector3(0, 0, -49))
	check(not power.aimed_ground().is_empty(), "Target just inside 50 meters is valid")
	hero.camera.look_at(Vector3(0, 0, -51))
	check(power.aimed_ground().is_empty(), "Target beyond 50 meters is invalid")
	hero.camera.look_at(hero.camera.global_position + Vector3(0, 1, -1))
	check(power.aimed_ground().is_empty(), "Looking at sky has no target")
	power.tick(0.01, input(true, true))
	power.tick(0.3, input(true))
	check(power.casting and Engine.time_scale == 0.5 and not power._marker.visible, "Holding slows time, but invalid ground has no marker")
	power.tick(0.01, input(false, false, true))
	check(not power.casting and Engine.time_scale == 1.0 and weather.lightning_strike_cooldown_remaining == 0, "Invalid release cancels for free and restores time")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Invalid release restores global audio speed")
	reset()
	var aimed := enemy(&"pistol_thug", Vector3(0, 0, -10))
	await physics_frame
	power.tick(0.01, input(true, true))
	power.tick(0.3, input(true))
	check(power._marker.visible and power._marker.mesh.size == Vector2(9, 9), "Hold shows a nine-meter ground circle")
	check(Engine.time_scale == 0.5, "Default hold runs at half speed")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "All audio runs at the exact game speed while aiming")
	var bullet = DAMAGE.new(7, aimed.global_position, Vector3.FORWARD, &"knockback", aimed)
	bullet.damage_type = &"bullet"
	hero_hp = hero.get_current_health()
	hero.apply_damage(bullet)
	check(hero.get_current_health() == hero_hp - 7 and power.casting and not hero.animation_controller.is_hit_reacting and not hero.is_knocked_out, "Bullet damage lands without interrupting or flinching the cast")
	check(hero.status_effects.hit_slowdown_remaining == 0 and Engine.time_scale == 0.5, "Damage does not inject a movement stagger or cancel aiming slow motion")
	power.tick(0.01, input(false, false, true))
	check(not power.aiming and Engine.time_scale == 0.5, "Time remains slow through release gesture")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Audio stays synchronized through the release gesture")
	power.tick(0.25, input())
	check(power.impacted and Engine.time_scale == 1.0 and aimed.get_current_health() == 75 and aimed.electrified.active, "Aimed impact hits target and restores normal time")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Impact restores audio together with game time")
	var punch = DAMAGE.new(5, hero.global_position, Vector3.FORWARD, &"chest", hero)
	aimed.apply_damage(punch)
	aimed.electrified.update(4)
	check(aimed.get_current_health() == 70 and not aimed.electrified.active, "Player follow-up cancels all remaining status damage")
	# Do not refresh an already-active status timer.
	aimed.electrified.begin(aimed, hero, 2.5, 15, 10)
	aimed.electrified.update(1)
	var before := aimed.get_current_health()
	power.apply_strike_damage(aimed.global_position)
	check(aimed.electrified.elapsed == 1 and aimed.get_current_health() == before - 25, "Existing Electrified takes impact damage without resetting its timer")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	collider.shape = box
	wall.add_child(collider)
	arena.add_child(wall)
	wall.global_position = Vector3(0, 2, -9)
	await physics_frame
	before = aimed.get_current_health()
	power.apply_strike_damage(Vector3(0, 0, -8))
	check(aimed.get_current_health() == before, "Wall blocks the initial hit and status application")
	check(power.aimed_ground().is_empty(), "A wall in the aiming ray cannot become a ground target")
	wall.free()
	await physics_frame
	reset()
	power.tick(0.01, input(true, true))
	power.tick(0.3, input(true))
	power.tick(0.01, input())
	check(not power.casting and Engine.time_scale == 1 and weather.lightning_strike_cooldown_remaining == 0, "Suppressed input cancels rather than firing")
	# Cancellation paths restore the exact previous scale and spend no cooldown.
	for reason in ["menu", "weather", "pause", "death"]:
		reset()
		Engine.time_scale = 0.8
		power.aiming_time_scale = 0.4
		power.tick(0.01, input(true, true))
		power.tick(0.3, input(true))
		check(is_equal_approx(Engine.time_scale, 0.32), "Inspector scale multiplies the prior game speed")
		check(is_equal_approx(AudioServer.playback_speed_scale, Engine.time_scale), "Custom slowdown applies identically to global audio")
		match reason:
			"menu": hero.input_controller.reset()
			"weather":
				weather.set_weather(&"clear")
				power.tick(0.01, input(true))
			"pause":
				paused = true
				await create_timer(0.02, true, false, true).timeout
				paused = false
			"death":
				var lethal = DAMAGE.new(10000, Vector3.ZERO, Vector3.ZERO, &"none", null)
				hero.apply_damage(lethal)
		check(not power.casting and is_equal_approx(Engine.time_scale, 0.8) and weather.lightning_strike_cooldown_remaining == 0, reason + " restores time without cooldown")
		check(is_equal_approx(AudioServer.playback_speed_scale, Engine.time_scale), reason + " restores matching global audio speed")
	Engine.time_scale = 1
	AudioServer.playback_speed_scale = 1
	weather.set_weather(&"clear")
	arena.free()
	await process_frame
	print("LIGHTNING_STRIKE_TESTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

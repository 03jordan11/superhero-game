extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var power: PlayerExternalCombustion
var cooldowns: Node
var slow: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func input(held := false, pressed := false, released := false, aim := false) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.secondary_power_pressed = held
	value.secondary_power_just_pressed = pressed
	value.secondary_power_just_released = released
	value.aim_power_pressed = aim
	return value

func reset(heat := 0.0, tier := 3) -> void:
	power.cancel()
	slow.cancel_all()
	hero.revive_for_respawn()
	hero.get_node("PlayerPowerController").progression.apply_save_data({"schema_version": 2, "upgrades": {"fire": tier, "flight": 0, "electricity": 3}})
	hero.get_node("PlayerPowerController").select_active_power(&"fire")
	cooldowns.external_combustion_cooldown_remaining = 0.0
	hero.laser_eyes.heat = heat
	hero.laser_eyes.overheated = false
	hero.laser_eyes._require_release = false
	hero.global_position = Vector3(0, 0.05, 0)
	hero.velocity = Vector3.ZERO
	power.tick(0.01, input())

func run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	hero.set_physics_process(false)
	hero.set_process_input(false)
	power = hero.external_combustion
	power.set_process(false)
	cooldowns = root.get_node("Weather")
	cooldowns.set_physics_process(false)
	slow = root.get_node("SlowMotion")
	slow.set_process(false)
	await physics_frame
	reset(50, 2)
	power.tick(0.01, input(true, true))
	check(not power.casting and not power.try_passive(), "Tier 3 required for manual and passive combustion")
	reset(0)
	power.tick(0.05, input(true, true))
	power.tick(0.01, input(false, false, true))
	check(not power.casting and cooldowns.external_combustion_cooldown_remaining == 0, "Under ten heat fails without cooldown")
	reset(10)
	check(power.erupt() and power.last_damage == 10 and power.last_radius == 1, "Ten heat is minimum damage and radius")
	check(hero.laser_eyes.heat == 0 and cooldowns.external_combustion_cooldown_remaining == 300, "Small release clears heat and spends full cooldown")
	reset(55)
	check(power.erupt() and power.last_damage == 40 and power.last_radius == 4.5, "Heat interpolates damage and radius linearly")
	reset()
	power.tick(1.0, input(true, true))
	check(power.charging and hero.laser_eyes.heat == 50, "One second adds fifty heat")
	power.tick(1.0, input(true))
	power.tick(5.0, input(true))
	check(power.charging and hero.laser_eyes.heat == 100 and not hero.laser_eyes.overheated and cooldowns.external_combustion_cooldown_remaining == 0, "Manual full charge holds safely without passive eruption")
	var hp := hero.get_current_health()
	var bullet = DAMAGE.new(7, Vector3.ZERO, Vector3.FORWARD, &"knockback", null)
	bullet.damage_type = &"bullet"
	hero.apply_damage(bullet)
	check(hero.get_current_health() == hp - 7 and power.charging and not hero.animation_controller.is_hit_reacting and hero.status_effects.hit_slowdown_remaining == 0, "Charging takes health damage without stun")
	var kinds: Array[StringName] = [&"melee_thug", &"pistol_thug", &"rifle_thug", &"super_thug"]
	var victims: Array[HostileBase] = []
	var health: Array[float] = []
	for i in kinds.size():
		var enemy := arena.spawn_enemy(kinds[i]) as HostileBase
		enemy.set_physics_process(false)
		enemy.global_position = hero.global_position + Vector3((i + 1) * 1.99, 0, 0)
		victims.append(enemy)
		health.append(enemy.get_current_health())
	var outside := arena.spawn_enemy(&"super_thug") as HostileBase
	outside.set_physics_process(false)
	outside.global_position = hero.global_position + Vector3(8.01, 0, 0)
	var outside_hp := outside.get_current_health()
	power.tick(0.01, input(false, false, true))
	check(power.last_damage == 70 and power.last_radius == 8 and hero.get_current_health() == hp - 7, "Full release has eight meter radius, seventy damage, no self-damage")
	for i in victims.size():
		check(victims[i].get_current_health() == health[i] - 70 and victims[i].knockback_velocity.length() > 0, "Damages and knocks back " + String(kinds[i]))
	check(outside.get_current_health() == outside_hp, "Beyond radius is excluded")
	check(Engine.time_scale == 1.0, "Explosion starts an eased transition")
	slow._advance(0.1)
	check(Engine.time_scale == 0.5 and AudioServer.playback_speed_scale == 0.5, "Explosion slows game and audio to half speed")
	power._process(1.4)
	slow._advance(0.25)
	check(Engine.time_scale > 0.5 and Engine.time_scale < 1.0, "Explosion ends with gradual recovery")
	slow._advance(0.25)
	check(Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0, "Recovery completes")
	hero.get_node("GameplayHUD")._refresh_cooldowns()
	check(hero.get_node("GameplayHUD/Cooldowns/ExternalCombustion").text.contains("300"), "Cooldown appears on existing text HUD")
	reset(50)
	power.tick(1.0, input(true, true))
	check(hero.laser_eyes.heat == 100, "Existing fifty heat halves remaining charge time")
	var origin := hero.global_position
	hero.velocity = Vector3(12, 4, 12)
	power.tick(0.1, input(true))
	check(hero.global_position == origin and hero.velocity == Vector3.ZERO, "Charging is immobile")
	power.tick(0.01, input())
	check(not power.casting and cooldowns.external_combustion_cooldown_remaining == 0, "Suppressed input cancels without firing")
	reset(50)
	hero.state_machine.transition_to(&"FlyingState")
	power.tick(1.0, input(true, true))
	check(power.charging and hero.is_flying and hero.velocity == Vector3.ZERO, "Can charge while hovering in flight")
	hero.apply_damage(bullet)
	check(hero.is_flying and power.charging, "Bullet cannot knock charging hero out of flight")
	power.tick(0.01, input(false, false, true))
	check(hero.is_flying and hero.laser_eyes.heat == 0, "Flight survives release")
	reset(100)
	var helicopter: Node3D = arena.spawn_enemy(&"helicopter")
	helicopter.set_physics_process(false)
	helicopter.global_position = hero.global_position + Vector3(0, 4, 0)
	power.erupt()
	check(helicopter.get_current_health() == 30 and helicopter.velocity == Vector3.ZERO and helicopter.flight.velocity == Vector3.ZERO, "Close aircraft takes damage without knockback")
	helicopter.free()
	reset(99)
	hp = hero.get_current_health()
	hero.laser_eyes.update_power(0.1, input(true, true, false, true))
	check(cooldowns.external_combustion_cooldown_remaining == 300 and hero.laser_eyes.heat == 0 and hero.get_current_health() == hp, "Aimed fire at full heat automatically erupts without self-damage")
	hero.laser_eyes.heat = 99
	hero.laser_eyes._require_release = false
	hero.laser_eyes.update_power(0.1, input(true, true, false, true))
	check(hero.laser_eyes.overheated and hero.get_current_health() == hp - floorf(hero.get_max_health() * 0.3), "Cooldown preserves normal damaging overheat")
	reset(100)
	hero.get_node("PlayerPowerController").select_active_power(&"electricity")
	check(not power.try_passive(), "Passive only works with Fire selected")
	reset(50)
	power.tick(0.01, input(true, true, false, true))
	check(not power.casting, "Aim plus Q remains Dragon Breath")
	hero.laser_eyes.update_power(0.1, input(true, false, false, true))
	check(hero.get_node("PlayerFire").breathing, "Aimed Q still starts breath")
	reset(50)
	power.tick(0.1, input(true, true))
	hero.get_node("PlayerPowerController").select_active_power(&"electricity")
	check(not power.casting and cooldowns.external_combustion_cooldown_remaining == 0, "Power switch cancels without spending cooldown")
	reset(50)
	power.tick(0.1, input(true, true))
	hero.apply_damage(DAMAGE.new(10000))
	check(hero.is_dead and not power.casting and cooldowns.external_combustion_cooldown_remaining == 0, "Lethal damage still kills and cancels charging")
	reset(100)
	power.erupt()
	slow._advance(0.1)
	paused = true
	slow._process(0)
	check(not power.casting and Engine.time_scale == 1 and AudioServer.playback_speed_scale == 1, "Pause restores audio/game speed")
	paused = false
	reset(100)
	power.erupt()
	slow._advance(0.1)
	var cooldown := float(cooldowns.external_combustion_cooldown_remaining)
	arena.free()
	check(cooldowns.external_combustion_cooldown_remaining == cooldown, "Scene teardown preserves cooldown")
	check(Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0, "Scene teardown restores time even during explosion")
	print("EXTERNAL_COMBUSTION_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

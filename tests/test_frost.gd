extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var power: PlayerFrost

func _initialize() -> void:
	create_timer(45, true, false, true).timeout.connect(func(): push_error("Frost test timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func enemy(kind := &"melee_thug") -> HostileBase:
	var victim := arena.spawn_enemy(kind) as HostileBase
	victim.set_physics_process(false)
	return victim

func expose(victim: HostileBase, seconds: float) -> void:
	victim.frost.receive(victim, hero, seconds, power)
	victim.frost.update(seconds)

func input(aim := true, attack := true, special := false) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.aim_power_pressed = aim
	value.activate_power_pressed = attack
	value.secondary_power_pressed = special
	return value

func run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	hero.set_physics_process(false)
	hero.set_process_input(false)
	power = hero.get_node("PlayerFrost")
	await physics_frame
	var powers := hero.get_node("PlayerPowerController")
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"ice": 0}})
	powers.select_active_power(&"ice")
	hero.laser_eyes.update_power(0.1, input(false, false))
	hero.laser_eyes.update_power(0.1, input())
	check(not power.firing and not hero.abilities.is_unlocked(PlayerAbilities.ICE), "Core alone does not grant Frost Breath or fists")
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"ice": 1}})
	hero.laser_eyes.update_power(0.1, input(false, false))
	hero.laser_eyes.update_power(0.1, input(true, false, true))
	check(not power.firing, "Aim plus Q is reserved for future Frost powers")
	hero.laser_eyes.update_power(0.1, input(false, false))
	hero.laser_eyes.update_power(0.5, input())
	check(power.firing and hero.laser_eyes.heat == 7.5 and hero.laser_eyes.aiming, "Tier one Aim plus Attack emits frost at fifteen heat per second")
	hero.laser_eyes.heat = 0.0
	hero.laser_eyes.update_power(power.super_freeze_seconds, input())
	check(power.firing and hero.laser_eyes.heat == 75.0 and not hero.laser_eyes.overheated, "Five seconds of breath leaves enough heat capacity to freeze a super")
	check(is_equal_approx(power._breath.spread, 0.25), "Frost uses Fire's cone spread")
	hero.input_controller.reset()
	check(not power.firing and not power._breath.visible, "Input reset cancels breath")
	var normal := enemy()
	expose(normal, 1.5)
	check(is_equal_approx(normal.get_current_health(), 92.5) and not normal.frost.frozen, "Unfrozen breath deals five damage per second")
	check(normal.action_speed < 1 and normal.action_speed > 0 and is_equal_approx(normal.animation_controller.animation_player.speed_scale, normal.action_speed), "Movement and animations slow together")
	var reduced := normal.action_speed
	normal.frost.update(0.5)
	check(is_equal_approx(normal.frost.buildup, 1) and normal.action_speed > reduced and normal.action_speed < 1, "Buildup and slow gradually wear off")
	expose(normal, 2.0)
	check(normal.frost.frozen and normal.current_state == normal.State.FROZEN and normal.action_speed == 0 and normal.animation_controller.animation_player.speed_scale == 0, "Three accumulated seconds freezes normal enemy")
	check(normal.frost.effect.visible, "Frozen state displays ice shell")
	var hp := normal.get_current_health()
	normal.frost.update(5.0)
	check(is_equal_approx(normal.get_current_health(), hp - 50) and not normal.frost.frozen and normal.action_speed == 1 and normal.animation_controller.animation_player.speed_scale == 1, "Five ticks then automatic thaw restores animation and movement")
	var super_enemy := enemy(&"super_thug")
	expose(super_enemy, 3.0)
	check(not super_enemy.frost.frozen and super_enemy.action_speed < 1, "Super remains mobile after three seconds")
	expose(super_enemy, 2.0)
	check(super_enemy.frost.frozen and super_enemy.get_current_health() == 475, "Super freezes at five seconds with twenty-five buildup damage")
	hp = super_enemy.get_current_health()
	for i in 20: expose(super_enemy, 0.1)
	check(is_equal_approx(super_enemy.get_current_health(), hp - 20) and is_equal_approx(super_enemy.frost.remaining, 5.0), "Continued frost refreshes expiry, keeps periodic damage, adds no breath damage")
	var melee = DAMAGE.new(1, hero.global_position, Vector3.FORWARD, &"chest", hero)
	melee.damage_type = &"melee"
	super_enemy.apply_damage(melee)
	var beam = DAMAGE.new(1, hero.global_position, Vector3.ZERO, &"none", hero)
	beam.damage_type = &"laser"
	super_enemy.apply_damage(beam)
	check(super_enemy.frost.frozen and super_enemy.frost.melee_hits == 1, "Continuous attacks cannot break ice")
	expose(super_enemy, 1.0)
	check(super_enemy.frost.melee_hits == 1, "Refreshing ice does not reset melee hits")
	super_enemy.apply_damage(melee)
	check(super_enemy.frost.frozen, "Ice survives two melee hits")
	super_enemy.apply_damage(melee)
	check(not super_enemy.frost.frozen and super_enemy.action_speed == 1, "Third melee hit breaks ice")
	hp = super_enemy.get_current_health()
	super_enemy.frost.update(10)
	check(super_enemy.get_current_health() == hp, "Breaking ice cancels remaining periodic damage")
	# Status ownership must not restore another status's paused animation speed.
	expose(super_enemy, 2.0)
	super_enemy.electrified.begin(super_enemy, hero, 2.5, 15, 10)
	check(super_enemy.frost.buildup == 0 and super_enemy.electrified.active, "Shock replaces frost buildup cleanly")
	expose(super_enemy, 5.0)
	check(super_enemy.frost.frozen and not super_enemy.electrified.active, "Frost replaces shock cleanly")
	super_enemy.frost.cancel()
	check(super_enemy.animation_controller.animation_player.speed_scale == 1, "Mixed statuses restore original animation speed")
	var dying := enemy()
	expose(dying, 3)
	dying.health_component.current_health = 5
	dying.frost.update(1)
	check(dying.is_dead and not dying.frost.frozen and dying.animation_controller.animation_player.speed_scale == 1, "Frozen damage kills and releases the frozen pose")
	# Geometry: cone widening, cover, and targets behind the hero.
	var inside := enemy()
	var outside := enemy()
	var behind := enemy()
	inside.global_position = Vector3(2, 0, -10)
	outside.global_position = Vector3(5, 0, -10)
	behind.global_position = Vector3(0, 0, 2)
	await physics_frame
	power._breath.set_stream(Vector3(0, 1, 0), Vector3(0, 1, -12), 0.25)
	power._breath.apply_frost(1, hero, power)
	for target in [inside, outside, behind]: target.frost.update(1)
	check(inside.frost.buildup == 1 and outside.frost.buildup == 0 and behind.frost.buildup == 0, "Cone includes edge targets, excludes outside and behind")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 5, 0.3)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = Vector3(0, 2, -5)
	await physics_frame
	power._breath.apply_frost(1, hero, power)
	inside.frost.update(1)
	check(inside.frost.buildup == 0, "Walls block frost and allow buildup to thaw")
	wall.free()
	# Real NPC movement and attack timers use the same local slowdown as animation.
	hero.global_position = Vector3(0, 0.1, 0)
	var mover := enemy() as MeleeHostile
	mover.global_position = Vector3(0, 0.05, -20)
	mover.combat_target = hero
	mover.current_state = mover.State.COMBAT
	mover.has_attack_slot = true
	mover.melee_state = mover.MeleeState.APPROACH
	mover.approach_remaining = 4.0
	mover.combat_action_delay_remaining = 0.0
	expose(mover, 1.5)
	mover.frost.receive(mover, hero, 0.1, power)
	await physics_frame
	mover._physics_process(0.1)
	check(is_equal_approx(Vector2(mover.velocity.x, mover.velocity.z).length(), mover.approach_speed * mover.action_speed), "Actual approach velocity uses the frost multiplier")
	mover.melee_state = mover.MeleeState.ATTACK
	mover.punch_elapsed = 0.0
	mover.punch_resolved = false
	mover.opening_windup_remaining = 0.0
	mover.animation_controller.play_melee_punch(0, 1.0)
	mover.frost.receive(mover, hero, 0.1, power)
	mover._physics_process(0.1)
	check(is_equal_approx(mover.punch_elapsed, 0.1 * mover.action_speed), "Actual melee impact timer slows with animation")
	mover.free()
	# Exercise real player punch tagging rather than only crafted damage payloads.
	for old in arena.opponents.get_children(): old.free()
	hero.revive_for_respawn()
	hero.global_position = Vector3(0, 0.1, 0)
	var punched := enemy()
	punched.global_position = hero.global_position - hero.global_basis.z * 2.0
	expose(punched, 3.0)
	await physics_frame
	for i in 3:
		check(hero.combat_controller._try_hit_target(hero, 1), "Real punch reaches frozen target")
		check(punched.frost.frozen == (i < 2), "Real punches break ice on hit three")
	punched.free()
	# Frozen targets are immediately freed by an actual grab action.
	hero.revive_for_respawn()
	hero.global_position = Vector3(0, 0.1, 0)
	hero.superhero_character.rotation = hero.superhero_character_default_rotation
	var grabbed := enemy()
	grabbed.global_position = hero.global_position + hero.superhero_character.global_basis.z.normalized() * 1.5
	expose(grabbed, 3)
	await physics_frame
	check(hero.hostile_grab.try_grab() and not grabbed.frost.frozen and grabbed.is_grabbed, "Grab breaks ice before taking animation ownership")
	hero.hostile_grab.drop()
	# Shared normal overheat still applies and can no longer emit frost.
	hero.laser_eyes.heat = 99
	hero.laser_eyes.overheated = false
	hero.laser_eyes._require_release = false
	hero.laser_eyes.update_power(0.2, input())
	check(hero.laser_eyes.overheated and not power.firing, "Frost reaches normal overheat and stops")
	arena.free()
	await process_frame
	print("FROST_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

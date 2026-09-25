extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var electric: PlayerElectricity

func _initialize() -> void:
	create_timer(40, true, false, true).timeout.connect(func(): push_error("Reactive Shock test timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func spawn(kind := &"melee_thug") -> HostileBase:
	hero.hostile_grab.drop()
	hero.anticipation.cancel()
	hero.revive_for_respawn()
	for enemy in arena.opponents.get_children(): enemy.free()
	var enemy: HostileBase = arena.spawn_enemy(kind)
	enemy.set_physics_process(false)
	enemy.global_position = hero.global_position + Vector3(0, -1, -1.8)
	enemy.look_at(Vector3(hero.global_position.x, enemy.global_position.y, hero.global_position.z))
	return enemy

func hit(attacker: Node3D, kind := &"melee") -> bool:
	var info = DAMAGE.new(1.0, attacker.global_position, Vector3.FORWARD, &"chest", attacker)
	info.damage_type = kind
	return hero.apply_damage(info)

func electrify(enemy: HostileBase) -> void:
	check(enemy.electrified.begin(enemy, hero, 2.5, 15, 10), "Can enter Electrified")

func run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	electric = hero.get_node("PlayerElectricity")
	for frame in 20: await physics_frame
	hero.set_physics_process(false)
	check(not electric.get_node("ElectrifiedPreparation").visible, "Effect is prepared invisibly on player load")
	var powers = hero.get_node("PlayerPowerController").progression
	hero.get_node("PlayerPowerController").select_active_power(&"electricity")
	var progression = load("res://scripts/ui-scripts/power_menu_progression.gd").new()
	progression.add_tokens(2)
	check(progression.purchase("electricity") and progression.purchase("electricity"), "Core and Reactive Shock can be purchased sequentially")
	var enemy := spawn()
	check(is_equal_approx(electric.reactive_hit_chance(enemy), 0.2), "Normal melee chance defaults to 20 percent")
	electric.reactive_chance = 1.0
	hit(enemy)
	check(not enemy.electrified.active, "Locked upgrade cannot retaliate")
	powers.apply_save_data({"schema_version": 2, "upgrades": {"electricity": 0}})
	hit(enemy)
	check(not enemy.electrified.active, "Core alone cannot retaliate")
	powers.apply_save_data(progression.to_save_data())
	check(powers.level("electricity") == 1, "Reactive unlock restores from save data")
	for selected in [&"fire", &"ice", &"laser_eyes"]:
		hero.get_node("PlayerPowerController").select_active_power(selected)
		hit(enemy)
		check(not enemy.electrified.active, "Reactive Shock cannot trigger while " + String(selected) + " is selected, even at guaranteed proc chance")
	hero.get_node("PlayerPowerController").select_active_power(&"electricity")
	hit(enemy, &"bullet")
	check(not enemy.electrified.active, "Bullets cannot trigger Reactive Shock")
	hero.is_dodging = true
	check(not hit(enemy) and not enemy.electrified.active, "Ignored roll hits cannot retaliate")
	hero.is_dodging = false
	powers.apply_save_data({"schema_version": 2, "upgrades": {"electricity": 1, "mind": 1}})
	enemy.has_attack_slot = true
	enemy._start_combo()
	check(hero.anticipation.begin_evade(enemy), "Counter duck starts for protection test")
	check(not hit(enemy) and not enemy.electrified.active, "Ignored counter hits cannot retaliate")
	hero.anticipation.cancel()
	electric.reactive_chance = 0.0
	hit(enemy)
	check(not enemy.electrified.active, "Failed chance roll leaves enemy unaffected")
	electric.reactive_chance = 1.0
	# Hit through the actual melee attack update, including synchronous interruption.
	hero.revive_for_respawn()
	enemy.has_attack_slot = true
	enemy._start_combo()
	enemy.opening_windup_remaining = 0.0
	var hp := hero.get_current_health()
	var heat := hero.laser_eyes.heat
	enemy._update_attack(0.21)
	check(enemy.electrified.active and enemy.current_state == enemy.State.ELECTRIFIED, "Successful melee hit enters Electrified")
	check(hero.get_current_health() < hp and hero.laser_eyes.heat == heat, "Passive does not negate triggering damage or spend Heat")
	check(enemy.punch_resolved and enemy.punches_started == 0, "Reactive Shock interrupts the combo immediately")
	var animation: AnimationPlayer = enemy.animation_controller.animation_player
	var pose := animation.current_animation_position
	var position := enemy.global_position
	enemy.receive_alert(hero)
	await create_timer(0.08).timeout
	check(animation.speed_scale == 0 and animation.current_animation_position == pose, "Animation is frozen, including after ally alerts")
	enemy._physics_process(0.99)
	check(enemy.get_current_health() == 100 and enemy.global_position == position, "No early tick or enemy movement")
	enemy._physics_process(0.01)
	check(enemy.get_current_health() == 85 and enemy.electrified.active, "First whole-second tick deals 15")
	check(not enemy.electrified.begin(enemy, hero, 2.5, 15, 10), "Active status does not stack or reset its schedule")
	enemy._physics_process(1.0)
	check(enemy.get_current_health() == 70, "Second whole-second tick deals 15")
	enemy._physics_process(0.49)
	check(enemy.get_current_health() == 70 and enemy.electrified.active, "No fractional tick before expiry")
	enemy._physics_process(0.01)
	check(enemy.get_current_health() == 60 and not enemy.electrified.active, "Expiry deals final 10 for exactly 40 total")
	check(animation.speed_scale == 1 and enemy.current_state == enemy.State.COMBAT, "Expiry restores animation and AI state")
	check(enemy.electrified.effect == null, "Expiry removes electricity visuals")
	enemy = spawn(&"super_thug")
	check(is_equal_approx(electric.reactive_hit_chance(enemy), 0.05), "Super chance defaults to 5 percent")
	electric.reactive_super_chance = 1.0
	hit(enemy)
	check(enemy.electrified.active, "Super can be electrified")
	var super_hp := enemy.get_current_health()
	enemy._physics_process(3.0)
	check(enemy.get_current_health() == super_hp - 40 and not enemy.electrified.active, "Long frames catch both ticks and expiry once, including supers")
	enemy = spawn(&"pistol_thug")
	hit(enemy)
	check(not enemy.electrified.active, "Non-melee character is not eligible")
	# Every player attack type cancels, while preserving damage already ticked.
	for kind in [&"melee", &"electricity", &"fire", &"laser", &"explosion"]:
		enemy = spawn()
		electrify(enemy)
		enemy._physics_process(1.0)
		var strike = DAMAGE.new(7.0, hero.global_position, Vector3.FORWARD, &"chest", hero)
		strike.damage_type = kind
		enemy.apply_damage(strike)
		enemy.electrified.update(5.0)
		check(not enemy.electrified.active and enemy.get_current_health() == 78, String(kind) + " cancels all remaining status damage and applies its own hit")
		check(enemy.animation_controller.animation_player.speed_scale == 1, "Attack restores animation playback")
	enemy = spawn()
	electrify(enemy)
	enemy._physics_process(1.0)
	await physics_frame
	check(hero.hostile_grab.try_grab(), "Player can grab an electrified normal enemy")
	check(not enemy.electrified.active and enemy.is_grabbed, "Successful grab clears Electrified before taking animation ownership")
	enemy.electrified.update(5.0)
	check(enemy.get_current_health() == 85 and enemy.animation_controller.animation_player.speed_scale == 1, "Grab cancels remaining damage and unfreezes paired animation")
	hero.hostile_grab.drop()
	enemy = spawn()
	electrify(enemy)
	enemy.health_component.current_health = 10
	enemy._physics_process(1.0)
	check(enemy.is_dead and not enemy.electrified.active and enemy.animation_controller.animation_player.speed_scale == 1, "Lethal tick cleans up before death animation")
	enemy = spawn()
	electrify(enemy)
	enemy.set_physics_process(true)
	paused = true
	await create_timer(0.1, true, false, true).timeout
	check(enemy.electrified.elapsed == 0 and enemy.electrified.effect.elapsed == 0, "Pause freezes status timer and electricity shader")
	paused = false
	enemy.set_physics_process(false)
	if "--render" in OS.get_cmdline_user_args():
		hero.get_node("GameplayHUD").hide()
		hero.hide()
		var camera := Camera3D.new()
		arena.add_child(camera)
		camera.global_position = enemy.global_position + Vector3(3.5, 2.0, 4.8)
		camera.look_at(enemy.global_position + Vector3.UP * 1.2)
		camera.make_current()
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/reactive_shock.png")
	arena.free()
	await process_frame
	print("REACTIVE_SHOCK failures=", failures)
	quit(1 if failures else 0)

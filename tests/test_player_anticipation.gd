extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var arena: Node3D
var hero: PlayerCharacter
var counter: Node
var damage_events := 0

func capture(label: String) -> void:
	if "--render" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/anticipation_" + label + ".png")

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): push_error("Anticipation timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func control(pressed: bool, echo := false, right := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_CTRL
	event.location = KEY_LOCATION_RIGHT if right else KEY_LOCATION_LEFT
	event.pressed = pressed
	event.echo = echo
	return event

func attack() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func prepare(id: StringName = &"melee_thug") -> Node3D:
	counter.cancel()
	counter.handle_event(control(false))
	hero.revive_for_respawn()
	for opponent in arena.opponents.get_children(): opponent.free()
	var enemy: Node3D = arena.spawn_enemy(id)
	enemy.set_physics_process(false)
	enemy.global_position = hero.global_position + Vector3(0, -1.0, -1.8)
	enemy.look_at(Vector3(hero.global_position.x, enemy.global_position.y, hero.global_position.z))
	enemy.has_attack_slot = true
	enemy.combat_action_delay_remaining = 0.0
	enemy._start_combo()
	return enemy

func resolve(enemy: Node3D) -> void:
	enemy.punch_resolved = true
	enemy._try_punch_hit()

func check_hits_ignored(label: String) -> void:
	var hp := hero.get_current_health()
	var phase: int = counter.phase
	var animation := hero.character_animation_player.current_animation
	var time_scale := Engine.time_scale
	var cooldown: float = hero.damage_receiver.regeneration_cooldown
	var events_before := damage_events
	for kind in [&"bullet", &"melee", &"explosion", &"generic"]:
		var hit = DAMAGE.new(10000.0, Vector3.ZERO, Vector3.FORWARD, &"knockback")
		hit.damage_type = kind
		hit.force_knockdown = true
		check(not hero.apply_damage(hit), label + " ignores " + String(kind))
	check(hero.get_current_health() == hp and not hero.is_dead, label + " preserves health even against lethal hits")
	check(counter.phase == phase and Engine.time_scale == time_scale, label + " preserves the counter and slow motion")
	check(hero.character_animation_player.current_animation == animation and not hero.animation_controller.is_hit_reacting and not hero.is_knocked_out, label + " cannot flinch or be knocked down")
	check(hero.status_effects.hit_slowdown_remaining == 0.0, label + " cannot receive hit slowdown")
	check(damage_events == events_before and hero.damage_receiver.regeneration_cooldown == cooldown, label + " emits no damage or regeneration reset")

func run() -> void:
	# Keep these action-timing regressions deterministic; eased transitions have their own tests.
	root.get_node("SlowMotion").ease_in_seconds = 0.0
	root.get_node("SlowMotion").ease_out_seconds = 0.0
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	hero = arena.player
	counter = hero.anticipation
	hero.damage_receiver.damage_received.connect(func(_info): damage_events += 1)
	for frame in 20: await physics_frame
	hero.set_physics_process(false)
	var enemy := prepare()
	check(not counter.enabled() and counter.pending_attacker() == null, "Locked tier has no warning")
	hero.get_node("PlayerPowerController").progression.apply_save_data({"schema_version": 2, "upgrades": {"mind": 1}})
	enemy = prepare()
	check(counter.pending_attacker() == enemy, "Opening swing is warned")
	check(is_equal_approx(enemy.opening_windup_remaining + enemy.punch_hit_delay, 0.35), "Normal opening has readable 0.35 second warning")
	counter._process(0)
	check(counter.warning.visible, "Red warning visible")
	await capture("warning")
	counter.handle_event(control(true, false, true))
	check(not counter.active(), "Right Ctrl does not activate counter evade")
	counter.handle_event(control(true, true))
	check(not counter.active(), "Key repeat cannot activate evade")
	hero.combat_controller.request_punch()
	var stamina := hero.stamina.current
	check(counter.handle_event(control(true)) and counter.active(), "Fresh Left Ctrl ducks while stationary")
	check(not hero.combat_controller.is_action_locked(), "Duck cancels ordinary punch")
	check(is_equal_approx(hero.stamina.current, stamina - hero.stamina.maximum * 0.1), "Duck spends 10 percent stamina")
	hero.character_animation_player.advance(0.12)
	await capture("duck")
	var hp := hero.get_current_health()
	counter.handle_event(attack())
	resolve(enemy)
	check(hero.get_current_health() == hp and counter.phase == counter.Phase.READY, "Opening hit evaded without damage")
	check(is_equal_approx(Engine.time_scale, 0.4), "Successful evade triggers slow motion")
	check(is_equal_approx(AudioServer.playback_speed_scale, Engine.time_scale), "Counter slow motion scales all audio identically")
	var enemy_hp: float = enemy.get_current_health()
	counter.tick(0.01 * Engine.time_scale)
	check(counter.phase == counter.Phase.COUNTER, "Attack buffered during duck starts counter")
	counter.tick(0.21 * Engine.time_scale)
	check(enemy.get_current_health() == enemy_hp, "Counter impact waits for the slowed animation")
	counter.tick(0.13)
	var damage: float = 2.0 * hero.stats.get_effective_strength() * hero.combat_controller.regular_hit_damage_multiplier
	check(is_equal_approx(enemy.get_current_health(), enemy_hp - damage), "Counter deals double normal punch damage once")
	check(enemy.is_waiting_for_knockback_stun, "Normal thug knocked down")
	hero.character_animation_player.advance(0.2)
	await capture("counter")
	counter.tick(0.1 * Engine.time_scale)
	check(is_equal_approx(enemy.get_current_health(), enemy_hp - damage), "Counter cannot hit twice")
	counter.cancel()
	check(Engine.time_scale == 1.0, "Cancellation restores time")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Counter cancellation restores audio speed")

	enemy = prepare(&"super_thug")
	# Super's 0.4 second windup enters the last 0.35 seconds before warning.
	enemy.punch_elapsed = 0.06
	check(counter.pending_attacker() == enemy, "Super opening enters warning window")
	counter.handle_event(control(true))
	resolve(enemy)
	counter.handle_event(attack())
	counter.tick(0.01 * Engine.time_scale)
	counter.tick(0.21)
	check(enemy.is_waiting_for_chest_hit_stun and not enemy.is_waiting_for_knockback_stun, "Super staggers instead of falling")
	counter.cancel()

	enemy = prepare()
	enemy.punches_started = 2
	check(counter.pending_attacker() == null, "Later combo swings do not warn")
	counter.handle_event(control(true))
	check(not counter.active(), "Later swings cannot trigger duck")
	enemy.punches_started = 1
	counter.handle_event(control(true, true))
	counter.handle_event(control(true))
	check(not counter.active(), "Holding Ctrl before warning cannot activate on window opening")
	counter.handle_event(control(false))
	counter.handle_event(control(true))
	check(counter.active(), "Release then press enables a new evade")
	var bullet = DAMAGE.new(5.0)
	bullet.damage_type = &"bullet"
	check_hits_ignored("Duck")
	resolve(enemy)
	counter.tick(0.4 * Engine.time_scale)
	check(counter.phase == counter.Phase.READY, "Counter opportunity remains available beyond the old protection timer")
	check_hits_ignored("Counter opportunity")
	counter.handle_event(attack())
	counter.tick(0.01 * Engine.time_scale)
	check_hits_ignored("Counter swing")
	var protected_target_hp: float = enemy.get_current_health()
	counter.tick(0.5)
	check(enemy.get_current_health() == protected_target_hp - damage, "Incoming hits do not prevent counter damage")
	check_hits_ignored("Counter recovery")
	counter.tick(0.16)
	check(not counter.active(), "Protection ends when counter recovery completes")
	var recovered_hp := hero.get_current_health()
	check(hero.apply_damage(bullet) and hero.get_current_health() < recovered_hp, "Gunfire damages hero again after counter completion")
	check(hero.animation_controller.is_hit_reacting, "Gunfire can flinch hero again after counter completion")

	enemy = prepare()
	counter.handle_event(control(true))
	resolve(enemy)
	paused = true
	counter._process(0)
	check(not counter.active() and Engine.time_scale == 1.0, "Pause cancels action and restores time")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Pausing the counter restores audio speed")
	paused = false
	enemy = prepare()
	counter.handle_event(control(true))
	resolve(enemy)
	counter.tick(0.51 * Engine.time_scale)
	check(not counter.active(), "Counter opportunity expires in real-time units")
	check(hero.apply_damage(bullet), "Expired counter opportunity leaves no hit immunity")

	enemy = prepare()
	var second: Node3D = arena.spawn_enemy(&"melee_thug")
	second.set_physics_process(false)
	second.global_position = hero.global_position + Vector3(1.5, -1, -0.5)
	second.has_attack_slot = true
	second.combat_action_delay_remaining = 0.0
	second._start_combo()
	second.opening_windup_remaining = 0.0
	second.punch_elapsed = 0.1
	check(counter.pending_attacker() == second, "Overlapping openings select the earliest incoming hit")
	second.free()
	counter.handle_event(control(true))
	enemy._reset_combat_actions()
	counter.tick(0.01)
	check(not counter.active() and Engine.time_scale == 1.0, "Canceled enemy attack cannot grant a counter or slow motion")
	enemy = prepare()
	counter.begin_evade(enemy)
	resolve(enemy)
	counter.handle_event(attack())
	counter.tick(0.01 * Engine.time_scale)
	var ranged_hp: float = enemy.get_current_health()
	enemy.global_position += Vector3(20, 0, 0)
	counter.tick(0.21)
	check(enemy.get_current_health() == ranged_hp, "Counter cannot damage distant enemies or dash to them")
	counter.cancel()

	enemy = prepare()
	hero.stamina.current = 0.0
	check(not counter.begin_evade(enemy), "Insufficient stamina blocks evade")
	hero.stamina.restore_full()
	hero.is_flying = true
	check(not counter.begin_evade(enemy), "Flight blocks evade")
	hero.is_flying = false
	hero.combat_controller.charge_phase = PlayerCombatController.ChargePhase.HOLD
	check(not counter.begin_evade(enemy), "Charged attacks block evade")
	hero.combat_controller.cancel_punch()
	counter.begin_evade(enemy)
	resolve(enemy)
	await create_timer(0.55, true, false, true).timeout
	check(Engine.time_scale == 1.0, "Slow motion expires after real-world duration")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Counter slow-motion expiry restores audio speed")
	counter.cancel()
	enemy = prepare()
	counter.begin_evade(enemy)
	resolve(enemy)
	enemy.is_dead = true
	counter.tick(0.01 * Engine.time_scale)
	check(not counter.active() and is_equal_approx(Engine.time_scale, 0.4), "Defeating the target does not truncate slow motion")
	await create_timer(0.55, true, false, true).timeout
	check(Engine.time_scale == 1.0, "Slow motion expires even after the action has ended")

	# Real engine event routing and live physics: no direct counter entry/hit calls.
	enemy = prepare()
	hero.set_physics_process(true)
	enemy.set_physics_process(true)
	Input.parse_input_event(control(false))
	Input.parse_input_event(control(true))
	Input.flush_buffered_events()
	check(counter.active(), "Left Ctrl event reaches player controller")
	while counter.phase == counter.Phase.DUCK: await physics_frame
	check(counter.phase == counter.Phase.READY, "Live opening punch resolves into evade")
	Input.parse_input_event(attack())
	Input.flush_buffered_events()
	var live_hp: float = enemy.get_current_health()
	while counter.phase == counter.Phase.READY: await physics_frame
	await process_frame
	var animation_start := hero.character_animation_player.current_animation_position
	var real_start := Time.get_ticks_usec()
	await create_timer(0.18, true, false, true).timeout
	var real_seconds := float(Time.get_ticks_usec() - real_start) / 1000000.0
	var animation_seconds := hero.character_animation_player.current_animation_position - animation_start
	print("ANTICIPATION_SLOW_MOTION real_seconds=", real_seconds, " animation_seconds=", animation_seconds)
	check(absf(animation_seconds - real_seconds * counter.slow_motion_scale) < 0.035, "Live hero animation advances at 40 percent real speed")
	check(enemy.get_current_health() == live_hp, "Live counter damage stays synchronized with slowed animation")
	while counter.active(): await physics_frame
	check(enemy.get_current_health() <= live_hp - damage, "Live attack event executes counter through physics")
	Input.parse_input_event(control(false))
	var release := attack()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	enemy = prepare()
	counter.begin_evade(enemy)
	resolve(enemy)
	arena.free()
	check(Engine.time_scale == 1.0, "Scene teardown cannot leak time scaling")
	check(AudioServer.playback_speed_scale == Engine.time_scale, "Scene teardown cannot leak slowed audio")
	print("PLAYER_ANTICIPATION failures=", failures)
	quit(1 if failures else 0)

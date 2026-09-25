extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var player: PlayerCharacter
var power: PlayerThunderstorm
var weather: Node
var world: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func input(pressed := false, fresh := false) -> PlayerInputSnapshot:
	var snapshot := PlayerInputSnapshot.new()
	snapshot.secondary_power_pressed = pressed
	snapshot.secondary_power_just_pressed = fresh
	return snapshot

func press() -> void:
	power.tick(0.01, input())
	power.tick(0.01, input(true, true))

func reset_cast() -> void:
	power.cancel()
	weather.set_weather(&"clear")
	weather.thunderstorm_cooldown_remaining = 0.0
	player.is_dead = false
	player.is_knocked_out = false
	player.animation_controller.is_hit_reacting = false

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	weather = root.get_node("Weather")
	weather.set_physics_process(false)
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	ground.add_child(collider)
	world.add_child(ground)
	ground.position.y = -0.5
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.position.y = 1.0
	player.set_physics_process(false)
	player.set_process_input(false)
	power = player.thunderstorm
	var powers := player.get_node("PlayerPowerController")
	var hud := player.get_node("GameplayHUD")
	await physics_frame
	for i in 8:
		player.velocity.y = -2
		player.move_and_slide()
	powers.select_active_power(&"electricity")
	for tier in [-1, 0, 1]:
		powers.progression.apply_save_data({"upgrades": {"electricity": tier}})
		press()
		check(not power.casting and not weather.is_thunderstorm(), "Only tier 2 can summon")
	powers.progression.apply_save_data({"upgrades": {"electricity": 2, "flight": 0}})
	powers.select_active_power(&"fire")
	press()
	check(not power.casting, "Electricity must be selected")
	powers.select_active_power(&"electricity")
	power.tick(0.01, input())
	power.tick(0.01, input(true))
	check(not power.casting, "Held Q without a fresh press cannot start casting")
	press()
	check(power.casting and not weather.is_thunderstorm(), "Fresh Q starts a windup without aiming")
	check(player.character_animation_player.current_animation == "Thunderstorm/Spell_Simple_Enter", "Enter animation plays")
	check(not player.anticipation.eligible(), "Counter cannot take ownership while summoning")
	power.tick(0.54, input(true))
	check(player.character_animation_player.current_animation == "Thunderstorm/Spell_Simple_Idle", "Short spell hold follows entry")
	power.tick(0.35, input(true))
	check(player.character_animation_player.current_animation == "Thunderstorm/Spell_Simple_Shoot", "Shoot gesture follows hold")
	check(not weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining == 0, "No storm or cooldown before release")
	power.tick(0.25, input(true))
	check(weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining == 300, "Release begins storm and five-minute cooldown")
	power.tick(0.3, input(true))
	check(player.character_animation_player.current_animation == "Thunderstorm/Spell_Simple_Exit", "Exit animation completes sequence")
	power.tick(0.5, input(true))
	check(not power.casting and not power._arc.visible, "Recovery releases animation and removes hand effect")
	check(player.laser_eyes.heat == 0, "Cosmetic summon consumes no Heat")
	hud.refresh_key_hints()
	check(hud.hint_labels["secondary_power"].text.contains("already active"), "HUD explains existing storm")
	weather.set_weather(&"clear")
	hud.refresh_key_hints()
	check(hud.hint_labels["secondary_power"].text.contains("5:00"), "HUD shows cooldown after clearing")
	press()
	check(not power.casting, "Clearing weather does not bypass cooldown")
	weather.advance_weather(299)
	press()
	check(not power.casting, "Cooldown still blocks at one second")
	weather.advance_weather(1)
	power.tick(0.01, input(true))
	check(not power.casting, "Holding Q never automatically triggers at cooldown expiry")
	press()
	check(power.casting, "Fresh press works once cooldown expires")
	# Damage before release cancels the cast, but still damages the hero normally.
	var hp := player.get_current_health()
	var damage = DAMAGE.new(1, player.global_position, Vector3.FORWARD, &"none", null)
	damage.damage_type = &"bullet"
	player.apply_damage(damage)
	check(not power.casting and player.get_current_health() == hp - 1, "Gunfire interrupts cast without invulnerability")
	check(not weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining == 0, "Interrupted windup costs no cooldown")
	reset_cast()
	press()
	power.tick(1.2, input())
	player.apply_damage(damage)
	check(not power.casting and weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining == 300, "Interrupting recovery does not undo a released storm")
	reset_cast()
	weather.set_weather(&"thunderstorm")
	press()
	check(not power.casting and weather.thunderstorm_cooldown_remaining == 0, "Manual storms block summoning without charging cooldown")
	reset_cast()
	press()
	weather.set_weather(&"thunderstorm")
	power.tick(1.5, input())
	check(not power.casting and weather.thunderstorm_cooldown_remaining == 0, "External weather change during windup does not consume cooldown")
	reset_cast()
	press()
	powers.select_active_power(&"fire")
	check(not power.casting and weather.thunderstorm_cooldown_remaining == 0, "Switching power cancels windup")
	powers.select_active_power(&"electricity")
	press()
	player.input_controller.reset()
	check(not power.casting, "Menu/focus input reset cancels casting")
	power.tick(0.1, input(true, true))
	check(not power.casting, "Reset requires release before recasting")
	reset_cast()
	player.laser_eyes.heat = 50
	player.laser_eyes._cooldown = 0
	press()
	power.tick(0.2, input())
	check(player.laser_eyes.heat < 50, "Existing Heat continues cooling during the summon")
	player.laser_eyes.heat = 0
	player.is_dead = true
	power.tick(0.1, input())
	check(not power.casting and not weather.is_thunderstorm(), "Death before release cannot leave a pending summon")
	reset_cast()
	press()
	powers.progression.apply_save_data({"upgrades": {"electricity": 1}})
	check(not power.casting, "Loading lower unlock cancels casting")
	powers.progression.apply_save_data({"upgrades": {"electricity": 2, "flight": 0}})
	# Same input path used in game, including in flight and with an indoor tag.
	world.add_to_group(&"weather_indoors")
	player.state_machine.transition_to(&"FlyingState")
	player.position.y = 25.0
	player.velocity = Vector3(5, 4, -3)
	player._profiled_physics_process(0.01)
	await process_frame
	player.set_physics_process(true)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(power.casting and player.is_flying and player.velocity == Vector3.ZERO, "Actual input route casts in flight, hovering, with no indoor restriction")
	var altitude := player.position.y
	var attack := InputEventAction.new()
	attack.action = "attack"
	attack.pressed = true
	player._profiled_input(attack)
	check(not player.combat_controller.is_action_locked() and not player.is_ground_slamming, "Attack cannot steal animation during cast")
	player._profiled_physics_process(1.2)
	check(weather.is_thunderstorm() and is_equal_approx(player.position.y, altitude), "Storm releases while hovering")
	player._profiled_physics_process(1.0)
	check(not power.casting and player.is_flying, "Flight resumes after casting")
	var scene2 := Node3D.new()
	root.add_child(scene2)
	player.reparent(scene2)
	current_scene = scene2
	check(weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining == 300, "Weather and cooldown survive a scene transfer")
	paused = true
	weather.set_physics_process(true)
	await create_timer(0.05, true).timeout
	check(weather.thunderstorm_cooldown_remaining == 300, "Pause preserves cooldown")
	paused = false
	weather.set_physics_process(false)
	weather.advance_weather(1000)
	check(weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining == 0, "Storm persists indefinitely beyond cooldown")
	weather.set_weather(&"clear")
	check(not weather.is_thunderstorm(), "Existing weather clear stops summoned storm")
	scene2.free()
	world.free()
	await process_frame
	print("THUNDERSTORM_POWER_TESTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

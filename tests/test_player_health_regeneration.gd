extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var health_updates := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var receiver := PlayerDamageReceiver.new()
	receiver.setup(100.0, null, null, null)
	receiver.health_changed.connect(func(_current, _maximum): health_updates += 1)
	receiver.apply_damage(DAMAGE.new(20.0), false, 0.0, false)
	receiver.update_regeneration(10.0)
	check(receiver.get_current_health() == 80.0, "Locked Preservation cannot regenerate")
	receiver.regeneration_enabled = true
	receiver.apply_damage(DAMAGE.new(10.0), false, 0.0, false)
	receiver.update_regeneration(4.5)
	check(receiver.get_current_health() == 70.0, "No healing before five seconds")
	receiver.update_regeneration(1.0)
	check(is_equal_approx(receiver.get_current_health(), 70.5), "Boundary tick heals only the half-second after the delay")
	receiver.update_regeneration(2.0)
	check(is_equal_approx(receiver.get_current_health(), 72.5), "Regeneration is exactly one HP per second")
	receiver.apply_damage(DAMAGE.new(1.0), false, 0.0, false)
	receiver.update_regeneration(5.0)
	check(is_equal_approx(receiver.get_current_health(), 71.5), "A new hit restarts the full delay")
	receiver.update_regeneration(1.0)
	check(is_equal_approx(receiver.get_current_health(), 72.5), "Healing resumes after the new delay")
	receiver.apply_damage(DAMAGE.new(0.0), false, 0.0, false)
	receiver.update_regeneration(1.0)
	check(is_equal_approx(receiver.get_current_health(), 73.5), "Rejected zero damage does not interrupt healing")
	var before := health_updates
	receiver.update_regeneration(500.0)
	check(receiver.get_current_health() == 100.0 and health_updates == before + 1, "Healing clamps at max and notifies HUD")
	receiver.update_regeneration(1.0)
	check(health_updates == before + 1, "Full health does not spam HUD signals")
	receiver.apply_damage(DAMAGE.new(100.0), false, 0.0, false)
	receiver.update_regeneration(60.0)
	check(receiver.get_current_health() == 0.0, "Regeneration cannot resurrect a dead player")
	receiver.free()

	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	world.add_child(player)
	player.set_physics_process(false)
	var powers := player.get_node("PlayerPowerController")
	var health := player.damage_receiver
	check(not health.regeneration_enabled, "New player starts with regen locked")
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"mind": 0}})
	check(health.regeneration_enabled, "Existing Preservation save ID unlocks regeneration")
	player.stats.resilience = 25
	check(health.regeneration_delay == 5.0 and health.regeneration_rate == 1.0, "Resilience does not scale regeneration")
	health.apply_damage(DAMAGE.new(20.0), false, 0.0, false)
	health.regeneration_cooldown = 0.0
	var hp := health.get_current_health()
	for tick in 8: await physics_frame
	check(health.get_current_health() > hp, "Live player physics advances regeneration")
	paused = true
	hp = health.get_current_health()
	var cooldown := health.regeneration_cooldown
	for tick in 8: await physics_frame
	check(health.get_current_health() == hp and health.regeneration_cooldown == cooldown, "Pause freezes healing and cooldown")
	paused = false
	player.is_dodging = true
	check(not health.apply_damage(DAMAGE.new(10.0), false, 0.0, false) and health.regeneration_cooldown == 0.0, "Dodged hits do not restart cooldown")
	player.is_dodging = false
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {}})
	check(not health.regeneration_enabled, "Loading a locked save disables regeneration")
	world.free()
	print("PLAYER_HEALTH_REGENERATION failures=", failures)
	quit(1 if failures else 0)

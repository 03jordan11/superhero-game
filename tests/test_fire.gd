extends SceneTree
const BALL = preload("res://effects/fireball.gd")
class Target extends StaticBody3D:
	var damage := 0.0
	var kind: StringName
	func apply_damage(info) -> bool:
		damage += info.amount
		kind = info.damage_type
		return true

var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func input(held := false, tap := false, aim := true) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.aim_power_pressed = aim
	value.activate_power_pressed = held
	value.activate_power_just_pressed = tap
	return value

func target(world: Node3D, position: Vector3) -> Target:
	var body := Target.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 0.1)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.position = position
	return body

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	var powers := player.get_node("PlayerPowerController")
	var fire: PlayerFire = player.get_node("PlayerFire")
	var shared := player.laser_eyes
	powers.select_active_power(&"fire")
	shared.update_power(0.1, input())
	shared.update_power(0.1, input(true, true))
	check(fire.shots_fired == 0 and not shared.aiming, "Locked Fire cannot aim or fire")
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"fire": 0}})
	check(player.abilities.is_unlocked(PlayerAbilities.FIRE) and not player.abilities.is_unlocked(PlayerAbilities.LASER_EYES), "Fire core unlocks independently of Laser Eyes")
	check(powers.progression.is_implemented("fire", 0) and powers.progression.is_implemented("fire", 1) and powers.progression.is_implemented("fire", 2) and not powers.progression.is_implemented("fire", 3), "Fire core and the first two upgrades are implemented")
	shared.update_power(0.1, input())
	check(shared.aiming and player.get_node("GameplayHUD/LaserReticle").visible and player.get_node("GameplayHUD/Heat").visible, "Fire has zoom, reticle, and shared heat HUD")
	shared.update_power(0.1, input(true, true, false))
	check(fire.shots_fired == 0, "Unaimed taps cannot fire")
	shared.update_power(0.1, input(true, false))
	check(fire.shots_fired == 0, "Aiming after holding attack does not count as a tap")
	shared.update_power(0.1, input())
	shared.update_power(0.016, input(true, true))
	check(fire.shots_fired == 1 and shared.heat == 20 and not shared.firing, "One tap launches a fireball and adds 20 Heat without lasers")
	for i in 10: shared.update_power(0.05, input(true, false))
	check(fire.shots_fired == 1, "Holding attack never repeats fire")
	shared.update_power(0.016, input())
	shared.update_power(0.016, input(true, true))
	check(fire.shots_fired == 2, "A fresh tap launches another fireball")
	shared.update_power(0.016, input())
	shared.update_power(0.016, input(true, true))
	check(fire.shots_fired == 2, "Shot interval limits rapid spam")
	var heat_before := shared.heat
	powers.select_active_power(&"ice")
	check(shared.heat == heat_before, "Switching power preserves Heat")
	shared.update_power(0.1, input())
	shared.update_power(0.1, input(true, true))
	check(fire.shots_fired == 2, "Other equipped powers cannot launch fireballs")
	powers.select_active_power(&"fire")
	shared.update_power(0.4, input())
	var wheel := player.get_node("PowerSelector/Wheel")
	wheel.open()
	wheel.close(true)
	shared.update_power(0.1, input(true, true))
	check(fire.shots_fired == 2, "Selector cannot leak an attack into Fire")
	shared.update_power(0.1, input())
	shared.heat = 90
	var health := player.get_current_health()
	shared.update_power(0.1, input(true, true))
	check(shared.overheated and player.is_knocked_out and shared.heat == 100, "Fire triggers shared overheat and knockdown")
	check(player.get_current_health() == health - floorf(player.get_max_health() * 0.3), "Overheat uses the exact 30 percent max-health penalty")
	shared.update_power(0.4, input())
	shared.update_power(0.1, input(true, true))
	check(fire.shots_fired == 3, "Overheat prevents additional fireballs")
	shared.update_power(5.0, input())
	check(shared.heat == 0 and not shared.overheated, "Passive cooling clears the shared lockout")
	# Remove previously launched balls before isolated collision checks.
	for node in get_nodes_in_group(&"fireball_projectiles"): node.free()
	var hit_target := target(world, Vector3(20, 2, -5))
	var nearby := target(world, Vector3(22, 2, -5))
	var far := target(world, Vector3(28, 2, -5))
	await physics_frame
	var ball := BALL.new()
	ball.source = player
	world.add_child(ball)
	ball.global_position = Vector3(20, 2, 0)
	ball.set_physics_process(false)
	ball.advance_to(Vector3(20, 2, -20))
	check(ball._spent and ball.global_position.z > -5.1, "Swept motion hits a thin wall even over a long frame")
	check(hit_target.damage == 40 and nearby.damage == 40 and far.damage == 0, "Impact damages each nearby target once within its radius")
	check(hit_target.kind == &"fire", "Fireball damage is tagged Fire")
	ball.advance_to(Vector3(20, 2, -30))
	check(hit_target.damage == 40, "Spent projectile cannot explode twice")
	var health_before := player.get_current_health()
	get_first_node_in_group(&"explosion_controller").explode_fireball(player.global_position, 40, 3, player)
	check(player.get_current_health() == health_before, "Ordinary fireball blasts exclude their owner")
	var expired := BALL.new()
	expired.lifetime = 0.1
	expired.velocity = Vector3.ZERO
	world.add_child(expired)
	expired.global_position = Vector3(100, 100, 100)
	expired._physics_process(0.2)
	check(expired.is_queued_for_deletion() and not expired._spent, "Missed projectiles expire without an explosion")
	await process_frame
	world.free()
	print("FIRE_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

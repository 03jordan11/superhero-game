extends SceneTree
const BALL = preload("res://effects/fireball.gd")
class Target extends StaticBody3D:
	var fire_damage := 0.0
	func apply_damage(info) -> bool:
		if info.damage_type == &"fire": fire_damage += info.amount
		return true
class TestCrowd extends Node3D:
	var _active: Node3D
var failures := 0
var world: Node3D
var player: PlayerCharacter
var fire: PlayerFire
var shared: PlayerLaserEyes
var powers: Node
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func input(held := false, tap := false, released := false, breath := false, aim := true) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.aim_power_pressed = aim
	value.activate_power_pressed = held
	value.activate_power_just_pressed = tap
	value.activate_power_just_released = released
	value.secondary_power_pressed = breath
	return value
func reset_power(tier := 2) -> void:
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"fire": tier, "laser_eyes": 0, "flight": 0}})
	powers.select_active_power(&"fire")
	shared.heat = 0.0
	shared.overheated = false
	fire._cooldown = 0.0
	shared.update_power(0.1, input())
func target(position: Vector3, size := Vector3(0.5, 1, 0.5)) -> Target:
	var body := Target.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.position = position
	return body
func clear_balls() -> void:
	for ball in get_nodes_in_group(&"fireball_projectiles"): ball.free()
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.position.y = 1.0
	player.set_physics_process(false)
	player.set_process_input(false)
	powers = player.get_node("PlayerPowerController")
	fire = player.get_node("PlayerFire")
	shared = player.laser_eyes
	reset_power(1)
	check(player.abilities.is_unlocked(PlayerAbilities.CHARGED_FIREBALL) and not player.abilities.is_unlocked(PlayerAbilities.DRAGON_BREATH), "Tier one unlocks charge only")
	shared.update_power(0.5, input(false, false, false, true))
	check(not fire.breathing and shared.heat == 0, "Dragon Breath remains gated before tier two")
	shared.update_power(0.75, input(true, true))
	check(fire.charging and is_equal_approx(fire.charge_ratio(), 0.5) and fire.shots_fired == 0, "Half charge holds the ball instead of firing")
	shared.update_power(0.75, input(true))
	check(is_equal_approx(fire.charge_ratio(), 1.0) and shared.heat == 30, "Full charge takes 1.5 seconds and generates 30 Heat")
	check(player.get_node("GameplayHUD/FireCharge").visible and player.get_node("GameplayHUD/FireCharge/Amount").text.contains("READY"), "HUD shows a full-charge release prompt")
	shared.update_power(0.5, input(true))
	check(shared.heat == 40 and fire.charge_ratio() == 1.0 and fire.shots_fired == 0, "Holding at max continues heating without auto-launch")
	shared.update_power(0.016, input(false, false, true))
	check(fire.shots_fired == 1 and shared.heat == 60 and not fire.charging, "Release launches one charged shot with its shot Heat cost")
	var ball = get_nodes_in_group(&"fireball_projectiles")[0]
	check(ball.damage == 80 and ball.blast_radius == 6 and ball.edge_damage == 40 and ball.visual_scale == 2, "Full charge doubles center damage and blast radius")
	check(not player.get_node("GameplayHUD/FireCharge").visible, "Charge HUD closes on release")
	clear_balls()
	reset_power()
	shared.update_power(0.01, input(true, true))
	shared.update_power(0.01, input(false, false, true))
	ball = get_nodes_in_group(&"fireball_projectiles")[0]
	check(ball.damage < 41 and ball.blast_radius < 3.1, "Quick tap after upgrade remains a normal-strength fireball")
	clear_balls()
	for interruption in ["aim", "switch", "reset", "locked", "selector"]:
		reset_power()
		shared.update_power(0.5, input(true, true))
		var shots := fire.shots_fired
		match interruption:
			"aim": shared.update_power(0.1, input(true, false, false, false, false))
			"switch": powers.select_active_power(&"ice")
			"reset": player.input_controller.reset()
			"locked": powers.progression.apply_save_data({"upgrades": {"fire": 0}})
			"selector":
				player.get_node("PowerSelector/Wheel").open()
				player.get_node("PowerSelector/Wheel").close(true)
		shared.update_power(0.1, input(false, false, true))
		check(not fire.charging and fire.shots_fired == shots, "Cancel without stray projectile on " + interruption)
	reset_power()
	shared.update_power(0.5, input(true, true))
	var before := fire.shots_fired
	shared.update_power(0.2, input(true, false, false, true))
	check(fire.breathing and not fire.charging and fire.shots_fired == before, "Breath cancels a charge when both buttons are held")
	shared.update_power(0.1, input(true))
	check(not fire.breathing and not fire.charging, "Ending breath cannot restart a held fireball without a fresh press")
	# Compare elapsed-time heat at different frame rates.
	for step in [0.1, 0.05]:
		reset_power()
		for i in roundi(1.5 / step): shared.update_power(step, input(true, i == 0))
		check(is_equal_approx(shared.heat, 30) and is_equal_approx(fire.charge_ratio(), 1), "Charge is frame-rate independent")
	reset_power()
	player.camera.top_level = true
	player.camera.global_position = Vector3(0, 2, 4)
	player.camera.look_at(Vector3(0, 1.6, -8))
	var victim := target(Vector3(0, 1.6, -8), Vector3(2, 2, 0.2))
	await physics_frame
	shared.update_power(1.0, input(false, false, false, true))
	check(fire.breathing and is_equal_approx(victim.fire_damage, 20) and shared.heat == 20, "Aimed Q deals 20 DPS and adds 20 Heat/sec")
	shared.update_power(0.1, input())
	check(not fire.breathing and not fire._breath.visible and victim.fire_damage == 20, "Releasing Q stops visuals and damage")
	shared.update_power(0.1, input(false, false, false, true, false))
	check(not fire.breathing and victim.fire_damage == 20, "Q requires aim")
	var wall := target(Vector3(0, 1.6, -3), Vector3(4, 4, 0.2))
	await physics_frame
	shared.update_power(0.5, input(false, false, false, true))
	check(victim.fire_damage == 20 and is_equal_approx(wall.fire_damage, 10), "Breath damages nearby objects but stops behind cover")
	wall.free()
	# Clamp final breath damage to the tiny time left before overheat; fall out of flight.
	shared.update_power(0.1, input())
	shared.heat = 99
	player.state_machine.transition_to(&"FlyingState")
	var health := player.get_current_health()
	shared.update_power(0.5, input(false, false, false, true))
	check(is_equal_approx(victim.fire_damage, 21), "Final breath interval is limited to remaining Heat capacity")
	check(shared.overheated and player.is_knocked_out and not player.is_flying and not fire.breathing, "Breath overheat cancels flight and stops the stream")
	check(player.get_current_health() == health - floorf(player.get_max_health() * 0.3), "Breath preserves exact overheat health cost")
	shared.update_power(5.0, input())
	check(shared.heat == 0 and not shared.overheated, "Both upgrades use passive shared cooling")
	victim.free()
	# Isolated physics blast: full center, decreasing edge, larger reach, no double hit.
	var origin := Vector3(30, 2, 0)
	var center := target(origin)
	var middle := target(origin + Vector3(3, 0, 0))
	var edge := target(origin + Vector3(5.8, 0, 0))
	var outside := target(origin + Vector3(7, 0, 0))
	await physics_frame
	var explosions := get_first_node_in_group(&"explosion_controller") as ExplosionController
	explosions.explode_fireball(origin, 80, 6, player, 40)
	check(is_equal_approx(center.fire_damage, 80), "Charged blast deals exactly double damage at center")
	check(center.fire_damage > middle.fire_damage and middle.fire_damage > edge.fire_damage and edge.fire_damage >= 40, "Charged blast falls off smoothly toward edge")
	check(edge.fire_damage > 0 and outside.fire_damage == 0, "Charged blast reaches beyond the old radius but respects its new radius")
	# A cone can hit multiple targets once, excludes targets outside it, and
	# includes capsule civilians (which do not have physics bodies).
	var breath_origin := Vector3(60, 2, 0)
	var cone_a := target(breath_origin + Vector3(-1, 0, -6))
	var cone_b := target(breath_origin + Vector3(1, 0, -6))
	var cone_out := target(breath_origin + Vector3(4, 0, -6))
	var extra_shape := cone_a.get_child(0).duplicate()
	cone_a.add_child(extra_shape)
	var crowd := TestCrowd.new()
	crowd._active = Node3D.new()
	crowd.add_child(crowd._active)
	var lod := preload("res://scripts/npc-scripts/civilian_capsule_lod.gd").new()
	crowd.add_child(lod)
	world.add_child(crowd)
	var civilian := lod.create_capsule(-1)
	crowd._active.add_child(civilian)
	civilian.global_position = breath_origin + Vector3(0, -0.9, -8)
	await physics_frame
	fire._breath.set_stream(breath_origin, breath_origin + Vector3.FORWARD * 12, 0.25)
	fire._breath.deal_damage(20, player)
	check(cone_a.fire_damage == 20 and cone_b.fire_damage == 20 and cone_out.fire_damage == 0, "Breath cone hits multiple targets once and rejects outside targets")
	check(civilian.pending_damage.size() == 1 and civilian.pending_damage[0].amount == 20, "Breath damages lightweight civilians exactly once")
	civilian.pending_damage.clear()
	explosions.explode_fireball(civilian.global_position + Vector3(3, 0.9, 0), 80, 6, player, 40)
	check(civilian.pending_damage.size() == 1 and is_equal_approx(civilian.pending_damage[0].amount, 65), "Distant civilian charged-blast falloff matches body targets")
	var side_damage_before := Vector2(cone_a.fire_damage, cone_b.fire_damage)
	var cover := target(breath_origin + Vector3(0, 0, -3), Vector3(10, 4, 0.2))
	civilian.pending_damage.clear()
	await physics_frame
	fire._breath.deal_damage(20, player)
	check(Vector2(cone_a.fire_damage, cone_b.fire_damage).is_equal_approx(side_damage_before) and civilian.pending_damage.is_empty(), "Cover occludes side targets and distant civilians, not just the central ray")
	cover.free()
	crowd.free()
	fire.cancel()
	# A held charge reaching full Heat explodes without spawning the stored fireball.
	player.state_machine.transition_to(&"GroundedState")
	reset_power()
	before = fire.shots_fired
	shared.heat = 95
	shared.update_power(1.0, input(true, true))
	check(shared.overheated and not fire.charging and fire.shots_fired == before, "Overheating during charge discards the held ball")
	await process_frame
	world.free()
	print("FIRE_UPGRADES_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

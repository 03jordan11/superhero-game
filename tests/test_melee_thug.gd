extends SceneTree

const MELEE = preload("res://scenes/npcs/melee_thug.tscn")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

class Target extends CharacterBody3D:
	var hits: int = 0
	var damage_taken: float = 0.0
	func apply_damage(info) -> bool:
		hits += 1
		damage_taken += info.amount
		return true

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func spawn_enemy(world: Node3D, target: Node3D, at: Vector3) -> MeleeHostile:
	var enemy := MELEE.instantiate() as MeleeHostile
	enemy.position = at
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.receive_alert(target)
	enemy.recovery_remaining = 0.0
	enemy.combat_action_delay_remaining = 0.0
	return enemy

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var target := Target.new()
	var target_shape := CollisionShape3D.new()
	target_shape.shape = CapsuleShape3D.new()
	target_shape.position.y = 1.0
	target.add_child(target_shape)
	world.add_child(target)
	var enemies: Array[MeleeHostile] = []
	for index in 6:
		var angle := TAU * float(index) / 6.0
		enemies.append(spawn_enemy(world, target, Vector3(cos(angle), 0, sin(angle)) * 8.0))
	await physics_frame
	await physics_frame
	for enemy in enemies:
		enemy._handle_combat(0.016)
	var coordinator: Node = target.get_node("MeleeAttackCoordinator")
	check(coordinator.active_count() == 2 and enemies[0].has_attack_slot and enemies[1].has_attack_slot, "Only two melee thugs reserve approach/attack slots")
	check(enemies[2].melee_state == MeleeHostile.MeleeState.SURROUND and not enemies[2].has_attack_slot, "Additional thugs surround")
	check(not enemies[2]._surround_destination().is_equal_approx(enemies[3]._surround_destination()), "Surround positions are distinct")
	check(is_equal_approx(enemies[2]._surround_destination().distance_to(target.position), 9.0), "Waiting thugs surround at the wider nine-meter radius")
	var waypoint := enemies[0]._surround_waypoint(Vector3(-8, 0, 0))
	check(absf(waypoint.z) > 1.0, "Surround movement goes around the target instead of directly through it")
	enemies[0].apply_damage(DAMAGE.new(1, target.global_position, Vector3.ZERO, &"chest", target))
	check(coordinator.active_count() == 1, "Damage interruption releases a reserved slot")
	enemies[2]._handle_combat(0.016)
	check(enemies[2].has_attack_slot and coordinator.active_count() == 2, "Next waiting thug receives the freed slot")
	enemies[1].free()
	enemies.remove_at(1)
	enemies[2]._handle_combat(0.016)
	check(enemies[2].has_attack_slot and coordinator.active_count() == 2, "Despawn releases slot for next waiter")
	target.position.y = 10.0
	for enemy in enemies:
		enemy._handle_combat(0.016)
	check(coordinator.active_count() == 0, "Unreachable airborne target releases approach slots")
	target.position = Vector3.ZERO
	for enemy in enemies:
		enemy.free()
	enemies.clear()
	# Exercise the default six-punch combo and shorter Inspector overrides.
	for length in [6, 2, 3]:
		var enemy := spawn_enemy(world, target, Vector3(0, 0, 1.8))
		check(enemy.min_combo_punches == 6 and enemy.max_combo_punches == 6, "Default turn is exactly six punches")
		enemy.min_combo_punches = length
		enemy.max_combo_punches = length
		var animation: AnimationPlayer = enemy.animation_controller.animation_player
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		await physics_frame
		enemy._handle_combat(0.01)
		check(enemy.melee_state == MeleeHostile.MeleeState.ATTACK, "Nearby slot holder starts a combo")
		var hits_before := target.hits
		for tick in 1600:
			enemy._handle_combat(0.01)
			animation.advance(0.01)
			if enemy.melee_state != MeleeHostile.MeleeState.ATTACK:
				break
		check(target.hits - hits_before == length, "%d-punch combo deals exactly one hit per swing" % length)
		check(not enemy.has_attack_slot and coordinator.active_count() == 0, "Combo yields slot for another attacker")
		check(enemy.recovery_remaining > 0.0, "Completed attacker has recovery before rejoining queue")
		enemy.free()
	# Commit a swing, then dodge behind it while staying within range.
	var attacker := spawn_enemy(world, target, Vector3(0, 0, 1.8))
	await physics_frame
	attacker._handle_combat(0.01)
	var hits_before := target.hits
	target.position.z = 3.6
	await physics_frame
	attacker._handle_combat(0.21)
	check(target.hits == hits_before, "A sidestep behind committed facing evades the punch")
	attacker._reset_combat_actions()
	target.position = Vector3.ZERO
	attacker.recovery_remaining = 0.0
	await physics_frame
	attacker._handle_combat(0.01)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(5, 3, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 1, 0.9)
	world.add_child(wall)
	await physics_frame
	attacker._handle_combat(0.21)
	check(target.hits == hits_before, "A wall blocks punch damage at impact time")
	wall.free()
	attacker._reset_combat_actions()
	attacker.position.z = 8.0
	attacker.recovery_remaining = 0.0
	await physics_frame
	attacker._handle_combat(0.01)
	attacker.approach_remaining = 0.0
	attacker._handle_combat(0.01)
	check(not attacker.has_attack_slot, "Stuck approach times out and frees slot")
	attacker.free()
	# Real physics: a crowd approaches and punches while respecting the cap.
	hits_before = target.hits
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var enemy := spawn_enemy(world, target, Vector3(cos(angle), 0, sin(angle)) * 7.0)
		enemy.set_physics_process(true)
		enemies.append(enemy)
	var cap_respected := true
	for tick in 360:
		await physics_frame
		if coordinator.active_count() > 2:
			cap_respected = false
	check(cap_respected, "Eight live enemies never exceed two attack slots")
	check(target.hits > hits_before, "Live approach movement reaches and damages the target")
	for enemy in enemies:
		enemy._die()
	check(coordinator.active_count() == 0, "Deaths release every slot")
	world.free()
	print("Melee thug: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

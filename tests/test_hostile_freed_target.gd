extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func spawn(world: Node3D, kind: String, position: Vector3) -> HostileBase:
	var enemy := load("res://scenes/npcs/%s_thug.tscn" % kind).instantiate() as HostileBase
	enemy.position = position
	world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	for kind in ["pistol", "rifle", "melee", "super"]:
		for search in [false, true]:
			var enemy := spawn(world, kind, Vector3.ZERO)
			var target := Node3D.new()
			world.add_child(target)
			target.position = Vector3(0, 0, 8)
			enemy.receive_alert(target)
			if enemy is MeleeHostile:
				enemy.has_attack_slot = enemy._get_coordinator().request_slot(enemy)
			if search:
				enemy.current_state = HostileBase.State.SEARCH
			var delayed_damage = DAMAGE.new(1, Vector3.ZERO, Vector3.ZERO, &"chest", target)
			target.free()
			check(not enemy._can_target(target) and not enemy._can_see_target(target), "Freed targets fail validation safely for " + kind)
			check(enemy.apply_damage(delayed_damage), "Damage from a deleted source still applies safely")
			if search:
				enemy._handle_search(0.016)
			else:
				enemy._handle_combat(0.016)
			check(enemy.combat_target == null and enemy.current_state == HostileBase.State.GUARD, "Invalid combat/search target clears and returns to guard: " + kind)
			check(not enemy.has_last_known_target_position and not enemy.has_search_destination, "Target loss clears stale search destinations")
			if enemy is MeleeHostile:
				check(not enemy.has_attack_slot, "Target loss releases melee/super turn")
			var queued := Node3D.new()
			world.add_child(queued)
			queued.queue_free()
			check(not enemy._can_target(queued), "Queued deletion is rejected before an object is freed")
			enemy.free()
	# Reproduce the actual vehicle destruction -> radius damage -> source removal path.
	var explosion := ExplosionController.new()
	explosion.effect_scene = null
	world.add_child(explosion)
	var car := load("res://scenes/vehicles/normal_car_2.tscn").instantiate() as Vehicle
	car.freeze = true
	world.add_child(car)
	var enemies: Array[HostileBase] = []
	var kinds := ["pistol", "rifle", "melee", "super"]
	for index in kinds.size():
		var angle := TAU * float(index) / kinds.size()
		enemies.append(spawn(world, kinds[index], Vector3(cos(angle), 0, sin(angle)) * 3.0))
	await physics_frame
	await physics_frame
	car.arm_thrown_impact(25.0, null)
	car.apply_damage(DAMAGE.new(car.get_current_health(), car.position, Vector3.ZERO, &"none", null, 25.0))
	for enemy in enemies:
		check(not enemy.is_dead and enemy.get_current_health() < enemy.max_health, "Vehicle explosion damages surviving " + str(enemy.enemy_type))
		check(enemy.combat_target == car, "Explosion reproduces temporary vehicle target")
	await process_frame
	await process_frame
	check(not is_instance_valid(car), "Exploded car is removed")
	for enemy in enemies:
		enemy._handle_combat(0.016)
		check(enemy.combat_target == null and enemy.current_state == HostileBase.State.GUARD, "Survivor safely drops deleted car target")
	world.free()
	print("Hostile freed target: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

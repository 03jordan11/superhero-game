extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

class Target extends CharacterBody3D:
	var hits := 0
	var damage_taken := 0.0
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

func spawn(world: Node3D, target: Node3D, kind: String, index: int) -> MeleeHostile:
	var enemy := load("res://scenes/npcs/%s_thug.tscn" % kind).instantiate() as MeleeHostile
	enemy.position = Vector3(10 + index * 3, 0, 8)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.receive_alert(target)
	enemy.combat_action_delay_remaining = 0.0
	enemy.recovery_remaining = 0.0
	return enemy

func reserve(enemy: MeleeHostile) -> bool:
	enemy.has_attack_slot = enemy._get_coordinator().request_slot(enemy)
	return enemy.has_attack_slot

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var target := Target.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	target.add_child(shape)
	world.add_child(target)
	var other := Target.new()
	world.add_child(other)
	other.position = Vector3(-20, 0, 0)
	var a := spawn(world, target, "melee", 0)
	var b := spawn(world, target, "melee", 1)
	var c := spawn(world, target, "melee", 2)
	var heavy := spawn(world, target, "super", 3) as SuperHostile
	var later := spawn(world, target, "melee", 4)
	var second := spawn(world, target, "super", 5) as SuperHostile
	check(heavy.max_health == 500 and heavy.get_current_health() == 500 and heavy.punch_damage == 40 and heavy.experience_gain == 350, "Super stats match requested balance")
	check(heavy.faction == &"mafia" and heavy.nameplate.text == "SUPER" and heavy.nameplate.modulate == Color("ef9a42"), "Super has Mafia identity and orange label")
	check(heavy.get_node("Superhero_Male_FullBody").scale.is_equal_approx(Vector3.ONE * 1.5), "Super model is 1.5 times normal size")
	check(is_equal_approx(heavy.get_node("CollisionShape3D").shape.height, a.get_node("CollisionShape3D").shape.height * 1.5), "Super capsule matches model size")
	check(a.approach_speed == 8.5 and a.surround_speed == 3.5 and heavy.approach_speed < a.approach_speed, "Melee movement reduced and super is slower still")
	check(reserve(a) and reserve(b), "Two normal melee thugs can take the first turns")
	check(not reserve(c) and not reserve(heavy) and not reserve(later) and not reserve(second), "Supers join the same waiting queue")
	var coordinator := target.get_node("MeleeAttackCoordinator")
	a._reset_combat_actions()
	check(not reserve(heavy) and reserve(c), "An earlier normal waiter goes before the super")
	b._reset_combat_actions()
	check(not reserve(heavy) and not reserve(later), "Super waits for both slots; later enemies cannot skip it")
	c._reset_combat_actions()
	check(reserve(heavy) and coordinator.active_count() == 1, "Super begins an exclusive turn after normal turns finish")
	check(not reserve(later) and not reserve(second), "Normal melee and second super stay out during exclusive turn")
	heavy._reset_combat_actions()
	check(heavy.has_attack_slot, "Recovery does not release a super turn")
	heavy.apply_damage(DAMAGE.new(1, target.position, Vector3.ZERO, &"chest", target))
	check(heavy.has_attack_slot and coordinator.active_count() == 1, "Hit interruption preserves exclusivity")
	heavy.receive_alert(other)
	check(heavy.combat_target == target, "Other alerts cannot steal the active super's target")
	target.position = Vector3(100, 20, 0)
	heavy._handle_combat(5.0)
	check(heavy.has_attack_slot and heavy.current_state == HostileBase.State.COMBAT, "Distance, approach timeout and airborne target do not end the super turn")
	target.position = Vector3.ZERO
	heavy.position = Vector3(0, 0, 2.5)
	heavy.recovery_remaining = 0.0
	heavy.is_hit_reacting = false
	var animation: AnimationPlayer = heavy.animation_controller.animation_player
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await physics_frame
	await physics_frame
	heavy._handle_combat(0.01)
	check(heavy.melee_state == MeleeHostile.MeleeState.ATTACK and is_equal_approx(animation.get_playing_speed(), 0.5), "Super starts punches at half playback speed")
	var elapsed := 0.0
	var first_hit := -1.0
	for tick in 2400:
		elapsed += 0.01
		heavy._handle_combat(0.01)
		animation.advance(0.01)
		if target.hits > 0 and first_hit < 0.0:
			first_hit = elapsed
		if heavy.melee_state != MeleeHostile.MeleeState.ATTACK:
			break
	check(first_hit >= 0.39 and target.hits == 6 and target.damage_taken == 240, "Six slower swings deal 40 damage each with a longer windup")
	check(heavy.has_attack_slot and coordinator.active_count() == 1 and not reserve(later), "Completed combo keeps exclusive turn")
	heavy._handle_combat(heavy.combo_recovery_time + 0.01)
	check(heavy.melee_state == MeleeHostile.MeleeState.ATTACK, "Super starts another combo without retreating or yielding")
	# Real reward path: defeat pays once, then queued normal goes before super two.
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	player.position = Vector3(-50, 0, 0)
	world.add_child(player)
	player.set_physics_process(false)
	# XP can roll into a level; compare against an independent stats instance.
	var expected = player.stats.duplicate()
	expected.add_experience(350)
	heavy.apply_damage(DAMAGE.new(999, target.position, Vector3.ZERO, &"chest", target))
	heavy._die()
	check(heavy.is_dead and not heavy.has_attack_slot and coordinator.active_count() == 0, "Super death releases exclusivity")
	check(player.stats.experience == expected.experience and player.stats.level == expected.level, "Super awards exactly 350 XP once")
	check(not reserve(second) and reserve(later), "Normal waiter between supers gets its turn after first super dies")
	later._reset_combat_actions()
	check(reserve(second), "Second super takes its exclusive turn in queue order")
	second.free()
	check(coordinator.active_count() == 0, "Removing an active super cannot leak its lock")
	var replacement := spawn(world, other, "super", 6)
	check(reserve(replacement), "Another target owns an independent queue")
	other.free()
	replacement._handle_combat(0.01)
	check(not replacement.has_attack_slot, "Destroyed target clears obsolete turn safely")
	# Exercise the actual physics update paths with an active super and waiters.
	for enemy in [a, b, c, later, replacement]:
		enemy.free()
	player.free()
	var live_super := spawn(world, target, "super", 0)
	live_super.position = Vector3(0, 0, 8)
	check(reserve(live_super), "Live super acquires a clean exclusive turn")
	live_super.set_physics_process(true)
	var crowd: Array[MeleeHostile] = []
	for index in 5:
		var enemy := spawn(world, target, "super" if index == 4 else "melee", index)
		var angle := TAU * float(index) / 5.0
		enemy.position = Vector3(cos(angle), 0, sin(angle)) * 10.0
		enemy.set_physics_process(true)
		crowd.append(enemy)
	var hits_before := target.hits
	var exclusive := true
	for tick in 240:
		await physics_frame
		if coordinator.active_count() != 1 or not live_super.has_attack_slot:
			exclusive = false
		for enemy in crowd:
			if enemy.has_attack_slot or enemy.melee_state == MeleeHostile.MeleeState.ATTACK:
				exclusive = false
	check(exclusive and target.hits > hits_before, "Live super approaches and attacks while all normal melee and other supers wait")
	world.free()
	print("Super thug: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

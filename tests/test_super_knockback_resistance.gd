extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	world.add_child(player)
	player.set_physics_process(false)
	var combat := player.get_node("PlayerCombatController") as PlayerCombatController
	var heavy := preload("res://scenes/npcs/super_thug.tscn").instantiate() as SuperHostile
	heavy.position = Vector3(0, 0, -1.8)
	world.add_child(heavy)
	heavy.set_physics_process(false)
	heavy.receive_alert(player)
	heavy.has_attack_slot = heavy._get_coordinator().request_slot(heavy)
	await physics_frame
	await physics_frame
	combat.combo_punch_index = PlayerCombatController.UPPERCUT_PUNCH_INDEX
	check(combat._try_hit_target(player, 10), "Actual third-punch hit query reaches the super")
	check(heavy.get_current_health() == 460, "Third punch retains full doubled damage")
	check(heavy.knockback_velocity == Vector3.ZERO and not heavy.is_waiting_for_knockback_stun, "Super resists third-hit knockback and knockdown")
	check(heavy.animation_controller.animation_player.current_animation == "Hit_Chest", "Super plays standing hit reaction")
	check(heavy.has_attack_slot, "Resisted finisher preserves super's exclusive turn")
	var position_before := heavy.position
	heavy._process_hit_reaction(0.1)
	check(heavy.velocity == Vector3.ZERO and heavy.position == position_before, "Resisted hit introduces no displacement")
	# Area attacks may reuse one payload across several recipients.
	var slam = DAMAGE.new(20, player.position, Vector3.FORWARD, &"ground_slam", player)
	heavy.apply_damage(slam)
	check(heavy.get_current_health() == 440 and heavy.knockback_velocity == Vector3.ZERO, "Ground-slam damage remains but knockdown is resisted")
	check(slam.reaction == &"ground_slam", "Resistance does not mutate shared damage info")
	for kind in ["melee", "pistol", "rifle"]:
		var normal := load("res://scenes/npcs/%s_thug.tscn" % kind).instantiate() as HostileBase
		normal.position = Vector3(10, 0, 0)
		world.add_child(normal)
		normal.set_physics_process(false)
		normal.apply_damage(slam)
		check(not normal.knockback_resistant and normal.is_waiting_for_knockback_stun and normal.knockback_velocity.length() > 0.0, "%s retains normal knockback" % kind)
		normal.free()
	heavy.knockback_resistant = false
	heavy.apply_damage(slam)
	check(heavy.is_waiting_for_knockback_stun and heavy.knockback_velocity.length() > 0.0, "Inspector resistance toggle restores ordinary knockback")
	heavy.knockback_resistant = true
	heavy.apply_damage(DAMAGE.new(999, player.position, Vector3.FORWARD, &"knockback", player))
	check(heavy.is_dead and not heavy.has_attack_slot and heavy.animation_controller.animation_player.current_animation == "Death01", "Resistance does not block lethal damage, death animation or turn release")
	world.free()
	print("Super knockback resistance: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

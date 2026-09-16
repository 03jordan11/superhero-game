extends SceneTree
const ENCOUNTER = preload("res://scenes/encounters/pirates.tscn")
var failures := 0
var main: Node3D
var hero: PlayerCharacter

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("Pirates test timed out"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main); current_scene = main
	hero = main.get_node("Player"); hero.set_physics_process(false)
	var schedule := main.get_node("SuperCity/Sidewalks/CargoShip/HarborSchedule")
	var clock := get_first_node_in_group(&"day_night_cycle")
	clock.cycle_running = false; clock.set_time(12)
	await physics_frame; await physics_frame
	var original_pose: Transform3D = schedule.get_parent().global_transform
	var commands = main.get_node("DeveloperMenu").commands
	check(commands.COMPLETIONS.has("spawn pirates"), "Console completes pirate command")
	check(commands.execute("help spawn").contains("pirates"), "Console documents pirate command")
	var reply: String = commands.execute("spawn pirates")
	print("PIRATE_SPAWN ", reply)
	check(reply.begins_with("Spawned Pirates"), "Actual harbor spawn succeeds")
	var all := get_nodes_in_group(&"pirate_encounter")
	if all.is_empty(): main.free(); quit(1); return
	var encounter = all[0]
	encounter.cleanup_delay = 0
	check(encounter.state == BaseEncounter.EncounterState.ACTIVE, "Pirates activate")
	check(encounter.active_hostiles.size() == 7, "Seven enemies spawn")
	var counts := {}
	for enemy: HostileBase in encounter.active_hostiles:
		enemy.set_physics_process(false)
		counts[enemy.enemy_type] = counts.get(enemy.enemy_type,0) + 1
	check(counts == {&"pistol_thug":2,&"melee_thug":3,&"rifle_thug":1,&"super_thug":1}, "Exact fixed pirate roster")
	check(encounter.xp_reward == 500 and encounter.money_reward == 0, "Fixed 500 XP reward")
	check(schedule.enabled and schedule.get_parent().global_transform.is_equal_approx(original_pose), "Scheduled cargo ship is untouched")
	check(not encounter.ship.has_node("HarborSchedule") and encounter.ship.navigation_mode == 1, "Pirate ship is anchored, with no schedule")
	check(commands.execute("spawn pirates").begins_with("Encounter spawn failed"), "Duplicate ship rejected")
	check(get_nodes_in_group(&"pirate_encounter").size() == 1, "Failed duplicate leaves no second ship")
	await physics_frame
	var ship_pose: Transform3D = encounter.ship.global_transform
	for enemy: HostileBase in encounter.active_hostiles:
		var ray := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 0.5, enemy.global_position - Vector3.UP * 0.5,1,[enemy.get_rid()])
		var hit := hero.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider == encounter.ship.get_node("Collision"), "Each pirate stands on real ship collision")
		check(enemy.required_walk_surface == encounter.ship.get_node("Collision"), "Deck movement restriction applies to all pirates")
	# Leave the camera-facing side of the tapered bow: normal walking stops.
	var walker: HostileBase = encounter.active_hostiles[2]
	var saved := walker.global_position
	walker.global_position = encounter.ship.to_global(Vector3(10.1,6.4,-60))
	walker.velocity = encounter.ship.global_basis.x * 10
	walker._keep_on_walk_surface(0.1)
	check(Vector2(walker.velocity.x,walker.velocity.z).length() < 0.01, "AI refuses to walk over deck edge")
	walker.global_position = saved
	clock.set_time(19); await physics_frame; await physics_frame
	check(encounter.ship.global_transform.is_equal_approx(ship_pose), "Clock changes don't move pirate ship")
	hero.stats.level = 12
	check(encounter.active_hostiles.size() == 7 and encounter.xp_reward == 500, "Level changes never alter composition or reward")
	var indicator := hero.get_node("EncounterIndicator") as PlayerEncounterIndicator
	indicator._profiled_process(0)
	check(indicator.visible and indicator.distance_label.text.contains("7 enemies"), "Waypoint displays remaining pirates")
	if "--render" in OS.get_cmdline_user_args(): await render_ship(encounter)
	# Exercise the actual enemy controllers with the player aboard the forecastle.
	hero.global_position = encounter.ship.to_global(Vector3(0,8.2,-71))
	for enemy: HostileBase in encounter.active_hostiles:
		enemy.set_physics_process(true)
		enemy.receive_alert(hero)
	for i in 120: await physics_frame
	check(encounter.active_hostiles.size() == 7, "Pirates survive ordinary deck pursuit without walking overboard")
	for enemy: HostileBase in encounter.active_hostiles:
		check(enemy.combat_target == hero, "Pirate AI engages player aboard ship")
		enemy.set_physics_process(false)
	# Clear six, then snapshot XP so ordinary kill XP is separate from the bonus.
	for i in 6: encounter.active_hostiles[0]._die()
	check(encounter.state == BaseEncounter.EncounterState.ACTIVE, "Six defeats cannot finish objective")
	var final_enemy: HostileBase = encounter.active_hostiles[0]
	final_enemy.experience_gain = 0
	var before: int = hero.stats.experience
	final_enemy._die()
	check(encounter.state == BaseEncounter.EncounterState.COMPLETED, "Last enemy completes encounter")
	check(hero.stats.experience == before + 500, "Completion awards exactly 500 bonus XP")
	encounter.complete_encounter(); final_enemy._die()
	check(hero.stats.experience == before + 500, "Reward cannot repeat")
	indicator._profiled_process(0)
	check(not indicator.visible, "Completed waypoint disappears")
	hero.global_position = encounter.ship.to_global(Vector3(0,8,-60))
	encounter._cleanup()
	check(not encounter.is_queued_for_deletion(), "Victory cleanup keeps deck under player")
	hero.global_position = Vector3.ZERO
	encounter._cleanup(); await process_frame; await process_frame
	check(not is_instance_valid(encounter), "Ship and enemies clean up after player leaves")
	# Missing enemies fail instead of granting a win; overboard enemies count as defeats.
	clock.set_time(12); await physics_frame; await physics_frame
	encounter = ENCOUNTER.instantiate(); main.add_child(encounter); encounter.cleanup_delay = 0
	check(encounter.start_encounter(hero), "Can start another pirate encounter after cleanup")
	if encounter.state == BaseEncounter.EncounterState.ACTIVE:
		for enemy: HostileBase in encounter.active_hostiles: enemy.set_physics_process(false)
		var overboard: HostileBase = encounter.active_hostiles[0]
		overboard.global_position.y = encounter.ship.global_position.y - 2
		encounter._physics_process(0.016)
		check(overboard.is_dead and encounter.active_hostiles.size() == 6, "Overboard pirate is defeated, not stranded underwater")
		encounter.active_hostiles[0].free()
		check(encounter.state == BaseEncounter.EncounterState.FAILED, "Unexpected removal of living enemy fails objective")
	encounter.free()
	# Bad placement fails cleanly rather than producing a partial encounter.
	encounter = ENCOUNTER.instantiate(); main.add_child(encounter)
	encounter.harbor_offset = Vector3.ZERO
	check(not encounter.start_encounter(hero), "Occupied berth cannot receive a pirate ship")
	check(encounter.ship == null and encounter.active_hostiles.is_empty(), "Blocked placement leaves no partial actors")
	encounter.free()
	main.free()
	print("PIRATES_PASS failures=",failures)
	quit(1 if failures else 0)

func render_ship(encounter: Node3D) -> void:
	for enemy: HostileBase in encounter.active_hostiles: enemy.set_physics_process(false)
	var camera := Camera3D.new(); main.add_child(camera)
	camera.far = 2000; camera.fov = 65
	camera.global_position = encounter.ship.to_global(Vector3(38,35,-95))
	camera.look_at(encounter.ship.to_global(Vector3(0,6,-58)))
	camera.make_current()
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/pirates-deck.png")
	camera.global_position = encounter.ship.to_global(Vector3(120,95,-180))
	camera.look_at(encounter.ship.global_position)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/pirates-harbor.png")
	camera.free()

extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	var player := main.get_node("Player") as PlayerCharacter
	player.set_physics_process(false)
	var commands = main.get_node("DeveloperMenu").commands
	player.abilities.set_unlocked(PlayerAbilities.TROUBLE_SENSE, false)
	await physics_frame
	await physics_frame
	paused = true
	check(get_nodes_in_group(&"encounter").is_empty(), "Main scene has no automatically added encounters")
	check(commands.COMPLETIONS.has("spawn gang_activity") and commands.execute("help spawn").contains("gang_activity"), "Encounter command is documented and completes")
	for invalid in ["spawn gang_activity 2", "spawn gang_activity extra", "spawn gang_activity 0"]:
		commands.execute(invalid)
	check(get_nodes_in_group(&"encounter").is_empty(), "Invalid encounter arguments do not spawn anything")
	for level in [1, 4, 7]:
		player.stats.level = level
		var result: String = commands.execute("spawn gang_activity")
		check(result.begins_with("Spawned Gang Activity"), "Console finds a random encounter site in the actual city: " + result)
		var encounters := get_nodes_in_group(&"encounter")
		if encounters.is_empty():
			continue
		var gang := encounters[0] as GangActivityEncounter
		var tier := BaseEncounter.difficulty_for_level(level)
		check(gang.global_position.y >= gang.minimum_ground_height, "Random city spawn excludes submerged ground")
		check(gang.active_hostiles.size() == [4, 5, 7][tier] and gang.xp_reward == [100, 500, 1000][tier], "Console uses hero level for exact count/reward")
		check(paused and gang.debug_waypoint and not player.abilities.is_unlocked(PlayerAbilities.TROUBLE_SENSE), "Encounter spawn preserves pause and does not unlock a power")
		var indicator := player.get_node("EncounterIndicator") as PlayerEncounterIndicator
		indicator._profiled_process(0)
		check(indicator.visible and indicator.distance_label.text.contains(gang.display_name), "Dev waypoint points to spawned city encounter")
		var start_health := player.get_current_health()
		await process_frame
		await process_frame
		check(player.get_current_health() == start_health, "Encounter cannot fight while console is paused")
		print("[Encounter console] ", result, " at ", gang.global_position)
		gang.cleanup_delay = 0.01
		for enemy in gang.active_hostiles.duplicate():
			enemy._die()
		indicator._profiled_process(0)
		check(not indicator.visible and gang.state == BaseEncounter.EncounterState.COMPLETED, "Completed encounter clears waypoint")
		paused = false
		await create_timer(0.05).timeout
		await process_frame # queue_free is committed at the end of the timer frame.
		await process_frame
		check(not is_instance_valid(gang), "Completed encounter cleans up after its delay")
		paused = true
	paused = false
	main.free()
	print("Encounter console: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

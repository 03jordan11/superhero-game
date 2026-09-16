extends SceneTree
var failures := 0

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Rescue console test timed out"); quit(1))
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
	check(get_nodes_in_group(&"encounter").is_empty(), "No automatic encounter spawns added to main")
	check(commands.COMPLETIONS.has("spawn rescue") and commands.execute("help spawn").contains("rescue"), "Rescue command has help and completion")
	commands.execute("spawn rescue 2")
	check(get_nodes_in_group(&"encounter").is_empty(), "Invalid rescue command cannot spawn")
	var result: String = commands.execute("spawn rescue")
	check(result.begins_with("Spawned Injured Civilian"), "Console spawns rescue in actual city: " + result)
	var rescue := get_nodes_in_group(&"encounter")[0] as RescueEncounter
	check(rescue.hospital == main.get_node("Hospital/RescueDropOff"), "Rescue selects hospital already placed in main scene")
	var time := rescue.remaining_time
	await process_frame
	await process_frame
	check(rescue.remaining_time == time, "Console pause freezes rescue countdown")
	var indicator := player.get_node("EncounterIndicator") as PlayerEncounterIndicator
	indicator._profiled_process(0)
	check(indicator.visible and indicator.distance_label.text.contains("Injured Civilian"), "Dev arrow works without Trouble Sense")
	check(commands.execute("status").contains("Good Will:"), "Console status exposes tracked rewards")
	paused = false
	player.position = rescue.patient.global_position + Vector3(0, 0.1, 2)
	check(player.rescue_carrier.try_pick_up(), "City rescue can be picked up")
	indicator._profiled_process(0)
	check(indicator.distance_label.text.contains("Hospital"), "Arrow changes to actual hospital")
	var patient := rescue.patient
	player._die()
	check(not player.is_carrying() and patient.get_parent() == rescue, "Hero death releases the protected civilian")
	rescue.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(patient), "Encounter removal cleans up civilian")
	main.free()
	print("Rescue console: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

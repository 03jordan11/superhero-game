extends SceneTree

const GANG = preload("res://scenes/encounters/gang-activity/gang_activity.tscn")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var generator := GANG.instantiate() as GangActivityEncounter
	generator.random_number_generator.seed = 8712
	var saw_mid_super := false
	for tier in [BaseEncounter.Difficulty.EASY, BaseEncounter.Difficulty.MID, BaseEncounter.Difficulty.HARD]:
		for sample in 1000:
			var roster := generator.build_roster(tier)
			var rifles := roster.count(&"rifle_thug")
			var pistols := roster.count(&"pistol_thug")
			var supers := roster.count(&"super_thug")
			var melee := roster.count(&"melee_thug")
			if tier == BaseEncounter.Difficulty.EASY:
				check(roster.size() == 4 and supers == 0 and melee >= 1 and ((rifles == 1 and pistols == 0) or (rifles == 0 and pistols >= 1 and pistols <= 3)), "Easy composition always obeys exclusive ranged branches")
			elif tier == BaseEncounter.Difficulty.MID:
				check(roster.size() == 5 and pistols >= 2 and pistols <= 3 and melee >= 1 and rifles + supers == 1, "Mid composition replaces rifle with at most one super")
				saw_mid_super = saw_mid_super or supers == 1
			else:
				check(roster.size() == 7 and rifles in [1, 2] and pistols in [1, 2] and supers in [1, 2] and melee >= 1, "Hard has required ranged and super counts with melee filling remainder")
	check(generator.mid_super_chance == 0.02 and saw_mid_super, "Rare mid super branch is configured and exercised")
	for chance in [0.0, 1.0]:
		generator.mid_super_chance = chance
		var roster := generator.build_roster(BaseEncounter.Difficulty.MID)
		check(roster.count(&"super_thug") == int(chance) and roster.count(&"rifle_thug") == 1 - int(chance), "Mid super probability is tunable and replaces rifle exactly")
	generator.free()
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	player.position = Vector3(-30, 0, -30)
	world.add_child(player)
	player.set_physics_process(false)
	var indicator := player.get_node("EncounterIndicator") as PlayerEncounterIndicator
	player.abilities.set_unlocked(PlayerAbilities.TROUBLE_SENSE, false)
	await physics_frame
	await physics_frame
	for level in [1, 3, 4, 6, 7, 20]:
		player.stats.level = level
		player.stats.experience = 0
		var gang := GANG.instantiate() as GangActivityEncounter
		gang.random_number_generator.seed = level
		gang.cleanup_delay = 0.0
		world.add_child(gang)
		var events := [0, 0]
		gang.encounter_started.connect(func(): events[0] += 1)
		gang.encounter_completed.connect(func(): events[1] += 1)
		check(gang.start_encounter(player), "Encounter can place a complete roster on clear ground")
		var tier: int = {1: 0, 3: 0, 4: 1, 6: 1, 7: 2, 20: 2}[level]
		check(gang.difficulty == tier and gang.hero_level_at_start == level and gang.xp_reward == [100, 500, 1000][tier], "Level boundary locks correct tier and XP")
		check(gang.active_hostiles.size() == [4, 5, 7][tier] and events[0] == 1, "Correct count and one start signal")
		check(not gang.start_encounter(player), "Starting an active encounter cannot duplicate enemies")
		var horizontal := Vector2(gang.position.x, gang.position.z).length()
		check(horizontal >= 60 and horizontal <= 200, "Location lies in configured random distance band")
		var positions: Array[Vector3] = []
		var enemy_xp := 0
		for enemy in gang.active_hostiles:
			enemy.set_physics_process(false)
			check(enemy.faction == &"mafia" and absf(enemy.global_position.y - 0.05) < 0.01, "Spawned participants are Mafia and on ground")
			for position in positions:
				check(position.distance_to(enemy.global_position) >= gang.minimum_hostile_spacing, "Group never stacks enemies")
			positions.append(enemy.global_position)
			enemy_xp += enemy.experience_gain
		indicator._profiled_process(0.0)
		check(not indicator.visible, "Ordinary encounter retains Trouble Sense requirement")
		gang.debug_waypoint = true
		indicator._profiled_process(0.0)
		check(indicator.visible and indicator.distance_label.text.contains(gang.display_name), "Dev encounter exposes existing waypoint without granting a power")
		# Changing hero level mid-encounter cannot change composition or reward.
		player.stats.level = 50
		var expected = player.stats.duplicate()
		expected.add_experience(enemy_xp + gang.xp_reward)
		var participants := gang.active_hostiles.duplicate()
		for index in participants.size():
			participants[index]._die()
			if index < participants.size() - 1:
				check(gang.state == BaseEncounter.EncounterState.ACTIVE, "All enemies must die to complete")
		gang.complete_encounter()
		gang.fail_encounter()
		check(gang.state == BaseEncounter.EncounterState.COMPLETED and events[1] == 1, "Completion is terminal and emitted once")
		check(player.stats.experience == expected.experience and player.stats.level == expected.level, "Completion bonus and individual enemy XP awarded exactly once")
		indicator._profiled_process(0.0)
		check(not indicator.visible, "Completed encounter disappears from waypoint")
		gang.free()
	# Inadequate footprint must fail atomically rather than stack a partial group.
	var cramped := GANG.instantiate() as GangActivityEncounter
	cramped.random_location_radius = 0
	cramped.hostile_spawn_radius = 0
	cramped.ground_search_attempts = 2
	cramped.cleanup_delay = 0
	world.add_child(cramped)
	var xp_before := player.stats.experience
	check(not cramped.start_encounter(player) and cramped.active_hostiles.is_empty(), "No room fails without partial spawning")
	cramped.complete_encounter()
	check(player.stats.experience == xp_before, "Failed placement awards no XP")
	cramped.free()
	var removed := GANG.instantiate() as GangActivityEncounter
	removed.cleanup_delay = 0
	world.add_child(removed)
	check(removed.start_encounter(player), "Removal fixture starts")
	removed.active_hostiles[0].free()
	check(removed.state == BaseEncounter.EncounterState.FAILED and player.stats.experience == xp_before, "Removing a living enemy fails without completion reward")
	removed.free()
	floor_body.position.y = -12.5
	await physics_frame
	await physics_frame
	var underwater := GANG.instantiate() as GangActivityEncounter
	underwater.cleanup_delay = 0
	world.add_child(underwater)
	check(not underwater.start_encounter(player) and underwater.active_hostiles.is_empty(), "Submerged ground cannot host a gang")
	underwater.free()
	floor_body.free()
	await physics_frame
	var empty := GANG.instantiate() as GangActivityEncounter
	empty.cleanup_delay = 0
	world.add_child(empty)
	check(not empty.start_encounter(player) and empty.active_hostiles.is_empty(), "Missing ground fails cleanly")
	world.free()
	print("Gang activity encounters: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

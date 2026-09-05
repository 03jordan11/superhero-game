extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var encounter_scene := load(
		"res://scenes/encounters/gang-activity/gang_activity.tscn"
	) as PackedScene
	assert(main_scene != null)
	assert(encounter_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)
	await physics_frame

	var player := main.get_node("Player") as PlayerCharacter
	assert(player != null)
	var encounter := encounter_scene.instantiate() as GangActivityEncounter
	assert(encounter != null)
	encounter.random_location_radius = 0.0
	main.add_child(encounter)
	encounter.start_encounter()
	assert(encounter.state == BaseEncounter.EncounterState.ACTIVE)
	assert(encounter.active_hostiles.size() == 3)

	for hostile in encounter.active_hostiles.duplicate():
		hostile._die()

	assert(encounter.state == BaseEncounter.EncounterState.COMPLETED)
	# The 100 XP completion reward plus 30 XP from the hostiles advances the
	# player from level 1 to level 2, carrying 30 XP into the next level.
	assert(player.stats.level == 2)
	assert(player.stats.experience == 30)
	print("PASS: Gang Activity awards completion XP and carries XP across a level-up")
	quit()

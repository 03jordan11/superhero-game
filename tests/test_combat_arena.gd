extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("Arena test timeout"); quit(1))
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func press_interact() -> void:
	Input.action_press("pick_up_vehicle")
	for tick in 4: await physics_frame
	Input.action_release("pick_up_vehicle")
	for tick in 2: await physics_frame

func run() -> void:
	var arena: Node3D = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var hero: PlayerCharacter = arena.player
	var menu: CanvasLayer = arena.get_node("PauseMenu")
	check(arena.opponent_count() == 0, "Arena starts empty")
	check(menu.arena_button != null and menu.arena_button.text == "Return from Combat Arena", "Debug ESC menu has return button")
	check(not menu.get_node("Center/Menu/SaveButton").visible, "Arena hides save button")
	var save := root.get_node("SaveManager")
	save._save_path = "res://artifacts/arena_must_not_save.json"
	check(not save.save_game() and not FileAccess.file_exists(save._save_path), "Training refuses saves without writing a file")
	for station in arena.get_node("Stations").get_children():
		if station.enemy_id == &"reset": continue
		hero.global_position = station.global_position + Vector3(0, 0.15, 2.2)
		hero.velocity = Vector3.ZERO
		hero.camera.look_at(station.global_position + Vector3.UP)
		for tick in 3: await physics_frame
		hero.camera.look_at(station.global_position + Vector3.UP)
		check(station.can_interact(hero), "Station reachable: " + str(station.enemy_id))
		var before: int = arena.opponent_count()
		await press_interact()
		check(arena.opponent_count() == before + 1, "E spawns exactly one " + str(station.enemy_id))
		# Holding E must never produce extra enemies.
		Input.action_press("pick_up_vehicle")
		for tick in 50: await physics_frame
		Input.action_release("pick_up_vehicle")
		check(arena.opponent_count() == before + 1, "Cooldown / held E avoids duplicate spawns")
		var enemy: Node3D = arena.opponents.get_child(arena.opponents.get_child_count() - 1)
		if enemy is HostileBase:
			check(enemy.combat_target == hero, "Thug targets arena player")
			check(enemy.experience_gain == 0, "Training thug awards no XP")
		else:
			check(enemy.target == hero and enemy.gun.target == hero, "Helicopter targets arena player")
		check(enemy.apply_damage(DAMAGE.new(5.0)), "Spawned opponent accepts combat damage")
		enemy.set_physics_process(false)
	hero.global_position = Vector3(0, 0.15, 40)
	check(not arena.get_node("Stations/Melee").can_interact(hero), "Cannot interact remotely")
	var before: int = arena.opponent_count()
	await press_interact()
	check(arena.opponent_count() == before, "E away from stations does not spawn")
	arena.maximum_opponents = before
	check(arena.spawn_enemy(&"melee_thug") == null, "Spawn limit prevents runaway batches")
	check(arena.spawn_enemy(&"unknown") == null, "Unknown opponent rejected")
	var reset: Node3D = arena.get_node("Stations/Reset")
	hero.global_position = reset.global_position + Vector3(0, 0.15, 2.2)
	hero.camera.look_at(reset.global_position + Vector3.UP)
	await press_interact()
	check(arena.opponent_count() == 0, "Reset button removes every opponent")
	check(hero.get_current_health() == hero.get_max_health() and hero.stamina.is_full(), "Reset heals and restores stamina")
	var enemy: Node3D = arena.spawn_enemy(&"melee_thug")
	enemy.set_physics_process(false)
	var screen := hero.get_node("DeathScreen")
	screen.death_animation_seconds = 0.0
	hero.apply_damage(DAMAGE.new(hero.get_max_health() + 1.0))
	while not screen.visible: await process_frame
	check(paused and hero.is_dead, "Arena death still uses death screen")
	screen.respawn_button.pressed.emit()
	await process_frame
	check(current_scene == arena and not hero.is_dead and not paused, "Death respawn stays in arena and unpauses")
	check(arena.opponent_count() == 0, "Death respawn clears opponents")
	check(hero.global_position.distance_to(arena.get_node("PlayerSpawn").global_position) < 0.3, "Death returns to station area")
	menu.pause_game()
	check(paused and menu.visible, "ESC menu pauses arena")
	check(not reset.can_interact(hero), "Pause blocks station interaction")
	menu.resume_game()
	current_scene = null
	arena.free()
	print("COMBAT_ARENA_TEST failures=", failures)
	quit(1 if failures else 0)

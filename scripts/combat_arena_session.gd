extends Node
## Keeps the real hero off-tree while a disposable training hero fights.
const ARENA_PATH := "res://scenes/combat_arena.tscn"
var busy := false
var original_player: PlayerCharacter
var return_scene_path := ""
var return_player_path: NodePath
var return_pose: Transform3D
var return_camera_rotation: Vector3
var return_player_data: Dictionary
var return_health := 0.0
var return_clock_path: NodePath
var return_clock := {}

func _enter_tree() -> void:
	add_to_group(&"combat_arena_session")
	process_mode = Node.PROCESS_MODE_ALWAYS

func enter() -> bool:
	if not OS.is_debug_build() or busy or is_instance_valid(original_player): return false
	var scene := get_tree().current_scene
	var hero := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if scene == null or scene.scene_file_path.is_empty() or hero == null or hero.is_dead: return false
	if hero.is_carrying() or hero.ship_interaction.is_attached(): return false
	var loading := get_node("/root/LoadingScreen")
	if not loading.begin("ENTERING COMBAT ARENA"): return false
	busy = true
	# Capture before loading/instantiating another copy of the player's scene.
	return_player_data = SaveManager._get_player_save_data(hero).duplicate(true)
	return_health = hero.get_current_health()
	var clock := get_tree().get_first_node_in_group(&"game_clock")
	if clock != null and scene.is_ancestor_of(clock):
		return_clock_path = scene.get_path_to(clock)
		for property in ["time_of_day", "cycle_running", "day_length_minutes", "time_scale"]:
			return_clock[property] = clock.get(property)
	var packed: PackedScene = await loading.load_scene(ARENA_PATH, 0, 85)
	if packed == null:
		await loading.finish(false)
		busy = false
		return false
	var arena := packed.instantiate()
	var progression: Dictionary = hero.get_node("PlayerPowerController").progression.to_save_data().duplicate(true)
	return_scene_path = scene.scene_file_path
	return_player_path = scene.get_path_to(hero)
	return_pose = hero.global_transform
	return_camera_rotation = hero.spring_arm.rotation
	original_player = hero
	hero.input_controller.reset()
	hero.target_lock.release()
	hero.get_parent().remove_child(hero)
	get_tree().current_scene = null
	scene.free()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var trainee := arena.get_node("Player") as PlayerCharacter
	SaveManager._apply_player_save_data(trainee, return_player_data)
	trainee.get_node("PlayerPowerController").progression.apply_save_data(progression)
	# Preserve explicit developer ability overrides as well as purchased powers.
	for ability in hero.abilities.unlocked_abilities:
		trainee.abilities.set_unlocked(ability, hero.abilities.is_unlocked(ability))
	trainee.get_node("PlayerPowerController").select_active_power(hero.get_node("PlayerPowerController").active_power)
	trainee.revive_for_respawn()
	await loading.finish(true)
	busy = false
	return true

func leave() -> bool:
	if not OS.is_debug_build() or busy: return false
	var loading := get_node("/root/LoadingScreen")
	if not loading.begin("LEAVING COMBAT ARENA"): return false
	busy = true
	# F6 standalone previews return to the main menu.
	var path := return_scene_path if is_instance_valid(original_player) else "res://scenes/main_menu.tscn"
	var packed: PackedScene = await loading.load_scene(path, 0, 85)
	if packed == null:
		await loading.finish(false)
		busy = false
		return false
	var destination := packed.instantiate()
	if not return_clock_path.is_empty():
		var clock := destination.get_node_or_null(return_clock_path)
		if clock != null:
			for property in return_clock: clock.set(property, return_clock[property])
	if is_instance_valid(original_player):
		var placeholder := destination.get_node_or_null(return_player_path)
		if placeholder == null:
			destination.free()
			await loading.finish(false)
			busy = false
			return false
		var parent := placeholder.get_parent()
		var index := placeholder.get_index()
		var hero_name := placeholder.name
		placeholder.free()
		original_player.name = hero_name
		parent.add_child(original_player)
		parent.move_child(original_player, index)
	var arena := get_tree().current_scene
	get_tree().current_scene = null
	arena.free()
	get_tree().root.add_child(destination)
	get_tree().current_scene = destination
	if is_instance_valid(original_player):
		# Packed scenes can reapply exported attribute defaults while instantiating.
		# Restore authoritative values after the destination has initialized.
		SaveManager._apply_player_save_data(original_player, return_player_data)
		var health = original_player.damage_receiver.health_component
		health.current_health = return_health
		health.health_changed.emit(health.current_health, health.max_health)
		# Standalone interiors normally inherit these menus from city travel.
		if not destination.has_node("PauseMenu"):
			destination.add_child(load("res://scenes/ui/pause_menu.tscn").instantiate())
		if not destination.has_node("GameplayMenu"):
			var menu := load("res://scripts/ui-scripts/gameplay_menu.gd").new() as CanvasLayer
			menu.name = "GameplayMenu"
			destination.add_child(menu)
		if not destination.has_node("DeveloperMenu"):
			var menu := load("res://scripts/ui-scripts/developer_menu.gd").new() as CanvasLayer
			menu.name = "DeveloperMenu"
			destination.add_child(menu)
		original_player.global_transform = return_pose
		original_player.spring_arm.rotation = return_camera_rotation
		original_player.input_controller.reset()
		original_player.camera.make_current()
		original_player.reset_physics_interpolation()
		original_player = null
	await loading.finish(true)
	if path == "res://scenes/main_menu.tscn": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	busy = false
	queue_free()
	return true

func _exit_tree() -> void:
	if is_instance_valid(original_player) and not original_player.is_inside_tree():
		original_player.free()

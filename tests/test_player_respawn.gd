extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
var player: PlayerCharacter
var screen: CanvasLayer
var loading: CanvasLayer
var render := false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func die() -> void:
	player.stamina.spend_full_bar()
	player.laser_eyes.heat = 75.0
	player.status_effects.hit_slowdown_remaining = 10.0
	player.velocity = Vector3(50, -20, 70)
	check(player.apply_damage(DAMAGE.new(player.get_max_health() + 1)), "Fatal damage accepted")
	while not screen.visible: await process_frame
	check(paused and player.is_dead and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Death screen pauses with a visible cursor")
	check(screen.respawn_button.has_focus(), "Respawn is keyboard/controller focused")
	check(not player.state_machine.transition_to(&"GroundedState"), "Dead state still rejects ordinary movement transitions")
	player.damage_receiver.restore_full_health()
	check(player.get_current_health() == 0, "Ordinary healing cannot bypass death")
	var pause_menu := current_scene.get_node_or_null("PauseMenu")
	if pause_menu != null:
		var escape := InputEventAction.new()
		escape.action = &"pause"
		escape.pressed = true
		pause_menu._profiled_unhandled_input(escape)
		check(paused and not pause_menu.visible, "Escape cannot dismiss death or open pause menu")
	var menu := get_first_node_in_group(&"gameplay_menu")
	if menu != null:
		menu.open_menu()
		check(not menu.visible, "Progression menu cannot open while dead")

func press_respawn() -> void:
	screen.respawn_button.pressed.emit()
	check(screen.respawning and screen.respawn_button.disabled and loading.active, "Respawn begins loading and disables repeat clicks")
	screen.respawn_button.pressed.emit()
	if render:
		await loading.present()
		root.get_texture().get_image().save_png("res://artifacts/death_respawn_loading.png")
	while screen.respawning: await process_frame

func check_recovered(identity: int) -> void:
	check(current_scene.scene_file_path.ends_with("gas_station_interior.tscn"), "Respawn destination is the hideout")
	check(player.get_instance_id() == identity and get_nodes_in_group(&"player").size() == 1, "Same hero retained without duplicates")
	check(player.global_position.distance_to(current_scene.get_node("PlayerSpawn").global_position) < .3, "Arrives at hideout spawn")
	check(not player.is_dead and not player.is_knocked_out and not screen.visible, "Life state and death UI reset")
	check(player.get_current_health() == player.get_max_health() and player.stamina.is_full(), "Full health and stamina restored")
	check(player.laser_eyes.heat == 0 and player.status_effects.hit_slowdown_remaining == 0, "Heat and damage slowdown cleared")
	check(not player.animation_controller.is_playing_death and not player.animation_controller.is_knocked_down, "Death animation latches cleared")
	check(not paused and not loading.active and not root.is_input_disabled(), "Gameplay/input restored after loading completes")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse recaptured for movement")
	check(player.stats.money == 654 and player.stats.strength == 7 and player.abilities.is_unlocked(PlayerAbilities.FLIGHT), "Stats, money and unlocks preserved")
	check(player.get_node("PlayerPowerController").progression.tokens == 9, "Unspent power tokens preserved")
	check(player.camera.current and is_equal_approx(player.spring_arm.spring_length, 1.5), "Interior camera restored")
	check(loading.progress_bar.value == 100, "Successful arrival completes progress bar")

func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Respawn test timeout"); quit(1))
	render = "--render" in OS.get_cmdline_user_args()
	loading = root.get_node("LoadingScreen")
	loading.error_display_seconds = .01
	var city := load("res://scenes/main.tscn").instantiate() as Node3D
	for monitor in city.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	root.add_child(city)
	current_scene = city
	player = city.get_node("Player")
	screen = player.get_node("DeathScreen")
	screen.death_animation_seconds = 0.05
	var identity := player.get_instance_id()
	var outdoor_spring := player.spring_arm.spring_length
	player.stats.money = 654
	player.stats.strength = 7
	player.get_node("PlayerPowerController").progression.apply_save_data({"schema_version":2, "tokens":9, "upgrades":{"flight":0}})
	var clock := get_first_node_in_group(&"game_clock")
	clock.set_time(19.5)
	clock.cycle_running = false
	for frame in 6: await process_frame
	var entrance: Node3D = city.get_node("SuperCity/Sidewalks/GasStationHideout/HideoutEntrance")
	var expected_return := entrance.to_global(Vector3(0, .4, 1.4))
	await die()
	if render:
		await loading.present()
		root.get_texture().get_image().save_png("res://artifacts/death_screen.png")
	# Failure leaves the old scene and dead hero intact, with a working retry.
	var original_path: String = entrance.interior_scene
	entrance.interior_scene = "res://missing_respawn_destination.tscn"
	await press_respawn()
	check(current_scene == city and player.is_dead and screen.visible and paused, "Failed loading preserves the death screen and scene")
	check(not screen.respawn_button.disabled and not loading.active and not root.is_input_disabled(), "Failure permits retry")
	entrance.interior_scene = original_path
	await press_respawn()
	check_recovered(identity)
	var movement := PlayerInputSnapshot.new(Vector2.RIGHT, 1.0)
	player.state_machine.physics_update(.1, movement)
	check(Vector2(player.velocity.x, player.velocity.z).length() > 0.1, "Restored movement state accepts walking input")
	player.velocity = Vector3.ZERO
	check(not is_instance_valid(city), "Old city unloaded on respawn")
	var travel := get_first_node_in_group(&"hideout_travel")
	check(travel._return_transform.origin.distance_to(expected_return) < .01, "Hideout exit returns to the actual placed station")
	check(is_equal_approx(current_scene.get_node("Clock").time_of_day, 19.5), "World clock preserved")
	# Dying in the hideout reuses the spawn without corrupting outdoor travel data.
	var room_id := current_scene.get_instance_id()
	await die()
	await press_respawn()
	check_recovered(identity)
	check(current_scene.get_instance_id() == room_id and is_equal_approx(travel._spring_length, outdoor_spring), "Indoor respawn retains room and outdoor camera settings")
	await travel._transition(current_scene.get_node("ExitDoor"))
	check(not travel._inside and player.global_position.distance_to(expected_return) < .3, "Can leave hideout after respawn")
	check(is_equal_approx(player.spring_arm.spring_length, outdoor_spring), "City camera restored on exit")
	# Death inside another building must still respawn in the primary hideout.
	await travel._transition(current_scene.get_node("SuperCity/BoxingGymExterior/GymEntrance"))
	check(current_scene.name == &"BoxingGym", "Entered second interior")
	await die()
	await press_respawn()
	check_recovered(identity)
	check(travel._return_transform.origin.distance_to(expected_return) < .01, "Death in another interior still uses gas-station return position")
	current_scene.free()
	travel.free()
	print("PLAYER_RESPAWN failures=", failures)
	quit(1 if failures else 0)

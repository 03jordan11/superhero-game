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
	var settings := root.get_node("GameSettings")
	var path := OS.get_environment("TEMP").path_join("settings_tabs_%d.cfg" % OS.get_process_id())
	settings._settings_file = path
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	var panel = menu.settings_menu
	menu._on_settings_pressed()
	check(panel.visible and not menu.main_menu.visible, "Main menu opens shared settings")
	check(panel.tabs.get_tab_count() == 4, "Four categories")
	for i in range(4):
		check(panel.tabs.get_tab_title(i) == ["Graphics", "Audio", "Gameplay", "Controls"][i], "Tab order matches requested categories")
	for device in ["keyboard", "controller"]:
		var expected: Dictionary = settings.input_bindings.defaults(device)
		check(panel.controls_panel.buttons[device].size() == expected.size(), "Controls exposes every current binding: " + device)
		for action in expected:
			check(panel.controls_panel.buttons[device].has(action), "Missing binding control: " + action)
	check(panel.get_theme_stylebox("panel").bg_color.a == 1.0, "Settings has an opaque background")
	check(panel.hint_settings.toggle is CheckBox, "Show Control Hints is a checkbox")
	panel.tabs.current_tab = 2
	check(panel.pages.Gameplay.is_visible_in_tree() and not panel.pages.Graphics.is_visible_in_tree(), "Tabs switch content")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var pause = scene.get_node("PauseMenu")
	scene.remove_child(pause)
	scene.free()
	root.add_child(pause)
	pause.pause_game()
	pause._on_settings_pressed()
	var other = pause.settings_menu
	other.sprint_mode_dropdown.select(1)
	other.sprint_mode_dropdown.item_selected.emit(1)
	other.power_mode_dropdown.select(1)
	other.power_mode_dropdown.item_selected.emit(1)
	check(settings.toggle_sprint and settings.toggle_power_activation and panel.sprint_mode_dropdown.selected == 1, "Accessibility updates both menus while paused")
	other.hud_toggles.always_show_health.button_pressed = false
	other.hud_toggles.always_show_experience.button_pressed = false
	other.hud_toggles.always_show_stamina.button_pressed = false
	check(not panel.hud_toggles.always_show_health.button_pressed, "HUD choices synchronize")
	other.hint_settings.toggle.button_pressed = false
	check(not panel.hint_settings.toggle.button_pressed, "Control hints synchronize")
	other.volume_sliders.SFX.value = 0.0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Zero SFX mutes the group")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Voice")), "SFX mute leaves Voice independent")
	other.volume_sliders.Voice.value = 40.0
	other.volume_sliders.Master.value = 75.0
	other.volume_sliders.Music.value = 25.0
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Voice"))), 0.4), "Voice slider controls bus gain")
	check(panel.volume_sliders.Master.value == 75.0, "Audio controls synchronize")
	await create_timer(0.35).timeout
	var saved := ConfigFile.new()
	check(saved.load(path) == OK and saved.get_value("audio", "Voice") == 0.4, "Debounced slider change persists while paused")
	check(saved.get_value("accessibility", "toggle_power_activation") and not saved.get_value("hud", "always_show_stamina"), "Future preferences persist")
	for bus in [&"PlayerImpacts", &"PlayerFootsteps", &"PlayerSpeedWind", &"VehicleExplosions"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"SFX", "Existing effect bus feeds SFX: " + String(bus))
	for bus in [&"SFX", &"Music", &"Voice"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"Master", "Master controls all categories")
	# Exercise graphics UI and persistence. Headless display application is a no-op.
	other.display_mode_dropdown.select(1)
	other.resolution_dropdown.select(1)
	other.resolution_dropdown.item_selected.emit(1)
	check(settings.display_mode == 1 and settings.window_resolution == Vector2i(1600, 900), "Display choices reach settings")
	other.display_mode_dropdown.select(2)
	other.display_mode_dropdown.item_selected.emit(2)
	check(other.resolution_dropdown.disabled and panel.resolution_dropdown.disabled, "Native fullscreen disables window resolution control")
	pause._on_back_pressed()
	check(not other.visible and pause.pause_actions.visible and paused, "Back from settings keeps game paused")
	pause.resume_game()
	check(not paused, "Resume still works")
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var hud = player.get_node("GameplayHUD")
	check(not hud.get_node("Health").visible and not hud.get_node("Progression").visible, "Unchecked always-show hides idle full health and XP")
	player.apply_damage(DAMAGE.new(10.0))
	check(hud.get_node("Health").visible, "Damage reveals health")
	hud._health_recent.stop()
	hud._refresh_status_visibility()
	check(hud.get_node("Health").visible, "Health stays visible while damaged")
	player.damage_receiver.health_component.current_health = player.get_max_health()
	player.damage_receiver.health_component.health_changed.emit(player.get_max_health(), player.get_max_health())
	check(hud.get_node("Health").visible, "Healing retains a short readout")
	hud._health_recent.start(0.02)
	await create_timer(0.06).timeout
	check(not hud.get_node("Health").visible, "Full health hides after recent-change timer")
	player.stats.add_experience(125)
	check(hud.get_node("Progression").visible and hud.level_label.text == "Lv 2", "XP gain and level-up reveal current progression")
	hud._experience_recent.start(0.02)
	await create_timer(0.06).timeout
	check(not hud.get_node("Progression").visible, "Progression hides after its timer")
	settings.set_hud_preference(&"always_show_health", true, false)
	settings.set_hud_preference(&"always_show_experience", true, false)
	check(hud.get_node("Health").visible and hud.get_node("Progression").visible, "Always-show restores persistent HUD")
	check(player.get_node("PlayerSoundManager/Death").bus == &"Voice" and player.get_node("PlayerSoundManager/ComboPunch").bus == &"SFX", "Player vocals and effects have distinct routes")
	settings.load_settings(path)
	check(settings.toggle_sprint and settings.audio_volumes.Voice == 0.4 and not settings.always_show_health, "Saved preferences survive reload")
	# Invalid types must not enable toggles or inject non-finite mixer/display values.
	var invalid := ConfigFile.new()
	invalid.set_value("audio", "SFX", NAN)
	invalid.set_value("accessibility", "toggle_sprint", "true")
	invalid.set_value("hud", "always_show_health", 0)
	invalid.set_value("display", "mode", 99)
	invalid.set_value("display", "resolution", Vector2i(-1, -1))
	invalid.save(path)
	settings.load_settings(path)
	check(settings.audio_volumes.SFX == 1.0 and not settings.toggle_sprint and settings.always_show_health, "Invalid preferences use safe defaults")
	check(settings.display_mode == 0 and settings.window_resolution == Vector2i(1920, 1080), "Invalid display values use defaults")
	settings._settings_file = "res://.godot/nonexistent_settings_dir/preferences.cfg"
	panel.hud_toggles.always_show_health.button_pressed = false
	check(panel.status.text.contains("could not save") and not settings.always_show_health, "Save failures are visible while changes still apply")
	settings._settings_file = path
	menu._on_back_pressed()
	check(menu.main_menu.visible and not panel.visible, "Main-menu Back navigation")
	player.free()
	pause.free()
	menu.free()
	DirAccess.remove_absolute(path)
	print("Settings tabs: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

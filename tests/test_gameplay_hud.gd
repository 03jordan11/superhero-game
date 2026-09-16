extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const PALETTE = preload("res://assets/ui/default_palette.tres")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var settings := root.get_node("GameSettings")
	var original_settings_path: String = settings._settings_file
	settings._settings_file = OS.get_environment("TEMP").path_join("hud_settings_test_%d.cfg" % OS.get_process_id())
	settings.set_show_control_hints(true, false)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: PlayerCharacter = main.get_node("Player")
	player.set_physics_process(false)
	var hud = player.get_node("GameplayHUD")
	check(hud.visible and not player.has_node("ChargeUI"), "Gameplay HUD remains visible without obsolete diagnostics")
	check(hud.health_label.text == "1000 / 1000" and hud.health_bar.value == 1000, "Initial health must match the initialized player")
	check(hud.level_label.text == "Lv 1" and hud.experience_label.text == "0 / 100 XP", "Initial progression should be visible without recent XP")
	player.apply_damage(DAMAGE.new(25.0))
	check(hud.health_label.text == "975 / 1000" and hud.health_bar.value == 975, "Actual damage should update health")
	player.stats.add_experience(125)
	check(hud.level_label.text == "Lv 2" and hud.experience_label.text == "25 / 200 XP", "Level-up must refresh both XP and threshold")
	check(hud.experience_bar.value == 25 and hud.experience_bar.max_value == 200, "XP bar should match progression")
	player.stats.resilience += 1
	check(hud.health_bar.max_value == player.get_max_health(), "Maximum health changes should refresh the HUD")
	var original_bindings := InputMap.action_get_events("jump")
	InputMap.action_erase_events("jump")
	var rebound := InputEventKey.new()
	rebound.keycode = KEY_K
	rebound.ctrl_pressed = true
	InputMap.action_add_event("jump", rebound)
	hud._process(0.25)
	check(hud.hint_keys.jump.text.contains("K") and hud.hint_keys.jump.text.contains("Ctrl"), "Hints must reflect live rebinding and modifiers")
	InputMap.action_erase_events("jump")
	hud.refresh_key_hints()
	check(hud.hint_keys.jump.text == "Unbound", "Unbound actions must not show an old/default key")
	for event in original_bindings: InputMap.action_add_event("jump", event)
	hud.refresh_key_hints()
	var pause_menu = main.get_node("PauseMenu")
	var main_menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(main_menu)
	var pause_toggle = pause_menu.get_node("Center/SettingsMenu").hint_settings.toggle
	var main_toggle = main_menu.get_node("Center/SettingsMenu").hint_settings.toggle
	pause_menu.pause_game()
	pause_menu._on_settings_pressed()
	pause_toggle.button_pressed = false
	check(not hud.get_node("Hints").visible and not main_toggle.button_pressed, "Paused toggle should update HUD and both settings menus")
	check(hud.visible and hud.health_label.is_visible_in_tree(), "Hint toggle must not hide health or XP")
	var config := ConfigFile.new()
	check(config.load(settings._settings_file) == OK and config.get_value("hud", "show_control_hints") == false, "Hint setting must persist")
	settings.set_population_settings(0, 1, 2)
	settings.set_show_control_hints(true, false)
	settings.load_settings()
	check(not settings.show_control_hints and not hud.get_node("Hints").visible, "Reload should restore saved hint preference")
	check(settings.crowd_density == 0 and settings.vehicle_density == 1, "Hint preferences must coexist with population presets")
	main_toggle.button_pressed = true
	check(hud.get_node("Hints").visible and pause_toggle.button_pressed, "Main-menu toggle must restore hints")
	pause_menu.resume_game()
	main_menu.free()
	# Verify shared resource colors affect both HUD and menu construction.
	var original_accent: Color = PALETTE.accent
	PALETTE.set("accent", Color(1, 0.3, 0.5))
	hud._apply_palette()
	main.get_node("GameplayMenu").powers_page._refresh()
	check(hud.health_bar.get_theme_stylebox("fill").bg_color == PALETTE.accent, "HUD must use shared palette")
	check(main.get_node("GameplayMenu").powers_page.power_buttons.super_leap.get_theme_stylebox("normal").border_color == PALETTE.accent, "Powers must use the same shared palette")
	PALETTE.set("accent", original_accent)
	main.free()
	DirAccess.remove_absolute(settings._settings_file)
	settings._settings_file = original_settings_path
	if failures == 0: print("PASS: static HUD, damage/XP updates, rebound keys, paused/main hint toggle, persistence and shared palette")
	quit(1 if failures else 0)

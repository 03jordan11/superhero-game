extends Node
## Player preferences only. Managers own the translation into their scene tuning.
signal population_settings_changed
signal control_hints_changed
signal display_settings_changed
signal audio_settings_changed
signal gameplay_settings_changed
signal accessibility_settings_changed

enum Quality { LOW, MEDIUM, HIGH }
const SETTINGS_FILE := "user://settings.cfg"
const DENSITY_SCALES := [0.5, 0.75, 1.0]
const DISTANCE_SCALES := [0.6, 0.8, 1.0]

var crowd_density: int = Quality.HIGH
var vehicle_density: int = Quality.HIGH
var population_view_distance: int = Quality.HIGH
var show_control_hints := true
var always_show_health := true
var always_show_stamina := true
var always_show_experience := true
var toggle_sprint := false
var toggle_power_activation := false
var display_mode := 0
var window_resolution := Vector2i(1920, 1080)
var audio_volumes := {&"Master": 1.0, &"SFX": 1.0, &"Music": 1.0, &"Voice": 1.0}
var _settings_file := SETTINGS_FILE
var input_bindings = preload("res://scripts/input_bindings.gd").new()

func _ready() -> void:
	input_bindings.name = "InputBindings"
	add_child(input_bindings)
	load_settings()

func crowd_scale() -> float:
	return DENSITY_SCALES[crowd_density]

func vehicle_scale() -> float:
	return DENSITY_SCALES[vehicle_density]

func distance_scale() -> float:
	return DISTANCE_SCALES[population_view_distance]

func set_population_settings(crowd: int, vehicles: int, distance: int, persist := true) -> Error:
	var next_crowd := clampi(crowd, Quality.LOW, Quality.HIGH)
	var next_vehicles := clampi(vehicles, Quality.LOW, Quality.HIGH)
	var next_distance := clampi(distance, Quality.LOW, Quality.HIGH)
	var changed := crowd_density != next_crowd or vehicle_density != next_vehicles or population_view_distance != next_distance
	crowd_density = next_crowd
	vehicle_density = next_vehicles
	population_view_distance = next_distance
	if changed: population_settings_changed.emit()
	return save_settings() if persist else OK

func save_settings(path := "") -> Error:
	if path.is_empty(): path = _settings_file
	var config := ConfigFile.new()
	input_bindings.write_config(config)
	config.set_value("population", "crowd_density", crowd_density)
	config.set_value("population", "vehicle_density", vehicle_density)
	config.set_value("population", "view_distance", population_view_distance)
	config.set_value("hud", "show_control_hints", show_control_hints)
	for key in [&"always_show_health", &"always_show_stamina", &"always_show_experience"]:
		config.set_value("hud", key, get(key))
	config.set_value("accessibility", "toggle_sprint", toggle_sprint)
	config.set_value("accessibility", "toggle_power_activation", toggle_power_activation)
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "resolution", window_resolution)
	for bus in audio_volumes:
		config.set_value("audio", bus, audio_volumes[bus])
	return config.save(path)

func load_settings(path := "") -> void:
	if path.is_empty(): path = _settings_file
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		push_warning("Could not read game settings; using defaults.")
	input_bindings.load_config(config)
	set_population_settings(
		_read_quality(config, "crowd_density"),
		_read_quality(config, "vehicle_density"),
		_read_quality(config, "view_distance"), false)
	var saved_hints: Variant = config.get_value("hud", "show_control_hints", true)
	set_show_control_hints(saved_hints if saved_hints is bool else true, false)
	for key in [&"always_show_health", &"always_show_stamina", &"always_show_experience"]:
		set_hud_preference(key, _read_bool(config, "hud", key, true), false)
	set_accessibility(_read_bool(config, "accessibility", "toggle_sprint", false),
		_read_bool(config, "accessibility", "toggle_power_activation", false), false)
	for bus in audio_volumes:
		var value: Variant = config.get_value("audio", bus, 1.0)
		var valid := (value is float or value is int) and is_finite(float(value))
		set_audio_volume(bus, clampf(float(value), 0.0, 1.0) if valid else 1.0, false)
	var mode: Variant = config.get_value("display", "mode", 0)
	display_mode = mode if mode is int and mode >= 0 and mode <= 2 else 0
	var resolution: Variant = config.get_value("display", "resolution", Vector2i(1920, 1080))
	window_resolution = resolution if resolution is Vector2i and resolution.x >= 640 and resolution.y >= 360 and resolution.x <= 7680 and resolution.y <= 4320 else Vector2i(1920, 1080)
	# Old preference files had no display settings; preserve their current window.
	if config.has_section("display"):
		apply_display_settings()
	elif DisplayServer.get_name() != "headless":
		var window := get_window()
		display_mode = 2 if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else (1 if window.borderless else 0)
		if window.mode == Window.MODE_WINDOWED and window.size.x >= 640 and window.size.y >= 360:
			window_resolution = window.size
	display_settings_changed.emit()

func set_show_control_hints(enabled: bool, persist := true) -> Error:
	if show_control_hints != enabled:
		show_control_hints = enabled
		control_hints_changed.emit()
	return save_settings() if persist else OK

func _read_quality(config: ConfigFile, key: String) -> int:
	var value: Variant = config.get_value("population", key, Quality.HIGH)
	if value is int and value >= Quality.LOW and value <= Quality.HIGH: return value
	return Quality.HIGH

func _read_bool(config: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value(section, key, fallback)
	return value if value is bool else fallback

func set_hud_preference(key: StringName, enabled: bool, persist := true) -> Error:
	if key not in [&"always_show_health", &"always_show_stamina", &"always_show_experience"]:
		return ERR_INVALID_PARAMETER
	if get(key) != enabled:
		set(key, enabled)
		gameplay_settings_changed.emit()
	return save_settings() if persist else OK

func set_accessibility(sprint_toggle: bool, power_toggle: bool, persist := true) -> Error:
	var changed := toggle_sprint != sprint_toggle or toggle_power_activation != power_toggle
	toggle_sprint = sprint_toggle
	toggle_power_activation = power_toggle
	if changed: accessibility_settings_changed.emit()
	return save_settings() if persist else OK

func set_audio_volume(bus: StringName, volume: float, persist := true) -> Error:
	if not audio_volumes.has(bus) or not is_finite(volume): return ERR_INVALID_PARAMETER
	audio_volumes[bus] = clampf(volume, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(audio_volumes[bus], 0.0001)))
	audio_settings_changed.emit()
	return save_settings() if persist else OK

func set_display_settings(mode: int, resolution: Vector2i, persist := true) -> Error:
	if mode < 0 or mode > 2 or resolution.x < 640 or resolution.y < 360 or resolution.x > 7680 or resolution.y > 4320:
		return ERR_INVALID_PARAMETER
	display_mode = mode
	window_resolution = resolution
	apply_display_settings()
	display_settings_changed.emit()
	return save_settings() if persist else OK

func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless": return
	var window := get_window()
	if display_mode == 2:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = display_mode == 1
		window.size = window_resolution

extends Node
## Player preferences only. Managers own the translation into their scene tuning.
signal population_settings_changed
signal control_hints_changed
signal display_settings_changed
signal audio_settings_changed
signal gameplay_settings_changed
signal accessibility_settings_changed
signal graphics_settings_changed
signal look_sensitivity_changed

enum Quality { LOW, MEDIUM, HIGH }
enum ShadowQuality { OFF, LOW, MEDIUM, HIGH }
const RENDER_SCALES := [50, 75, 100]
const FPS_LIMITS := [30, 60, 120, 0]
const SHADOW_DISTANCES := [0.0, 80.0, 160.0, 300.0]
const SHADOW_ATLAS_SIZES := [1024, 1024, 2048, 4096]
const SETTINGS_FILE := "user://settings.cfg"
const DENSITY_SCALES := [0.5, 0.75, 1.0]
const DISTANCE_SCALES := [0.6, 0.8, 1.0]
const MIN_LOOK_SENSITIVITY := 0.25
const MAX_LOOK_SENSITIVITY := 3.0

var crowd_density: int = Quality.HIGH
var vehicle_density: int = Quality.HIGH
var population_view_distance: int = Quality.HIGH
var show_control_hints := true
var show_minimap := true
var always_show_health := true
var always_show_stamina := true
var always_show_experience := true
var toggle_sprint := false
var toggle_power_activation := false
var look_sensitivity := 1.0
var display_mode := 0
var window_resolution := Vector2i(1920, 1080)
var render_scale := 100
var shadow_quality: int = ShadowQuality.HIGH
var bloom_enabled := true
var fps_limit := 0
var vsync_enabled := true
var audio_volumes := {&"Master": 1.0, &"SFX": 1.0, &"Music": 1.0, &"Voice": 1.0}
var _settings_file := SETTINGS_FILE
var _display_revision := 0
var _window_fit_callback: Callable
var input_bindings = preload("res://scripts/input_bindings.gd").new()

func _ready() -> void:
	input_bindings.name = "InputBindings"
	add_child(input_bindings)
	load_settings()
	get_tree().node_added.connect(_on_graphics_node_added)

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
	config.set_value("controls", "look_sensitivity", look_sensitivity)
	config.set_value("population", "crowd_density", crowd_density)
	config.set_value("population", "vehicle_density", vehicle_density)
	config.set_value("population", "view_distance", population_view_distance)
	config.set_value("hud", "show_control_hints", show_control_hints)
	for key in [&"always_show_health", &"always_show_stamina", &"always_show_experience", &"show_minimap"]:
		config.set_value("hud", key, get(key))
	config.set_value("accessibility", "toggle_sprint", toggle_sprint)
	config.set_value("accessibility", "toggle_power_activation", toggle_power_activation)
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "resolution", window_resolution)
	for key in [&"render_scale", &"shadow_quality", &"bloom_enabled", &"fps_limit", &"vsync_enabled"]:
		config.set_value("graphics", key, get(key))
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
	var sensitivity: Variant = config.get_value("controls", "look_sensitivity", 1.0)
	var valid_sensitivity := (sensitivity is float or sensitivity is int) and is_finite(float(sensitivity))
	set_look_sensitivity(float(sensitivity) if valid_sensitivity else 1.0, false)
	set_population_settings(
		_read_quality(config, "crowd_density"),
		_read_quality(config, "vehicle_density"),
		_read_quality(config, "view_distance"), false)
	var saved_hints: Variant = config.get_value("hud", "show_control_hints", true)
	set_show_control_hints(saved_hints if saved_hints is bool else true, false)
	for key in [&"always_show_health", &"always_show_stamina", &"always_show_experience", &"show_minimap"]:
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
	set_graphics_settings(
		_read_graphics_choice(config, "render_scale", RENDER_SCALES, 100),
		_read_graphics_choice(config, "shadow_quality", [0, 1, 2, 3], ShadowQuality.HIGH),
		_read_bool(config, "graphics", "bloom_enabled", true),
		_read_graphics_choice(config, "fps_limit", FPS_LIMITS, 0),
		_read_bool(config, "graphics", "vsync_enabled", true), false)

func _read_graphics_choice(config: ConfigFile, key: String, choices: Array, fallback: int) -> int:
	var value: Variant = config.get_value("graphics", key, fallback)
	return value if value is int and value in choices else fallback

func set_graphics_settings(scale_percent: int, shadows: int, bloom: bool, cap: int, vsync: bool, persist := true) -> Error:
	if scale_percent not in RENDER_SCALES or shadows < ShadowQuality.OFF or shadows > ShadowQuality.HIGH or cap not in FPS_LIMITS:
		return ERR_INVALID_PARAMETER
	render_scale = scale_percent
	shadow_quality = shadows
	bloom_enabled = bloom
	fps_limit = cap
	vsync_enabled = vsync
	apply_graphics_settings()
	graphics_settings_changed.emit()
	return save_settings() if persist else OK

func apply_graphics_settings() -> void:
	var window := get_window()
	window.scaling_3d_scale = render_scale / 100.0
	window.positional_shadow_atlas_size = SHADOW_ATLAS_SIZES[shadow_quality]
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[shadow_quality], true)
	Engine.max_fps = fps_limit
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED, window.get_window_id())
	for node in get_tree().root.find_children("*", "Light3D", true, false):
		_apply_graphics_to_node(node)
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_graphics_to_node(node)

func _on_graphics_node_added(node: Node) -> void:
	if node is Light3D or node is WorldEnvironment:
		_apply_graphics_to_id.call_deferred(node.get_instance_id())

func _apply_graphics_to_id(id: int) -> void:
	# A short-lived effect or a scene change may free a light before this runs.
	var node := instance_from_id(id) as Node
	if is_instance_valid(node): _apply_graphics_to_node(node)

func _apply_graphics_to_node(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	if node is Light3D:
		if not node.has_meta("graphics_original_shadow"):
			node.set_meta("graphics_original_shadow", node.shadow_enabled)
		var allowed := shadow_quality != ShadowQuality.OFF
		if not node is DirectionalLight3D and shadow_quality == ShadowQuality.LOW: allowed = false
		node.shadow_enabled = bool(node.get_meta("graphics_original_shadow")) and allowed
		if node is DirectionalLight3D:
			if not node.has_meta("graphics_original_shadow_distance"):
				node.set_meta("graphics_original_shadow_distance", node.directional_shadow_max_distance)
			var original: float = node.get_meta("graphics_original_shadow_distance")
			node.directional_shadow_max_distance = original if shadow_quality == ShadowQuality.HIGH else minf(original, SHADOW_DISTANCES[shadow_quality])
	elif node is WorldEnvironment and node.environment != null and not node.has_meta("day_night_environment"):
		if not node.has_meta("graphics_original_glow"):
			node.set_meta("graphics_original_glow", node.environment.glow_enabled)
			node.environment = node.environment.duplicate()
		node.environment.glow_enabled = bloom_enabled and bool(node.get_meta("graphics_original_glow"))

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
	if key not in [&"always_show_health", &"always_show_stamina", &"always_show_experience", &"show_minimap"]:
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

func set_look_sensitivity(value: float, persist := true) -> Error:
	if not is_finite(value): return ERR_INVALID_PARAMETER
	var next := clampf(value, MIN_LOOK_SENSITIVITY, MAX_LOOK_SENSITIVITY)
	if not is_equal_approx(look_sensitivity, next):
		look_sensitivity = next
		look_sensitivity_changed.emit()
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
	_display_revision += 1
	if _window_fit_callback.is_valid() and get_tree().process_frame.is_connected(_window_fit_callback):
		get_tree().process_frame.disconnect(_window_fit_callback)
	if DisplayServer.get_name() == "headless": return
	var window := get_window()
	# Remember the monitor before fullscreen/window decorations alter the bounds.
	var screen := window.current_screen
	if display_mode == 2:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = display_mode == 1
		_fit_display_window(screen, _display_revision, 2)

func _fit_display_window(screen: int, revision: int, remaining_frames: int) -> void:
	# Old callbacks must not resize a newer selection or pull us out of fullscreen.
	if revision != _display_revision or display_mode == 2: return
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED: return
	screen = clampi(screen, 0, maxi(DisplayServer.get_screen_count() - 1, 0))
	window.current_screen = screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if not usable.has_area(): return
	var id := window.get_window_id()
	var client_size := DisplayServer.window_get_size(id)
	var outer_size := DisplayServer.window_get_size_with_decorations(id)
	var decoration_size := (outer_size - client_size).max(Vector2i.ZERO)
	var client_offset := DisplayServer.window_get_position(id) - DisplayServer.window_get_position_with_decorations(id)
	# Keep a small gap around the entire native frame, not just the game viewport.
	var padding := Vector2i(8, 8)
	var available := (usable.size - decoration_size - padding * 2).max(Vector2i.ONE)
	var scale := minf(1.0, minf(float(available.x) / window_resolution.x, float(available.y) / window_resolution.y))
	window.size = Vector2i(Vector2(window_resolution) * scale).max(Vector2i.ONE)
	outer_size = DisplayServer.window_get_size_with_decorations(id)
	window.position = usable.position + (usable.size - outer_size) / 2 + client_offset
	# Native mode/DPI changes may settle after this frame. These one-shot callbacks
	# also run while the settings menu has paused gameplay, then stop repositioning.
	if remaining_frames > 0:
		_window_fit_callback = _fit_display_window.bind(screen, revision, remaining_frames - 1)
		get_tree().process_frame.connect(_window_fit_callback, CONNECT_ONE_SHOT)

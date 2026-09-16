extends PanelContainer
## Shared main/pause settings. Gameplay systems consume GameSettings preferences.
signal back_requested
const PALETTE = preload("res://assets/ui/default_palette.tres")
const POPULATION = preload("res://scenes/ui/population_settings.tscn")
const HINT_SETTINGS = preload("res://scripts/ui-scripts/control_hint_settings.gd")
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const HUD_LABELS := {&"always_show_health": "Always Show Health", &"always_show_stamina": "Always Show Stamina", &"always_show_experience": "Always Show Level / XP"}
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
var resolutions: Array[Vector2i] = RESOLUTIONS.duplicate()
var pages: Dictionary = {}
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var hud_toggles: Dictionary = {}
var display_mode_dropdown: OptionButton
var resolution_dropdown: OptionButton
var sprint_mode_dropdown: OptionButton
var power_mode_dropdown: OptionButton
var population_settings: Node
var hint_settings: Node
var controls_panel: VBoxContainer
var _audio_save_timer: Timer
@onready var settings: Node = get_node("/root/GameSettings")
@onready var tabs: TabContainer = $Margin/Layout/Tabs
@onready var status: Label = $Margin/Layout/Status

func _ready() -> void:
	PALETTE.apply_menu_colors(self)
	add_theme_stylebox_override("panel", _box(PALETTE.surface, PALETTE.border, 14))
	tabs.add_theme_stylebox_override("panel", _box(PALETTE.surface, PALETTE.border, 5))
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus"]:
		var selected: bool = state == "tab_selected" or state == "tab_focus"
		var style := _box(PALETTE.surface_selected if selected else PALETTE.surface_raised, PALETTE.accent if selected else PALETTE.border, 5)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		tabs.add_theme_stylebox_override(state, style)
	tabs.add_theme_color_override("font_selected_color", PALETTE.accent_soft)
	tabs.add_theme_color_override("font_unselected_color", PALETTE.text_secondary)
	for title in ["Graphics", "Audio", "Gameplay", "Controls"]:
		pages[title] = _page(title)
	_build_graphics()
	_build_audio()
	_build_gameplay()
	controls_panel = preload("res://scripts/ui-scripts/control_bindings_panel.gd").new()
	pages.Controls.add_child(controls_panel)
	controls_panel.status_changed.connect(func(copy: String): status.text = copy)
	$Margin/Layout/BackButton.pressed.connect(func(): back_requested.emit())
	settings.display_settings_changed.connect(_refresh_display)
	settings.audio_settings_changed.connect(_refresh_audio)
	settings.gameplay_settings_changed.connect(_refresh_gameplay)
	settings.accessibility_settings_changed.connect(_refresh_gameplay)
	_refresh_display()
	_refresh_audio()
	_refresh_gameplay()
	_audio_save_timer = Timer.new()
	_audio_save_timer.one_shot = true
	_audio_save_timer.wait_time = 0.25
	_audio_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_audio_save_timer)
	_audio_save_timer.timeout.connect(_save_audio)

func open_page() -> void:
	_refresh_display()
	_refresh_audio()
	_refresh_gameplay()
	show()
	tabs.get_tab_bar().grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or settings.input_bindings.is_capturing: return
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var direction := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())
		tabs.get_tab_bar().grab_focus()
		get_viewport().set_input_as_handled()

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	return content

func _build_graphics() -> void:
	var page: VBoxContainer = pages.Graphics
	display_mode_dropdown = _option(page, "Display Mode", ["Windowed", "Borderless Windowed", "Fullscreen"])
	resolution_dropdown = _option(page, "Resolution", [])
	for resolution in resolutions:
		resolution_dropdown.add_item("%d × %d" % [resolution.x, resolution.y])
	resolution_dropdown.tooltip_text = "Window size. Fullscreen uses your display's native resolution."
	display_mode_dropdown.item_selected.connect(_on_display_selected)
	resolution_dropdown.item_selected.connect(_on_display_selected)
	_heading(page, "Performance")
	population_settings = POPULATION.instantiate()
	page.add_child(population_settings)
	_note(page, "Population settings adjust pedestrians and traffic. Buildings are unaffected.")

func _build_audio() -> void:
	var page: VBoxContainer = pages.Audio
	for bus in [&"Master", &"SFX", &"Music", &"Voice"]:
		var row := _row(page, "Sound Effects" if bus == &"SFX" else String(bus))
		var slider := HSlider.new()
		slider.name = String(bus) + "Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(230, 44)
		row.add_child(slider)
		var amount := Label.new()
		amount.custom_minimum_size.x = 66
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.add_theme_font_size_override("font_size", 22)
		row.add_child(amount)
		volume_sliders[bus] = slider
		volume_labels[bus] = amount
		slider.value_changed.connect(_on_volume_changed.bind(bus))
	_note(page, "Voice controls player vocal sounds and future dialogue. Music volume is ready for future music.")

func _build_gameplay() -> void:
	var page: VBoxContainer = pages.Gameplay
	page.add_theme_constant_override("separation", 10)
	_heading(page, "HUD")
	hint_settings = HINT_SETTINGS.new()
	page.add_child(hint_settings)
	hint_settings.toggle.custom_minimum_size.y = 36
	for key in HUD_LABELS:
		var toggle := CheckBox.new()
		toggle.text = HUD_LABELS[key]
		toggle.custom_minimum_size.y = 36
		toggle.add_theme_font_size_override("font_size", 22)
		page.add_child(toggle)
		hud_toggles[key] = toggle
		toggle.toggled.connect(_on_hud_toggled.bind(key))
	_note(page, COPY.text("hud.settings.visibility_help"))
	_heading(page, "Accessibility")
	sprint_mode_dropdown = _option(page, "Boost / Sprint", ["Hold", "Toggle"])
	power_mode_dropdown = _option(page, "Aim / Zoom (Right Click)", ["Hold", "Toggle"])
	sprint_mode_dropdown.item_selected.connect(_on_accessibility_selected)
	power_mode_dropdown.item_selected.connect(_on_accessibility_selected)
	_note(page, "Toggle: press once to activate, again to stop. Sprint and aim reset when paused. While aiming, hold Attack to fire Laser Eyes. Without aiming, Attack punches or air slams.")

func _row(page: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(380, 44)
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	return row

func _option(page: VBoxContainer, title: String, choices: Array) -> OptionButton:
	var row := _row(page, title)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.y = 44
	option.add_theme_font_size_override("font_size", 22)
	for choice in choices: option.add_item(choice)
	row.add_child(option)
	return option

func _heading(page: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", PALETTE.accent)
	page.add_child(label)

func _note(page: VBoxContainer, copy: String) -> void:
	var label := Label.new()
	label.text = copy
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", PALETTE.text_secondary)
	page.add_child(label)

func _box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box

func _refresh_display() -> void:
	display_mode_dropdown.select(settings.display_mode)
	var resolution: Vector2i = settings.window_resolution
	if not resolutions.has(resolution):
		resolutions.append(resolution)
		resolution_dropdown.add_item("%d × %d" % [resolution.x, resolution.y])
	resolution_dropdown.select(resolutions.find(resolution))
	resolution_dropdown.disabled = settings.display_mode == 2

func _refresh_audio() -> void:
	for bus in volume_sliders:
		var value := roundi(float(settings.audio_volumes[bus]) * 100.0)
		volume_sliders[bus].set_value_no_signal(value)
		volume_labels[bus].text = "%d%%" % value

func _refresh_gameplay() -> void:
	for key in hud_toggles:
		hud_toggles[key].set_pressed_no_signal(settings.get(key))
	sprint_mode_dropdown.select(1 if settings.toggle_sprint else 0)
	power_mode_dropdown.select(1 if settings.toggle_power_activation else 0)

func _on_display_selected(_index: int) -> void:
	_report_save(settings.set_display_settings(display_mode_dropdown.selected, resolutions[resolution_dropdown.selected]))

func _on_volume_changed(value: float, bus: StringName) -> void:
	settings.set_audio_volume(bus, value / 100.0, false)
	# Preview immediately, but avoid writing the config every frame while dragging.
	_audio_save_timer.start()

func _save_audio() -> void:
	_report_save(settings.save_settings())

func _exit_tree() -> void:
	if is_instance_valid(_audio_save_timer) and not _audio_save_timer.is_stopped() and is_instance_valid(settings):
		settings.save_settings()

func _on_hud_toggled(value: bool, key: StringName) -> void:
	_report_save(settings.set_hud_preference(key, value))

func _on_accessibility_selected(_index: int) -> void:
	_report_save(settings.set_accessibility(sprint_mode_dropdown.selected == 1, power_mode_dropdown.selected == 1))

func _report_save(result: Error) -> void:
	status.text = "Changes are saved automatically." if result == OK else "Applied, but could not save settings."

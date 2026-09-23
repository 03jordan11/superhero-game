extends PanelContainer
## Shown with the debug menu, whose existing pause/mouse handling allows sliders.
const PALETTE = preload("res://assets/ui/default_palette.tres")
var _library: Node
var _sliders: Dictionary = {}
var _numbers: Dictionary = {}
var _district_toggle: CheckButton
var _night_button: Button
var _day_button: Button

func _ready() -> void:
	_library = get_node("/root/CityWindows")
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "WindowLightingControls"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0.43
	offset_left = 24
	offset_top = 24
	offset_right = 0
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.background
	style.border_color = PALETTE.owned_border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, 20)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "Night windows"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", PALETTE.accent)
	column.add_child(title)
	_add_slider(column, "Lit windows", "lit_window_percent")
	_district_toggle = CheckButton.new()
	_district_toggle.text = "Use separate building percentages"
	_district_toggle.toggled.connect(func(value: bool): _library.use_district_percentages = value)
	column.add_child(_district_toggle)
	_add_slider(column, "Commercial", "commercial_percent")
	_add_slider(column, "Residential", "residential_percent")
	_add_slider(column, "Industrial", "industrial_percent")
	column.add_child(HSeparator.new())
	_add_slider(column, "Banks", "bank_percent")
	_add_slider(column, "Police stations", "police_percent")
	_add_slider(column, "City Hall", "city_hall_percent")
	_add_slider(column, "Hospital", "hospital_percent")
	_add_slider(column, "Firehouse", "firehouse_percent")
	column.add_child(HSeparator.new())
	_add_slider(column, "Warm colors", "warm_window_percent")
	_add_slider(column, "Brightness", "brightness", 3.0, 0.05)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_night_button = Button.new()
	_night_button.text = "Set midnight"
	_night_button.pressed.connect(_set_time.bind(0.0))
	buttons.add_child(_night_button)
	_day_button = Button.new()
	_day_button.text = "Set noon"
	_day_button.pressed.connect(_set_time.bind(12.0))
	buttons.add_child(_day_button)
	var note := Label.new()
	note.text = "Changes appear immediately, even while paused.\nWarm colors mixes amber/yellow; the rest are cool blue-white.\nUse the existing save command to keep these settings."
	note.add_theme_font_size_override("font_size", 18)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_library.settings_changed.connect(_refresh)
	_refresh()

func _add_slider(column: VBoxContainer, label_text: String, property: String, maximum := 100.0, increment := 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 165
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = property
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 110
	slider.max_value = maximum
	slider.step = increment
	slider.value_changed.connect(func(value: float): _library.set(property, value))
	row.add_child(slider)
	var number := SpinBox.new()
	number.max_value = maximum
	number.step = increment
	number.suffix = "%" if maximum == 100.0 else "x"
	number.custom_minimum_size.x = 120
	number.value_changed.connect(func(value: float): _library.set(property, value))
	row.add_child(number)
	_sliders[property] = slider
	_numbers[property] = number

func _refresh() -> void:
	_district_toggle.set_pressed_no_signal(_library.use_district_percentages)
	for property in _sliders:
		var enabled := true
		if property in ["commercial_percent", "residential_percent", "industrial_percent"]:
			enabled = _library.use_district_percentages
		elif property == "lit_window_percent": enabled = not _library.use_district_percentages
		_sliders[property].set_value_no_signal(_library.get(property))
		_numbers[property].set_value_no_signal(_library.get(property))
		_sliders[property].editable = enabled
		_numbers[property].editable = enabled
		_sliders[property].get_parent().modulate.a = 1.0 if enabled else 0.45
	var has_clock := get_tree().get_first_node_in_group(&"day_night_cycle") != null
	_night_button.disabled = not has_clock
	_day_button.disabled = not has_clock

func _set_time(hours: float) -> void:
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null: clock.set_time(hours)

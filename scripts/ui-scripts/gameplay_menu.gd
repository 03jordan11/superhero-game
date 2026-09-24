extends CanvasLayer
## In-game notebook; owns its pause only while open. Gameplay data stays on Player.
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const PALETTE = preload("res://assets/ui/default_palette.tres")
const TAB_IDS := ["powers", "gear", "attributes", "journal", "map"]
var tabs: TabContainer
var powers_page: Control
var map_page: Control
var attribute_labels: Dictionary = {}
var attribute_notes: Dictionary = {}
var attribute_buttons: Dictionary = {}
var points_label: Label
var attribute_feedback: Label
var level_label: Label
var title_label: Label
var close_button: Button
var attribute_footer: Label
var player: PlayerCharacter
var _owns_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	add_to_group(&"gameplay_menu")
	player = get_parent().get_node_or_null("Player") as PlayerCharacter
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _box(PALETTE.background, PALETTE.border))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title_label = _label(32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	close_button = Button.new()
	close_button.custom_minimum_size = Vector2(180, 46)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_stylebox_override("normal", _box(PALETTE.surface_raised, PALETTE.border, 8))
	close_button.add_theme_stylebox_override("hover", _box(PALETTE.surface_selected, PALETTE.accent, 8))
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 25)
	tabs.add_theme_stylebox_override("panel", _box(PALETTE.surface, PALETTE.border))
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus"]:
		var box := _box(PALETTE.surface_selected if state == "tab_selected" else PALETTE.surface_raised, PALETTE.accent if state == "tab_selected" else PALETTE.border)
		box.content_margin_left = 28
		box.content_margin_right = 28
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		tabs.add_theme_stylebox_override(state, box)
	layout.add_child(tabs)
	powers_page = preload("res://scenes/ui/powers_page.tscn").instantiate()
	powers_page.embedded = true
	if player != null:
		powers_page.persistence = player.get_node("PlayerPowerController")
		powers_page.progression = powers_page.persistence.progression
	tabs.add_child(powers_page)
	powers_page.show()
	for id in ["gear", "attributes", "journal", "map"]:
		var page := Control.new()
		page.name = id.to_pascal_case()
		tabs.add_child(page)
		if id == "attributes": _build_attributes(page)
		if id == "map":
			map_page = preload("res://scripts/ui-scripts/region_map.gd").new()
			map_page.player = player
			map_page.city = get_parent().get_node_or_null("SuperCity")
			page.add_child(map_page)
			map_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_copy()
	if player != null:
		player.stats.stat_changed.connect(_on_stat_changed)
		player.stats.level_changed.connect(_on_level_changed)
		player.stats.experience_changed.connect(_on_experience_changed)
		player.stats.attribute_points_changed.connect(_on_points_changed)
	visibility_changed.connect(_refresh_attributes)
	hide()

func _input(event: InputEvent) -> void:
	if is_instance_valid(player) and player.is_dead: return
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	if bindings.is_capturing or DebugManager.developer_menu_open: return
	if not visible and get_tree().paused: return
	if bindings.is_action_press(event, "gameplay_menu"):
		if visible: close_menu()
		else: open_menu()
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("ui_cancel") or bindings.is_action_press(event, "pause")):
		close_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		tabs.current_tab = posmod(tabs.current_tab + (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1), TAB_IDS.size())
		tabs.get_tab_bar().grab_focus()
		get_viewport().set_input_as_handled()

func open_menu(selected_tab: int = -1) -> void:
	if is_instance_valid(player) and player.is_dead: return
	if visible or get_tree().paused: return
	if selected_tab >= 0: tabs.current_tab = clampi(selected_tab, 0, TAB_IDS.size() - 1)
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	map_page.reset_view()
	_refresh_copy()
	powers_page.refresh_page()
	tabs.get_tab_bar().grab_focus()

func close_menu() -> void:
	hide()
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_attributes(page: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
	page.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 24)
	scroll.add_child(column)
	level_label = _label(28)
	column.add_child(level_label)
	points_label = _label(24)
	column.add_child(points_label)
	for id in ["strength", "speed", "resilience"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(PALETTE.surface_raised, PALETTE.border, 22))
		column.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		var row := HBoxContainer.new()
		content.add_child(row)
		var value := _label(30)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value)
		attribute_labels[id] = value
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 46)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_upgrade_attribute.bind(id))
		row.add_child(button)
		attribute_buttons[id] = button
		var note := _label(22)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(note)
		attribute_notes[id] = note
	attribute_footer = _label(22)
	attribute_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(attribute_footer)
	attribute_feedback = _label(22)
	attribute_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(attribute_feedback)

func _upgrade_attribute(id: String) -> void:
	if player == null or not player.stats.upgrade_attribute(StringName(id)): return
	var saved: bool = get_node("/root/SaveManager").save_game()
	attribute_feedback.text = COPY.text("gameplay.attributes.upgraded" if saved else "powers.feedback.save_failed", {"attribute": COPY.text("gameplay.attribute." + id)})
	_refresh_attributes()
	if attribute_buttons[id].disabled: tabs.get_tab_bar().grab_focus()

func _refresh_attributes() -> void:
	if not visible or player == null: return
	for id in attribute_labels:
		var bonus: int = player.get_node("PlayerPowerController").attribute_bonus(id)
		attribute_labels[id].text = attribute_text(id, player.stats.get(id), bonus)
		attribute_buttons[id].disabled = not player.stats.can_upgrade_attribute(StringName(id))
	points_label.text = COPY.text("gameplay.attributes.points", {"points": player.stats.attribute_points})
	level_label.text = COPY.text("gameplay.progress", {"level": player.stats.level, "xp": player.stats.experience, "required": player.stats.get_experience_to_next_level()})

func attribute_text(id: String, base: int, bonus: int) -> String:
	var text := COPY.text("gameplay.attribute.value", {"attribute": COPY.text("gameplay.attribute." + id), "value": base + bonus})
	return text + (" " + COPY.text("gameplay.attribute.bonus", {"bonus": bonus}) if bonus > 0 else "")

func _refresh_copy() -> void:
	title_label.text = COPY.text("gameplay.title")
	close_button.text = COPY.text("gameplay.close")
	for i in TAB_IDS.size(): tabs.set_tab_title(i, COPY.text("gameplay.tab." + TAB_IDS[i]))
	for id in attribute_notes: attribute_notes[id].text = COPY.text("gameplay.attribute." + id + ".description")
	attribute_footer.text = COPY.text("gameplay.attributes.help")
	for id in attribute_buttons: attribute_buttons[id].text = COPY.text("gameplay.attributes.upgrade")
	_refresh_attributes()

func _on_stat_changed(_id: StringName, _value: int) -> void: _refresh_attributes()
func _on_level_changed(_value: int) -> void: _refresh_attributes()
func _on_points_changed(_value: int) -> void: _refresh_attributes()
func _on_experience_changed(_value: int, _required: int) -> void: _refresh_attributes()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(attribute_footer): _refresh_copy()

func _exit_tree() -> void:
	if _owns_pause: get_tree().paused = false

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PALETTE.text_primary)
	return label

func _box(fill: Color, border: Color, padding := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

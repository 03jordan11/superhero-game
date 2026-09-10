extends Control

signal back_requested

const PROGRESSION = preload("res://scripts/ui-scripts/power_menu_progression.gd")
const ICON = preload("res://scripts/ui-scripts/power_menu_icon.gd")
const PALETTE = preload("res://assets/ui/default_palette.tres")
const STRINGS = preload("res://scripts/ui-scripts/powers_text.gd")

var progression = PROGRESSION.new()
var persistence: Node
var embedded := false
var selected_id := "super_leap"
var power_buttons: Dictionary = {}
var card_titles: Dictionary = {}
var card_icons: Dictionary = {}
var localized_controls: Dictionary = {}
var feedback_key := ""
var card_pips: Dictionary = {}
var category_counts: Dictionary = {}
var token_label: Label
var title_label: Label
var category_label: Label
var description_label: Label
var detail_icon: Control
var upgrade_states: Array[Label] = []
var upgrade_names: Array[Label] = []
var upgrade_descriptions: Array[Label] = []
var implementation_label: Label
var detail_scroll: ScrollContainer
var upgrade_panels: Array[PanelContainer] = []
var action_button: Button
var feedback_label: Label
var back_button: Button


func _ready() -> void:
	add_to_group(&"powers_menu")
	_build_ui()
	progression.changed.connect(_refresh)
	_refresh()
	if not embedded: hide()


func open_page() -> void:
	show()
	feedback_key = ""
	_refresh()
	if detail_scroll != null: detail_scroll.scroll_vertical = 0
	power_buttons[selected_id].grab_focus()

func refresh_page() -> void:
	feedback_key = ""
	_refresh()


func select_power(id: String) -> void:
	if not PROGRESSION.POWERS.has(id): return
	selected_id = id
	feedback_key = ""
	_refresh()
	if detail_scroll != null: detail_scroll.scroll_vertical = 0


func _purchase_selected() -> void:
	var was_locked: bool = progression.level(selected_id) < 0
	if progression.purchase(selected_id):
		if action_button.disabled: power_buttons[selected_id].grab_focus()
		feedback_key = "powers.feedback.unlocked" if was_locked else "powers.feedback.upgraded"
		if persistence != null and not persistence.last_save_succeeded: feedback_key = "powers.feedback.save_failed"
		_refresh()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _style(PALETTE.background, PALETTE.background))
	add_child(background)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 24 if embedded else 56)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16 if embedded else 32)
	background.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12 if embedded else 22)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(_localized_label("powers.title", 48, PALETTE.text_primary))
	var wallet := PanelContainer.new()
	wallet.custom_minimum_size.x = 280
	wallet.add_theme_stylebox_override("panel", _style(PALETTE.surface, PALETTE.border, 8 if embedded else 20))
	header.add_child(wallet)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 22)
	wallet.add_child(wallet_row)
	wallet_row.add_child(_label("◆", 40, PALETTE.accent))
	var wallet_text := VBoxContainer.new()
	wallet_row.add_child(wallet_text)
	wallet_text.add_child(_localized_label("powers.tokens", 16, PALETTE.text_secondary))
	token_label = _label("0", 36, PALETTE.accent)
	wallet_text.add_child(token_label)
	layout.add_child(_rule())
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	if embedded:
		layout.add_child(body)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		layout.add_child(scroll)
		scroll.add_child(body)
	var categories := HBoxContainer.new()
	categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	categories.add_theme_constant_override("separation", 16)
	body.add_child(categories)
	for category in PROGRESSION.CATEGORIES:
		_build_category(categories, category)
	_build_details(body)
	layout.add_child(_rule())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	layout.add_child(footer)
	back_button = _button("", false)
	localized_controls[back_button] = {"key": "powers.back", "fields": {}}
	back_button.custom_minimum_size = Vector2(220, 52)
	back_button.pressed.connect(func(): back_requested.emit())
	footer.add_child(back_button)
	if embedded: footer.hide()


func _build_category(parent: HBoxContainer, category: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(PALETTE.background, PALETTE.border, 18))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_localized_label("powers.category." + category.to_lower(), 27, PALETTE.accent))
	var count := _label("", 16, PALETTE.text_secondary)
	column.add_child(count)
	category_counts[category] = count
	column.add_child(_rule())
	for id in PROGRESSION.POWERS:
		if PROGRESSION.POWERS[id].category == category:
			_build_card(column, id)


func _build_card(parent: VBoxContainer, id: String) -> void:
	var button := _button("", false)
	button.name = id.to_pascal_case()
	button.custom_minimum_size = Vector2(0, 152)
	button.size_flags_vertical = Control.SIZE_FILL
	button.pressed.connect(select_power.bind(id))
	button.focus_entered.connect(select_power.bind(id))
	parent.add_child(button)
	power_buttons[id] = button
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var icon := ICON.new()
	icon.power = id
	icon.custom_minimum_size = Vector2(62, 62)
	row.add_child(icon)
	card_icons[id] = icon
	var title := _label("", 23, PALETTE.text_primary)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(title)
	card_titles[id] = title
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 10)
	column.add_child(pips)
	card_pips[id] = []
	for i in int(PROGRESSION.POWERS[id].max_upgrades):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
		card_pips[id].append(pip)
	_ignore_mouse(margin)


func _build_details(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PALETTE.surface, PALETTE.owned_border, 20))
	if embedded:
		detail_scroll = ScrollContainer.new()
		detail_scroll.custom_minimum_size.x = 580
		detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		detail_scroll.follow_focus = true
		parent.add_child(detail_scroll)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_scroll.add_child(panel)
	else:
		panel.custom_minimum_size.x = 580
		parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	category_label = _label("", 16, PALETTE.accent)
	column.add_child(category_label)
	title_label = _label("", 38, PALETTE.text_primary)
	column.add_child(title_label)
	var art := PanelContainer.new()
	art.custom_minimum_size.y = 112
	art.add_theme_stylebox_override("panel", _style(PALETTE.surface_raised, PALETTE.border, 8))
	column.add_child(art)
	var center := CenterContainer.new()
	art.add_child(center)
	detail_icon = ICON.new()
	detail_icon.custom_minimum_size = Vector2(96, 96)
	center.add_child(detail_icon)
	description_label = _label("", 18, PALETTE.text_secondary)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.y = 78
	column.add_child(description_label)
	implementation_label = _label("", 16, PALETTE.accent_soft)
	implementation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(implementation_label)
	column.add_child(_rule())
	for i in 3:
		var upgrade := PanelContainer.new()
		upgrade.add_theme_stylebox_override("panel", _style(PALETTE.surface, PALETTE.border, 6))
		column.add_child(upgrade)
		upgrade_panels.append(upgrade)
		var upgrade_content := VBoxContainer.new()
		upgrade.add_child(upgrade_content)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		upgrade_content.add_child(row)
		row.add_child(_label("0%d" % (i + 1), 23, PALETTE.accent))
		var name_label := _label("", 20, PALETTE.text_primary)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_label)
		upgrade_names.append(name_label)
		var status := _label("", 14, PALETTE.text_secondary)
		row.add_child(status)
		upgrade_states.append(status)
		var copy := _label("", 18, PALETTE.text_secondary)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_content.add_child(copy)
		upgrade_descriptions.append(copy)
	var planned := _localized_label("powers.upgrade.planned_note", 16, PALETTE.text_secondary)
	planned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(planned)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	action_button = _button("", true)
	action_button.custom_minimum_size.y = 58
	action_button.pressed.connect(_purchase_selected)
	column.add_child(action_button)
	feedback_label = _label("", 16, PALETTE.accent)
	feedback_label.custom_minimum_size.y = 23
	column.add_child(feedback_label)


func _refresh() -> void:
	for control in localized_controls:
		var copy: Dictionary = localized_controls[control]
		control.text = STRINGS.text(copy.key, copy.fields)
	token_label.text = str(progression.tokens)
	for category in PROGRESSION.CATEGORIES:
		var owned := 0
		var total := 0
		for id in PROGRESSION.POWERS:
			if PROGRESSION.POWERS[id].category != category: continue
			total += 1
			if progression.level(id) >= 0: owned += 1
		category_counts[category].text = STRINGS.text("powers.category.count", {"owned": owned, "total": total})
	for id in power_buttons:
		var level: int = progression.level(id)
		var selected: bool = id == selected_id
		var owned := level >= 0
		var fill := PALETTE.surface_selected if owned else PALETTE.surface
		var border := PALETTE.owned_border if owned else PALETTE.border
		var style := _style(fill, PALETTE.accent if selected else border, 12)
		if selected: style.set_border_width_all(2)
		if owned:
			style.shadow_color = Color(PALETTE.accent, 0.12)
			style.shadow_size = 6
		power_buttons[id].add_theme_stylebox_override("normal", style)
		card_titles[id].text = STRINGS.power_name(id)
		card_titles[id].add_theme_color_override("font_color", PALETTE.text_primary if owned else PALETTE.locked_tint)
		card_icons[id].ink = PALETTE.accent_soft if owned else PALETTE.locked_tint
		card_icons[id].queue_redraw()
		for i in card_pips[id].size():
			var pip_style := _style(PALETTE.accent if level > i else Color(0, 0, 0, 0), PALETTE.accent if level > i else PALETTE.owned_border)
			pip_style.set_corner_radius_all(7)
			pip_style.set_border_width_all(2)
			card_pips[id][i].add_theme_stylebox_override("panel", pip_style)
	var data: Dictionary = PROGRESSION.POWERS[selected_id]
	var level: int = progression.level(selected_id)
	category_label.text = STRINGS.text("powers.category." + String(data.category).to_lower())
	title_label.text = STRINGS.power_name(selected_id)
	detail_icon.power = selected_id
	detail_icon.queue_redraw()
	description_label.text = STRINGS.text("power." + selected_id + ".description")
	implementation_label.text = STRINGS.text("power." + selected_id + ".current")
	for i in upgrade_states.size():
		upgrade_names[i].text = STRINGS.text("power." + selected_id + ".upgrade." + str(i + 1) + ".name")
		upgrade_descriptions[i].text = STRINGS.text("power." + selected_id + ".upgrade." + str(i + 1) + ".description")
		upgrade_states[i].text = STRINGS.text("powers.upgrade.unlocked" if level > i else ("powers.upgrade.next" if level == i else "powers.upgrade.locked"))
		if not progression.is_implemented(selected_id, i + 1): upgrade_states[i].text += "\n" + STRINGS.text("powers.effect.planned")
		upgrade_states[i].add_theme_color_override("font_color", PALETTE.accent if level >= i else PALETTE.text_secondary)
		upgrade_panels[i].add_theme_stylebox_override("panel", _style(PALETTE.surface_selected if level > i else PALETTE.surface, PALETTE.owned_border if level >= i else PALETTE.border, 6))
	var reason: String = progression.blocked_reason(selected_id)
	action_button.disabled = not reason.is_empty()
	if level >= int(data.max_upgrades):
		action_button.text = STRINGS.text("powers.action.maxed")
	else:
		action_button.text = reason if not reason.is_empty() else (STRINGS.text("powers.action.unlock", {"power": STRINGS.power_name(selected_id)}) if level < 0 else STRINGS.text("powers.action.upgrade", {"number": level + 1}))
	feedback_label.text = "" if feedback_key.is_empty() else STRINGS.text(feedback_key, {"power": STRINGS.power_name(selected_id)})


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(feedback_label):
		_refresh()


func _localized_label(key: String, font_size: int, color: Color, fields: Dictionary = {}) -> Label:
	var label := _label("", font_size, color)
	localized_controls[label] = {"key": key, "fields": fields}
	return label


func _style(fill: Color, border: Color, padding := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", PALETTE.text_on_accent if primary else PALETTE.text_primary)
	button.add_theme_color_override("font_hover_color", PALETTE.text_on_accent if primary else PALETTE.text_primary)
	button.add_theme_color_override("font_pressed_color", PALETTE.text_primary)
	button.add_theme_color_override("font_disabled_color", PALETTE.text_secondary)
	button.add_theme_stylebox_override("normal", _style(PALETTE.accent if primary else PALETTE.surface, PALETTE.accent if primary else PALETTE.border, 12))
	button.add_theme_stylebox_override("hover", _style(PALETTE.accent_soft if primary else PALETTE.surface_raised, PALETTE.accent, 12))
	button.add_theme_stylebox_override("pressed", _style(PALETTE.surface_selected, PALETTE.accent, 12))
	button.add_theme_stylebox_override("disabled", _style(PALETTE.surface_raised, PALETTE.border, 12))
	var focus := _style(Color(0, 0, 0, 0), PALETTE.focus)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = PALETTE.border
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control: _ignore_mouse(child)

extends VBoxContainer
## Shared by main-menu and paused settings. The binding service owns input capture.
signal status_changed(copy: String)
const BINDINGS = preload("res://scripts/input_bindings.gd")
var buttons := {"keyboard": {}, "controller": {}}
var _action := ""
var _device := ""
var _origin: Button
var _message: Label
var _dialog: CanvasLayer
var _prompt: Label
@onready var settings: Node = get_node("/root/GameSettings")
@onready var bindings: Node = settings.input_bindings

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_note("Select a binding, then press a key, mouse button, Xbox button, or trigger. Used bindings swap actions. Dodge Roll and Descend may share a control. Sticks are fixed.")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for title in ["Action", "Keyboard / Mouse", "Xbox Controller"]:
		var label := _label(title)
		grid.add_child(label)
	for action in BINDINGS.ACTIONS:
		var label := _label(bindings.action_label(action))
		label.custom_minimum_size.x = 320
		grid.add_child(label)
		for device in buttons:
			if not bindings.bindings[device].has(action):
				grid.add_child(_label("Left Stick (fixed)"))
				continue
			var button := Button.new()
			button.custom_minimum_size = Vector2(220, 42)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 21)
			button.pressed.connect(start_capture.bind(action, device))
			grid.add_child(button)
			buttons[device][action] = button
	for copy in ["Camera Look", "Mouse (fixed)", "Right Stick (fixed)"]:
		grid.add_child(_label(copy))
	_note("Menus: D-pad to navigate, A to select, B to go back. LB / RB switch tabs. Escape also goes back. Menu controls stay fixed so you can always edit your bindings.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for device in buttons:
		var button := Button.new()
		button.text = "Reset Keyboard / Mouse" if device == "keyboard" else "Reset Xbox Controls"
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(_reset.bind(device))
		row.add_child(button)
	_message = _note("Single keys and buttons; hold/release actions also support LT and RT. Sprint Hold / Toggle is in Gameplay.")
	_dialog = CanvasLayer.new()
	_dialog.layer = 100
	add_child(_dialog)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.06, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	_prompt = _label("")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	center.add_child(_prompt)
	_dialog.hide()
	bindings.changed.connect(refresh)
	bindings.capture_finished.connect(_finish_capture)
	visibility_changed.connect(_on_visibility_changed)
	refresh()

func _label(copy: String) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", 21)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _note(copy: String) -> Label:
	var label := _label(copy)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	return label

func refresh() -> void:
	for device in buttons:
		for action in buttons[device]:
			buttons[device][action].text = bindings.label_for(action, device)
	if is_instance_valid(_message): _message.text = "Bindings updated."

func start_capture(action: String, device: String) -> void:
	_action = action
	_device = device
	_origin = buttons[device][action]
	_prompt.text = "%s\n\nPress %s.\n\nEscape cancels. Automatically cancels after 15 seconds.\nRelease a held trigger before assigning it." % [bindings.action_label(action), "a keyboard key or mouse button" if device == "keyboard" else "an Xbox button or trigger"]
	_dialog.show()
	bindings.begin_capture(device)

func _finish_capture(event: InputEvent) -> void:
	if _action.is_empty(): return
	_dialog.hide()
	if event != null:
		var result: String = bindings.rebind(_action, _device, event)
		_message.text = result + (" Saved." if settings.save_settings() == OK else " Applied, but could not save settings.")
	else:
		_message.text = "Binding canceled."
	status_changed.emit(_message.text)
	_action = ""
	if is_instance_valid(_origin) and _origin.is_visible_in_tree(): _origin.grab_focus()

func _reset(device: String) -> void:
	bindings.reset_device(device)
	_message.text = "Defaults restored." if settings.save_settings() == OK else "Defaults applied, but could not save settings."
	status_changed.emit(_message.text)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and not _action.is_empty(): bindings.cancel_capture()

func _exit_tree() -> void:
	if not _action.is_empty() and is_instance_valid(bindings): bindings.cancel_capture()

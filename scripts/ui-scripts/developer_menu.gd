extends CanvasLayer
## Paused, debug-build-only console. Game operations live in developer_commands.gd.
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const PALETTE = preload("res://assets/ui/default_palette.tres")
const COMMANDS = preload("res://scripts/ui-scripts/developer_commands.gd")
const MAX_HISTORY := 100
const MAX_OUTPUT_LINES := 300
var commands: RefCounted
var command_input: LineEdit
var output: RichTextLabel
var title_label: Label
var hint_label: Label
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _owns_pause := false
var _history: Array[String] = []
var _history_index := 0
var _draft := ""
var _output_lines: PackedStringArray = []
var _completion_matches: Array[String] = []
var _completion_index := -1
var _last_completion := ""

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	commands = COMMANDS.new(get_parent().get_node("Player"))
	_build_ui()
	_refresh_copy()
	_append_output(COPY.text("console.welcome"))
	hide()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "Console"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 0.55
	panel.anchor_bottom = 0.6
	panel.offset_left = 0
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = 0
	var box := StyleBoxFlat.new()
	box.bg_color = PALETTE.background
	box.border_color = PALETTE.owned_border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: box.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", PALETTE.accent)
	column.add_child(title_label)
	output = RichTextLabel.new()
	output.name = "Output"
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.scroll_following = true
	output.selection_enabled = true
	output.bbcode_enabled = false
	output.focus_mode = Control.FOCUS_NONE
	output.add_theme_font_size_override("normal_font_size", 24)
	output.add_theme_color_override("default_color", PALETTE.text_primary)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	output.add_theme_font_override("normal_font", mono)
	column.add_child(output)
	var row := HBoxContainer.new()
	column.add_child(row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_color_override("font_color", PALETTE.accent)
	prompt.add_theme_font_size_override("font_size", 24)
	row.add_child(prompt)
	command_input = LineEdit.new()
	command_input.name = "Command"
	command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_input.custom_minimum_size.y = 46
	command_input.max_length = 256
	command_input.add_theme_font_override("font", mono)
	command_input.add_theme_font_size_override("font_size", 24)
	command_input.text_submitted.connect(_submit)
	command_input.gui_input.connect(_command_gui_input)
	row.add_child(command_input)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", PALETTE.text_secondary)
	column.add_child(hint_label)

func _input(event: InputEvent) -> void:
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	if bindings.is_capturing: return
	if visible:
		if bindings.is_action_press(event, "toggle_debug") or bindings.is_action_press(event, "pause") or event.is_action_pressed("ui_cancel"):
			_set_menu_open(false)
			get_viewport().set_input_as_handled()
	elif not get_tree().paused and bindings.is_action_press(event, "toggle_debug"):
		_set_menu_open(true)
		get_viewport().set_input_as_handled()

func _set_menu_open(is_open: bool) -> void:
	if is_open == visible: return
	if is_open:
		if get_tree().paused: return
		previous_mouse_mode = Input.mouse_mode
		_owns_pause = true
		DebugManager.developer_menu_open = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show()
		command_input.grab_focus()
	else:
		hide()
		DebugManager.developer_menu_open = false
		if _owns_pause:
			get_tree().paused = false
			_owns_pause = false
			Input.mouse_mode = previous_mouse_mode

func _submit(line: String) -> void:
	var clean := line.strip_edges()
	if clean.is_empty(): return
	if _history.is_empty() or _history.back() != clean: _history.append(clean)
	if _history.size() > MAX_HISTORY: _history.pop_front()
	_history_index = _history.size()
	_draft = ""
	_completion_matches.clear()
	command_input.clear()
	if clean.to_lower() == "clear":
		_output_lines.clear()
		output.text = ""
		return
	_append_output("> " + clean)
	_append_output(commands.execute(clean))

func _append_output(message: String) -> void:
	if message.is_empty(): return
	_output_lines.append_array(message.split("\n"))
	if _output_lines.size() > MAX_OUTPUT_LINES:
		_output_lines = _output_lines.slice(_output_lines.size() - MAX_OUTPUT_LINES)
	output.text = "\n".join(_output_lines)

func _command_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
		_recall(-1 if event.keycode == KEY_UP else 1)
		command_input.accept_event()
	elif event.keycode == KEY_TAB:
		_complete()
		command_input.accept_event()

func _recall(direction: int) -> void:
	if _history.is_empty(): return
	if _history_index == _history.size(): _draft = command_input.text
	_history_index = clampi(_history_index + direction, 0, _history.size())
	command_input.text = _draft if _history_index == _history.size() else _history[_history_index]
	command_input.caret_column = command_input.text.length()
	_completion_matches.clear()

func _complete() -> void:
	var prefix := command_input.text.to_lower()
	if _completion_matches.is_empty() or prefix != _last_completion:
		_completion_matches.clear()
		for completion in COMMANDS.COMPLETIONS:
			if completion.begins_with(prefix): _completion_matches.append(completion)
		_completion_index = -1
	if _completion_matches.is_empty(): return
	_completion_index = (_completion_index + 1) % _completion_matches.size()
	_last_completion = _completion_matches[_completion_index]
	command_input.text = _last_completion
	command_input.caret_column = command_input.text.length()

func _refresh_copy() -> void:
	title_label.text = COPY.text("console.title")
	command_input.placeholder_text = COPY.text("console.placeholder")
	hint_label.text = COPY.text("console.hint")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(title_label): _refresh_copy()

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
		DebugManager.developer_menu_open = false
		Input.mouse_mode = previous_mouse_mode

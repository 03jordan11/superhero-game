extends Node
## One keyboard/mouse and one Xbox binding per action. Sticks remain fixed.
signal changed
signal device_changed
signal capture_finished(event: InputEvent)
signal controller_disconnected
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")

const ACTIONS := {
	"move_forward": ["Move Forward", KEY_W, -1],
	"move_backward": ["Move Backward", KEY_S, -1],
	"move_left": ["Move Left", KEY_A, -1],
	"move_right": ["Move Right", KEY_D, -1],
	"jump": ["Jump / Charge Jump / Ascend", KEY_SPACE, JOY_BUTTON_A],
	"sprint": ["Sprint / Boost", KEY_SHIFT, JOY_BUTTON_LEFT_STICK],
	"toggle_flight": ["Toggle Flight", KEY_F, JOY_BUTTON_Y],
	"attack": ["Attack / Air Slam / Active Power", -MOUSE_BUTTON_LEFT, JOY_BUTTON_X],
	"flight_descend": ["Descend", KEY_CTRL, JOY_BUTTON_B],
	"pick_up_vehicle": ["Pick Up / Charge Throw / Drop", KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
	"pause": ["Pause", KEY_ESCAPE, JOY_BUTTON_START],
	"toggle_debug": ["Developer Console", KEY_QUOTELEFT, JOY_BUTTON_BACK],
	"gameplay_menu": ["controls.gameplay_menu", KEY_P, JOY_BUTTON_RIGHT_STICK],
	"aim_power": ["Aim / Zoom", -MOUSE_BUTTON_RIGHT, -1],
	"secondary_power": ["Dragon Breath (Hold While Aiming)", KEY_Q, -1],
	"power_selector": ["Power Selector (Hold)", KEY_ALT, JOY_BUTTON_LEFT_SHOULDER],
	"lock_target": ["Lock On / Next Enemy (Hold to Release)", KEY_TAB, JOY_BUTTON_DPAD_LEFT],
}
const BINDING_VERSION := 3
const PREVIOUS_KEYBOARD_DEFAULTS := {"pick_up_vehicle": KEY_R, "secondary_power": KEY_E}
const STICKS := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_backward": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}
const XBOX_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3 (LS Click)",
	JOY_BUTTON_RIGHT_STICK: "R3 (RS Click)", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right"}
const MENU_BUTTONS := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
	"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN,
	"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
var bindings := {"keyboard": {}, "controller": {}}
var active_device := "keyboard"
var is_capturing := false
var capture_device := ""
var _capture_timer: Timer
var _blocked_triggers: Dictionary = {}
var _trigger_pressed: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.ignore_joypad_on_unfocused_application = true
	_capture_timer = Timer.new()
	_capture_timer.one_shot = true
	_capture_timer.wait_time = 15.0
	add_child(_capture_timer)
	_capture_timer.timeout.connect(cancel_capture)
	Input.joy_connection_changed.connect(_on_connection_changed)
	# Declare these explicitly: project/script launches may have keyboard-only UI defaults.
	for action in MENU_BUTTONS:
		var event := make_event({"kind": "button", "code": MENU_BUTTONS[action]})
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	load_config(ConfigFile.new())

func defaults(device: String) -> Dictionary:
	var result := {}
	for action in ACTIONS:
		if device == "controller" and action in ["aim_power", "secondary_power"]:
			result[action] = {"kind": "trigger", "code": JOY_AXIS_TRIGGER_LEFT if action == "aim_power" else JOY_AXIS_TRIGGER_RIGHT}
			continue
		var code: int = ACTIONS[action][1 if device == "keyboard" else 2]
		if device == "controller" and code < 0: continue
		result[action] = {"kind": "button" if device == "controller" else ("key" if code > 0 else "mouse"), "code": absi(code)}
	return result

func load_config(config: ConfigFile) -> void:
	for device in bindings:
		var candidate := defaults(device)
		var valid := true
		var used: Array = []
		var migrated_actions: Array[String] = []
		if device == "keyboard" and int(config.get_value("bindings", "version", 0)) < 2:
			for action in PREVIOUS_KEYBOARD_DEFAULTS:
				if config.get_value("bindings_keyboard", action, {}) == {"kind": "key", "code": PREVIOUS_KEYBOARD_DEFAULTS[action]}:
					migrated_actions.append(action)
		if device == "keyboard" and int(config.get_value("bindings", "version", 0)) < 3:
			for action in {"lock_target": KEY_CAPSLOCK, "gameplay_menu": KEY_TAB}:
				var old_code: int=KEY_CAPSLOCK if action=="lock_target" else KEY_TAB
				if config.get_value("bindings_keyboard",action,{})=={"kind":"key","code":old_code}:
					migrated_actions.append(action)
		# Read saved assignments first; a new action must not reset older custom bindings.
		for action in candidate:
			if action in migrated_actions: continue
			if not config.has_section_key("bindings_" + device, action): continue
			var value: Variant = config.get_value("bindings_" + device, action, candidate[action])
			if not _valid_binding(value, device) or value in used:
				valid = false
				break
			candidate[action] = value
			used.append(value)
		if valid:
			for action in candidate:
				if config.has_section_key("bindings_" + device, action) and action not in migrated_actions: continue
				if candidate[action] in used:
					candidate[action] = _unused_binding(device, used)
				used.append(candidate[action])
		bindings[device] = candidate if valid else defaults(device)
	_apply()

func _unused_binding(device: String, used: Array) -> Dictionary:
	var codes: Array = XBOX_NAMES.keys() if device == "controller" else [KEY_I, KEY_M, KEY_P, KEY_O, KEY_U, KEY_J, KEY_K, KEY_L]
	if device == "keyboard": codes.append_array(range(KEY_A, KEY_Z + 1))
	for code in codes:
		var value := {"kind": "button" if device == "controller" else "key", "code": code}
		if value not in used: return value
	return {"kind": "trigger", "code": JOY_AXIS_TRIGGER_LEFT}

func action_label(action: String) -> String:
	return COPY.text(ACTIONS[action][0]) if action == "gameplay_menu" else ACTIONS[action][0]

func write_config(config: ConfigFile) -> void:
	config.set_value("bindings", "version", BINDING_VERSION)
	for device in bindings:
		for action in bindings[device]:
			config.set_value("bindings_" + device, action, bindings[device][action])

func reset_device(device: String) -> void:
	if not bindings.has(device): return
	bindings[device] = defaults(device)
	_apply()

func rebind(action: String, device: String, event: InputEvent) -> String:
	if not bindings.has(device) or not bindings[device].has(action): return "This control is fixed."
	var value := describe_event(event)
	if not _valid_binding(value, device): return "Choose a key, mouse button, Xbox button, or trigger."
	var swapped := ""
	for other in bindings[device]:
		if other != action and bindings[device][other] == value:
			bindings[device][other] = bindings[device][action].duplicate()
			swapped = " Swapped with %s." % action_label(other)
			break
	bindings[device][action] = value
	_apply()
	return "%s: %s.%s" % [action_label(action), event_label(make_event(value)), swapped]

func _apply() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, 0.2 if STICKS.has(action) else 0.5)
		for device in bindings:
			if bindings[device].has(action): InputMap.action_add_event(action, make_event(bindings[device][action]))
	for action in STICKS:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
		if action.begins_with("look_"): InputMap.action_erase_events(action)
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = STICKS[action][0]
		event.axis_value = STICKS[action][1]
		InputMap.action_add_event(action, event)
	_trigger_pressed.clear()
	changed.emit()

func _valid_binding(value: Variant, device: String) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.has("kind") or not value.has("code") or not value.code is int: return false
	if device == "keyboard":
		return (value.kind == "key" and value.code > 0 and value.code < KEY_UNKNOWN) or (value.kind == "mouse" and value.code in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2])
	return (value.kind == "button" and XBOX_NAMES.has(value.code)) or (value.kind == "trigger" and value.code in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT])

static func describe_event(event: InputEvent) -> Dictionary:
	# Single physical keys (including Shift/Ctrl), without modifier chords.
	if event is InputEventKey: return {"kind": "key", "code": int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)}
	if event is InputEventMouseButton: return {"kind": "mouse", "code": int(event.button_index)}
	if event is InputEventJoypadButton: return {"kind": "button", "code": int(event.button_index)}
	if event is InputEventJoypadMotion and event.axis_value > 0.0: return {"kind": "trigger", "code": int(event.axis)}
	return {}

static func make_event(value: Dictionary) -> InputEvent:
	var event: InputEvent
	match value.kind:
		"key":
			event = InputEventKey.new()
			event.physical_keycode = value.code
		"mouse":
			event = InputEventMouseButton.new()
			event.button_index = value.code
		"button":
			event = InputEventJoypadButton.new()
			event.button_index = value.code
		"trigger":
			event = InputEventJoypadMotion.new()
			event.axis = value.code
			event.axis_value = 1.0
	event.device = -1
	return event

static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event.duplicate()
		if key.physical_keycode != 0:
			var mapped: int = key.physical_keycode
			if DisplayServer.get_name() != "headless": mapped = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
			key.keycode = mapped if mapped != 0 else key.physical_keycode
			key.physical_keycode = 0
		return OS.get_keycode_string(key.get_keycode_with_modifiers())
	if event is InputEventMouseButton:
		return {1: "Left Mouse", 2: "Right Mouse", 3: "Middle Mouse", 8: "Mouse 4", 9: "Mouse 5"}.get(event.button_index, event.as_text())
	if event is InputEventJoypadButton: return XBOX_NAMES.get(event.button_index, "Xbox Button")
	if event is InputEventJoypadMotion: return "LT" if event.axis == JOY_AXIS_TRIGGER_LEFT else "RT"
	return "Unbound"

func label_for(action: String, device: String) -> String:
	if not bindings[device].has(action): return "Left Stick (fixed)"
	return event_label(make_event(bindings[device][action]))

func begin_capture(device: String) -> void:
	if not bindings.has(device): return
	is_capturing = true
	capture_device = device
	_blocked_triggers.clear()
	for joy in Input.get_connected_joypads():
		for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			if Input.get_joy_axis(joy, axis) > 0.2: _blocked_triggers[Vector2i(joy, axis)] = true
	_capture_timer.start()

func cancel_capture() -> void:
	if is_capturing: _finish_capture(null)

func _finish_capture(event: InputEvent) -> void:
	is_capturing = false
	_capture_timer.stop()
	capture_finished.emit(event)

func _input(event: InputEvent) -> void:
	if is_capturing:
		if event is InputEventMouseMotion: return
		get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
			cancel_capture()
			return
		if event is InputEventJoypadMotion:
			var axis_key := Vector2i(event.device, event.axis)
			if event.axis_value < 0.2: _blocked_triggers.erase(axis_key)
			if event.axis_value < 0.65 or _blocked_triggers.has(axis_key): return
		elif not event.is_pressed() or event.is_echo(): return
		if _valid_binding(describe_event(event), capture_device): _finish_capture(event)
		return
	var device := active_device
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		device = "controller"
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		device = "keyboard"
	if device != active_device:
		active_device = device
		device_changed.emit()

func is_bound_control_held(action: StringName) -> bool:
	# Check controls independently of the cached action state. In Godot 4.7.2
	# on Windows, Shift's action can remain pressed after the key is released:
	# https://github.com/godotengine/godot/issues/122728
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey:
			if binding.physical_keycode != 0:
				if Input.is_physical_key_pressed(binding.physical_keycode): return true
			elif Input.is_key_pressed(binding.keycode): return true
		elif binding is InputEventMouseButton:
			if Input.is_mouse_button_pressed(binding.button_index): return true
		elif binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
			var devices: Array = Input.get_connected_joypads() if binding.device < 0 else [int(binding.device)]
			for device in devices:
				if binding is InputEventJoypadButton:
					if Input.is_joy_button_pressed(device, binding.button_index): return true
				elif Input.get_joy_axis(device, binding.axis) * binding.axis_value > InputMap.action_get_deadzone(action):
					return true
	return false

func is_action_press(event: InputEvent, action: String) -> bool:
	# Triggers send repeated motion events while squeezed. Fire once per squeeze.
	if event is InputEventJoypadMotion:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventJoypadMotion and binding.axis == event.axis:
				var key := "%s:%d:%d" % [action, event.device, event.axis]
				var pressed: bool = event.axis_value * binding.axis_value > InputMap.action_get_deadzone(action)
				var was_pressed: bool = _trigger_pressed.get(key, false)
				_trigger_pressed[key] = pressed
				return pressed and not was_pressed
		return false
	return event.is_action_pressed(action) and not event.is_echo()

func _on_connection_changed(_device: int, connected: bool) -> void:
	if connected: return
	cancel_capture()
	_trigger_pressed.clear()
	controller_disconnected.emit()
	if Input.get_connected_joypads().is_empty():
		active_device = "keyboard"
		device_changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_capture()

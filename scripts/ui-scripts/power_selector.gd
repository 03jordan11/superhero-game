extends Control
## Hold to choose; the center preserves the equipped power on release.
const ICON = preload("res://scripts/ui-scripts/power_menu_icon.gd")
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const IDS: Array[StringName] = [&"laser_eyes", &"ice", &"fire", &"electricity"]
const COLORS := [Color("ff758d"), Color("7cdfff"), Color("ffb463"), Color("d1a0ff")]
@export_range(30.0, 100.0, 1.0) var deadzone_radius := 76.0
var highlighted := -1
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _controller := false
var _icons: Array[Control] = []
@onready var player: PlayerCharacter = get_parent().get_parent()
@onready var powers: Node = player.get_node("PlayerPowerController")
@onready var bindings: Node = get_node("/root/GameSettings").input_bindings

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	for id in IDS:
		var icon := Control.new()
		icon.set_script(ICON)
		icon.power = String(id)
		add_child(icon)
		_icons.append(icon)
	resized.connect(_layout)
	bindings.changed.connect(cancel)
	bindings.controller_disconnected.connect(cancel)
	player.get_node("PlayerStateMachine/DeadState").death_started.connect(cancel)
	_layout()

func _scale_factor() -> float:
	return minf(1.0, minf(size.x / 700.0, size.y / 680.0))

func _layout() -> void:
	var scale_factor := _scale_factor()
	for i in _icons.size():
		var direction := Vector2.UP.rotated(i * PI / 2.0)
		_icons[i].position = size * 0.5 + (direction * 165.0 - Vector2(26, 45)) * scale_factor
		_icons[i].size = Vector2(52, 52) * scale_factor
		_icons[i].ink = COLORS[i]
		_icons[i].queue_redraw()
	queue_redraw()

func _blocked() -> bool:
	return get_tree().paused or DebugManager.developer_menu_open or bindings.is_capturing or player.is_dead or player.is_knocked_out

func open(controller := false) -> void:
	if visible or _blocked(): return
	_controller = controller
	highlighted = -1
	_previous_mouse_mode = Input.mouse_mode
	player.input_controller.reset()
	if player.is_charging_jump:
		player.state_machine.transition_to(&"GroundedState" if player.is_on_floor() else &"AirborneState")
	player.jump_hold_time = 0.0
	player.vehicle_interactor.cancel_throw_charge()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not controller: get_viewport().warp_mouse(size * 0.5)
	queue_redraw()

func close(confirm: bool) -> void:
	if not visible: return
	if confirm and highlighted >= 0: powers.select_active_power(IDS[highlighted])
	hide()
	player.input_controller.reset()
	# Other menus own their cursor while paused.
	if not get_tree().paused and not DebugManager.developer_menu_open:
		Input.mouse_mode = _previous_mouse_mode

func cancel() -> void:
	close(false)

func choose_direction(offset: Vector2) -> void:
	var next := -1
	if offset.length() >= deadzone_radius:
		next = posmod(roundi((offset.angle() + PI / 2.0) / (PI / 2.0)), 4)
	if next != highlighted:
		highlighted = next
		queue_redraw()

func _input(event: InputEvent) -> void:
	# Godot maps both Alt keys to KEY_ALT; reserve only the left key by default.
	if event is InputEventKey and event.physical_keycode == KEY_ALT and event.location == KEY_LOCATION_RIGHT: return
	if visible and _blocked(): cancel()
	if _blocked(): return
	if event.is_action_pressed("power_selector") and not event.is_echo():
		open(event is InputEventJoypadButton or event is InputEventJoypadMotion)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_released("power_selector"):
		close(true)
		get_viewport().set_input_as_handled()
	elif visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			cancel()
		elif event.is_action_pressed("gameplay_menu") or event.is_action_pressed("toggle_debug"):
			cancel()
			return # Allow the requested menu to open normally.
		elif event is InputEventMouseMotion:
			_controller = false
			choose_direction((event.position - size * 0.5) / maxf(_scale_factor(), 0.01))
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible: return
	if _blocked():
		cancel()
		return
	if _controller:
		var direction := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.3)
		choose_direction(direction * 250.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		cancel()
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.018, 0.036, 0.65))
	var factor := _scale_factor()
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * factor)
	for i in 4:
		var start := -PI * 0.75 + i * PI / 2.0 + 0.025
		var end := start + PI / 2.0 - 0.05
		var polygon := PackedVector2Array()
		for step in 33: polygon.append(Vector2.from_angle(lerpf(start, end, step / 32.0)) * 245.0)
		for step in 33: polygon.append(Vector2.from_angle(lerpf(end, start, step / 32.0)) * 91.0)
		var fill := Color("142938") if highlighted != i else Color("294757")
		draw_colored_polygon(polygon, fill)
		draw_arc(Vector2.ZERO, 245.0, start, end, 48, Color(COLORS[i], 0.95 if highlighted == i else 0.35), 3.0, true)
		if powers.active_power == IDS[i]:
			draw_arc(Vector2.ZERO, 96.0, start + 0.2, end - 0.2, 32, COLORS[i], 4.0, true)
		var position_on_ring := Vector2.UP.rotated(i * PI / 2.0) * 165.0
		_text(COPY.text("selector." + String(IDS[i])), position_on_ring + Vector2(0, 32), 19, Color("e8f2fa"))
		var status := "selector.future" if not powers.progression.is_implemented(String(IDS[i]), 0) else ("selector.ready" if player.abilities.is_unlocked(IDS[i]) else "selector.locked")
		_text(COPY.text(status), position_on_ring + Vector2(0, 52), 12, Color("a1b5c5"))
	draw_circle(Vector2.ZERO, 77.0, Color("0b1928"))
	draw_arc(Vector2.ZERO, 77.0, 0.0, TAU, 64, Color("41647a"), 1.0, true)
	_text(COPY.text("selector.title"), Vector2(0, -292), 25, Color("eef8ff"))
	_text(COPY.text("selector.choose" if highlighted < 0 else "selector.equip"), Vector2(0, -5), 14, Color("91abc0"))
	var center_name := COPY.text("selector." + String(powers.active_power if highlighted < 0 else IDS[highlighted]))
	_text(center_name, Vector2(0, 19), 17, Color("edf8ff"))
	var device := "controller" if _controller else "keyboard"
	_text(COPY.text("selector.release", {"key": bindings.label_for("power_selector", device)}), Vector2(0, 294), 17, Color("dcebf7"))
	_text(COPY.text("selector.cancel"), Vector2(0, 320), 13, Color("91abc0"))

func _text(value: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

extends CanvasLayer
## Event-driven HUD with optional contextual health and progression visibility.
const PALETTE = preload("res://assets/ui/default_palette.tres")
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")

@onready var health_bar: ProgressBar = $Health/Values/Bar
@onready var health_label: Label = $Health/Values/Amount
@onready var level_label: Label = $Progression/Level
@onready var experience_bar: ProgressBar = $Progression/Bar
@onready var experience_label: Label = $Progression/Amount
@onready var stamina_bar: ProgressBar = $Stamina/Bar
@onready var stamina_label: Label = $Stamina/Amount
var player: PlayerCharacter
const HINTS := {"jump": "hud.hint.jump", "toggle_flight": "hud.hint.flight", "sprint": "hud.hint.sprint"}
var hint_keys: Dictionary = {}
var hint_labels: Dictionary = {}
var hints_elapsed := 0.0
var settings: Node
var _health_recent: Timer
var _experience_recent: Timer
var _last_health := -1.0
var _last_max_health := -1.0

func _ready() -> void:
	_apply_palette()
	_build_hints()
	settings = get_node("/root/GameSettings")
	settings.input_bindings.changed.connect(refresh_key_hints)
	settings.input_bindings.device_changed.connect(refresh_key_hints)
	settings.control_hints_changed.connect(_refresh_hint_visibility)
	settings.gameplay_settings_changed.connect(_refresh_status_visibility)
	_health_recent = _recent_timer()
	_experience_recent = _recent_timer()
	_refresh_hint_visibility()
	player = get_parent() as PlayerCharacter
	if player.is_node_ready():
		_bind_player()
	else:
		# Player initializes its damage receiver in its own _ready, after children.
		player.ready.connect(_bind_player, CONNECT_ONE_SHOT)

func _bind_player() -> void:
	player.damage_receiver.health_changed.connect(_on_health_changed)
	player.stats.experience_changed.connect(_on_experience_changed)
	player.stats.level_changed.connect(_on_level_changed)
	player.stamina.changed.connect(_on_stamina_changed)
	_refresh()

func _refresh() -> void:
	_on_health_changed(player.get_current_health(), player.get_max_health())
	_on_stamina_changed(player.stamina.current, player.stamina.maximum, player.stamina.exhausted)
	_refresh_progression()
	refresh_key_hints()

func _on_health_changed(current: float, maximum: float) -> void:
	if _last_health >= 0.0 and (not is_equal_approx(current, _last_health) or not is_equal_approx(maximum, _last_max_health)):
		_health_recent.start()
	_last_health = current
	_last_max_health = maximum
	health_bar.max_value = maxf(maximum, 1.0)
	health_bar.value = clampf(current, 0.0, health_bar.max_value)
	health_label.text = COPY.text("hud.health", {"current": roundi(current), "max": roundi(maximum)})
	_refresh_status_visibility()

func _on_experience_changed(_current: int, _required: int) -> void:
	_experience_recent.start()
	_refresh_progression()

func _on_stamina_changed(current: float, maximum: float, exhausted: bool) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = COPY.text("hud.stamina.exhausted" if exhausted else "hud.stamina", {"current": ceili(current), "max": roundi(maximum)})
	_refresh_status_visibility()

func _on_level_changed(_level: int) -> void:
	_experience_recent.start()
	_refresh_progression()

func _refresh_progression() -> void:
	var required := player.stats.get_experience_to_next_level()
	experience_bar.max_value = required
	experience_bar.value = clampi(player.stats.experience, 0, required)
	level_label.text = COPY.text("hud.level", {"level": player.stats.level})
	experience_label.text = COPY.text("hud.experience", {"current": player.stats.experience, "max": required})
	_refresh_status_visibility()

func _recent_timer() -> Timer:
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_refresh_status_visibility)
	return timer

func _refresh_status_visibility() -> void:
	if _health_recent == null or _experience_recent == null: return
	$Health.visible = settings.always_show_health or _last_health < _last_max_health or not _health_recent.is_stopped()
	$Progression.visible = settings.always_show_experience or not _experience_recent.is_stopped()
	$Stamina.visible = settings.always_show_stamina or stamina_bar.value < stamina_bar.max_value

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(player) and player.is_node_ready():
		_refresh()

func _build_hints() -> void:
	for action in HINTS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		$Hints.add_child(row)
		var key := Label.new()
		key.custom_minimum_size = Vector2(60, 30)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_color_override("font_color", PALETTE.accent_soft)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(PALETTE.surface, 0.7)
		box.border_color = PALETTE.owned_border
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 8
		box.content_margin_right = 8
		key.add_theme_stylebox_override("normal", box)
		row.add_child(key)
		hint_keys[action] = key
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", PALETTE.text_primary)
		label.add_theme_color_override("font_shadow_color", PALETTE.shadow)
		label.add_theme_constant_override("shadow_offset_y", 2)
		row.add_child(label)
		hint_labels[action] = label
	refresh_key_hints()

func _refresh_hint_visibility() -> void:
	$Hints.visible = settings.show_control_hints
	set_process(settings.show_control_hints)
	if settings.show_control_hints: refresh_key_hints()

func _process(delta: float) -> void:
	# InputMap has no binding-changed signal. This also picks up runtime rebinds
	# and keyboard layout changes, without rebuilding controls every frame.
	hints_elapsed += delta
	if hints_elapsed >= 0.25:
		hints_elapsed = 0.0
		refresh_key_hints()

func refresh_key_hints() -> void:
	for action in hint_keys:
		hint_labels[action].text = COPY.text(HINTS[action])
		var binding := binding_text(action)
		if hint_keys[action].text != binding: hint_keys[action].text = binding

func binding_text(action: String) -> String:
	if is_instance_valid(settings) and settings.input_bindings.active_device == "controller":
		return settings.input_bindings.label_for(action, "controller")
	var names: Array[String] = []
	var other_names: Array[String] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key: InputEventKey = event.duplicate()
				if key.physical_keycode != 0:
					var mapped := key.physical_keycode
					if DisplayServer.get_name() != "headless":
						mapped = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
					key.keycode = mapped if mapped != 0 else key.physical_keycode
					key.physical_keycode = 0
				var name := OS.get_keycode_string(key.get_keycode_with_modifiers())
				if not name.is_empty() and name not in names: names.append(name)
			elif event is InputEventMouseButton:
				names.append(COPY.text("hud.hint.mouse", {"button": event.button_index}))
			else:
				other_names.append(event.as_text())
	if not names.is_empty(): return " / ".join(names)
	if not other_names.is_empty(): return " / ".join(other_names)
	return COPY.text("hud.hint.unbound")

func _apply_palette() -> void:
	for label in [health_label, level_label, experience_label, stamina_label]:
		label.add_theme_color_override("font_color", PALETTE.text_primary)
		label.add_theme_color_override("font_shadow_color", PALETTE.shadow)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	for bar in [health_bar, experience_bar, stamina_bar]:
		var track := StyleBoxFlat.new()
		track.bg_color = PALETTE.surface
		track.border_color = PALETTE.owned_border
		track.set_border_width_all(1)
		track.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", track)
		var fill := StyleBoxFlat.new()
		fill.bg_color = PALETTE.accent
		fill.border_color = PALETTE.accent_soft
		fill.set_border_width_all(1)
		fill.set_corner_radius_all(4)
		fill.shadow_color = Color(PALETTE.accent, 0.4)
		fill.shadow_size = 5
		bar.add_theme_stylebox_override("fill", fill)
	$Health/Icon/Cross.color = PALETTE.accent
	$Health/Icon/Glow.color = Color(PALETTE.accent, 0.18)

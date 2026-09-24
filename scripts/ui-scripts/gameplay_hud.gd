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
@onready var flight_charge_bar: ProgressBar = $FlightCharge/Bar
@onready var flight_charge_label: Label = $FlightCharge/Amount
@onready var heat_bar: ProgressBar = $Heat/Bar
@onready var heat_label: Label = $Heat/Amount
var _flight_charge_active := false
var _flight_charge_ratio := 0.0
var _flight_charge_eligible := false
var player: PlayerCharacter
const HINTS := {"jump": "hud.hint.jump", "toggle_flight": "hud.hint.flight", "sprint": "hud.hint.sprint", "aim_power": "hud.hint.aim", "attack": "hud.hint.power", "secondary_power": "hud.hint.dragon_breath"}
var hint_keys: Dictionary = {}
var hint_labels: Dictionary = {}
var hints_elapsed := 0.0
var settings: Node
var _health_recent: Timer
var _experience_recent: Timer
var _last_health := -1.0
var _last_max_health := -1.0
var _clock: Node
@onready var minimap: Control = $Minimap

func _enter_tree() -> void:
	# Hideout travel keeps this HUD/player, but replaces the city. _ready does
	# not run again when the existing player re-enters a different scene.
	_refresh_minimap.call_deferred()

func _ready() -> void:
	_apply_palette()
	_refresh_clock()
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
	minimap.player = player
	minimap.city = player.get_parent().get_node_or_null("SuperCity")
	settings.gameplay_settings_changed.connect(_refresh_minimap)
	_refresh_minimap()
	player.damage_receiver.health_changed.connect(_on_health_changed)
	player.stats.experience_changed.connect(_on_experience_changed)
	player.stats.level_changed.connect(_on_level_changed)
	player.stamina.changed.connect(_on_stamina_changed)
	player.flight_charge_changed.connect(_on_flight_charge_changed)
	player.laser_eyes.heat_changed.connect(_on_heat_changed)
	player.laser_eyes.aim_changed.connect(_on_aim_changed)
	player.get_node("PlayerFire").charge_changed.connect(_on_fire_charge_changed)
	player.abilities.ability_changed.connect(_on_ability_changed)
	player.get_node("PlayerPowerController").active_power_changed.connect(_on_active_power_changed)
	_refresh()

func _refresh_minimap() -> void:
	if not is_instance_valid(minimap) or not is_instance_valid(player) or not is_instance_valid(settings): return
	if not player.is_inside_tree(): return
	# Resolve against the player's current scene, never the freed outdoor city.
	minimap.player = player
	minimap.city = player.get_parent().get_node_or_null("SuperCity")
	minimap.visible = settings.show_minimap and is_instance_valid(minimap.city)
	minimap.queue_redraw()
	# Keep the existing control hints above the map; restore them when disabled.
	$Hints.offset_top = -552.0 if minimap.visible else -216.0
	$Hints.offset_bottom = -368.0 if minimap.visible else -32.0

func _on_active_power_changed(_power: StringName) -> void:
	refresh_key_hints()

func _refresh() -> void:
	_on_health_changed(player.get_current_health(), player.get_max_health())
	_on_stamina_changed(player.stamina.current, player.stamina.maximum, player.stamina.exhausted)
	_refresh_progression()
	refresh_key_hints()
	_on_flight_charge_changed(_flight_charge_active, _flight_charge_ratio, _flight_charge_eligible)
	_on_heat_changed(player.laser_eyes.heat, player.laser_eyes.overheated)
	_on_aim_changed(player.laser_eyes.aiming)
	var fire: PlayerFire = player.get_node("PlayerFire")
	_on_fire_charge_changed(fire.charging, fire.charge_ratio())

func _on_ability_changed(_id: StringName, _unlocked: bool) -> void:
	refresh_key_hints()
	_on_heat_changed(player.laser_eyes.heat, player.laser_eyes.overheated)

func _on_heat_changed(percent: float, overheated: bool) -> void:
	$Heat.visible = player.abilities.is_unlocked(PlayerAbilities.LASER_EYES) or player.abilities.is_unlocked(PlayerAbilities.FIRE) or player.abilities.is_unlocked(PlayerAbilities.ELECTRICITY) or percent > 0.0
	heat_bar.value = percent
	heat_label.text = COPY.text("hud.heat.overheated" if overheated else "hud.heat", {"percent": roundi(percent)})
	var fill := heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color(1.0, 0.24, 0.06) if overheated else PALETTE.accent
	fill.border_color = Color(1.0, 0.7, 0.25) if overheated else PALETTE.accent_soft
	fill.shadow_color = Color(fill.bg_color, 0.4)

func _on_fire_charge_changed(active: bool, ratio: float) -> void:
	$FireCharge.visible = active
	$FireCharge/Bar.value = ratio * 100.0
	$FireCharge/Amount.text = COPY.text("hud.fire_charge.full" if ratio >= 1.0 else "hud.fire_charge", {"percent": roundi(ratio * 100.0)})

func _on_aim_changed(active: bool) -> void:
	$LaserReticle.visible = active

func _on_flight_charge_changed(active: bool, ratio: float, eligible: bool) -> void:
	_flight_charge_active = active
	_flight_charge_ratio = ratio
	_flight_charge_eligible = eligible
	$FlightCharge.visible = active
	flight_charge_bar.visible = eligible
	flight_charge_bar.value = ratio * 100.0
	flight_charge_label.text = COPY.text("hud.flight_charge" if eligible else "hud.flight_charge.unavailable", {"percent": roundi(ratio * 100.0)})

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
	if settings.show_control_hints: refresh_key_hints()

func _process(delta: float) -> void:
	# InputMap has no binding-changed signal. This also picks up runtime rebinds
	# and keyboard layout changes, without rebuilding controls every frame.
	hints_elapsed += delta
	if hints_elapsed >= 0.25:
		hints_elapsed = 0.0
		_refresh_clock()
		if settings.show_control_hints: refresh_key_hints()

func _refresh_clock() -> void:
	if not is_instance_valid(_clock) or not _clock.is_inside_tree():
		_clock = get_tree().get_first_node_in_group(&"game_clock")
		if _clock != null and not _clock.time_changed.is_connected(_on_clock_changed):
			_clock.time_changed.connect(_on_clock_changed)
	$Clock.visible = is_instance_valid(_clock)
	if is_instance_valid(_clock): $Clock.text = _clock.formatted_time()

func _on_clock_changed(_hours: float) -> void:
	if is_instance_valid(_clock): $Clock.text = _clock.formatted_time()

func refresh_key_hints() -> void:
	if is_instance_valid(player):
		var id: StringName = player.get_node("PlayerPowerController").active_power
		$ActivePower.text = COPY.text("selector.hud", {"key": binding_text("power_selector"), "power": COPY.text("selector." + String(id))})
		if not player.get_node("PlayerPowerController").progression.is_implemented(String(id), 0):
			$ActivePower.text += "  ·  " + COPY.text("selector.future")
		elif not player.abilities.is_unlocked(id):
			$ActivePower.text += "  ·  " + COPY.text("selector.locked")
	for action in hint_keys:
		hint_labels[action].text = COPY.text(HINTS[action])
		if action in ["aim_power", "attack"]:
			hint_keys[action].get_parent().visible = is_instance_valid(player) and player.get_node("PlayerPowerController").active_power in [PlayerAbilities.LASER_EYES, PlayerAbilities.FIRE, PlayerAbilities.ELECTRICITY] and player.abilities.is_unlocked(player.get_node("PlayerPowerController").active_power)
		if action == "attack":
			hint_labels[action].text = COPY.text("hud.hint.active_power")
			if is_instance_valid(player) and player.get_node("PlayerPowerController").active_power == PlayerAbilities.ELECTRICITY:
				hint_labels[action].text = COPY.text("hud.hint.electric_shock")
			if is_instance_valid(player) and player.get_node("PlayerPowerController").active_power == PlayerAbilities.FIRE and player.abilities.is_unlocked(PlayerAbilities.CHARGED_FIREBALL):
				hint_labels[action].text = COPY.text("hud.hint.fire_charge")
		if action == "secondary_power":
			hint_keys[action].get_parent().visible = is_instance_valid(player) and player.get_node("PlayerPowerController").active_power == PlayerAbilities.FIRE and player.abilities.is_unlocked(PlayerAbilities.DRAGON_BREATH)
		if action == "toggle_flight" and is_instance_valid(player) and player.abilities.is_unlocked(PlayerAbilities.FLIGHT_SURGE):
			hint_labels[action].text = COPY.text("hud.hint.flight_surge")
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
	for label in [health_label, level_label, experience_label, stamina_label, flight_charge_label, heat_label, $FireCharge/Amount, $Clock]:
		label.add_theme_color_override("font_color", PALETTE.text_primary)
		label.add_theme_color_override("font_shadow_color", PALETTE.shadow)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	for bar in [health_bar, experience_bar, stamina_bar, flight_charge_bar, heat_bar, $FireCharge/Bar]:
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

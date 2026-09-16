@tool
extends Node3D
## Reusable vessel. Waterline Y=0; forward is local -Z; scale is in metres.
enum NavigationMode { UNDERWAY, ANCHORED, BERTHED }
@export var palette: Resource:
	set(value):
		palette = value
		if is_node_ready(): apply_palette()
@export_enum("Underway", "Anchored", "Berthed") var navigation_mode: int = NavigationMode.UNDERWAY:
	set(value):
		navigation_mode = value
		if is_node_ready(): apply_night(_night)
@export var follow_day_night_cycle := true
@export_range(0.0, 1.0, .05) var standalone_night_amount := 0.0:
	set(value):
		standalone_night_amount = value
		if is_node_ready(): apply_night(value)
@export_range(0.0, 12.0, .1) var navigation_brightness := 5.0:
	set(value):
		navigation_brightness = value
		if is_node_ready(): apply_night(_night)
@export var deck_lights_enabled := true:
	set(value):
		deck_lights_enabled = value
		if is_node_ready(): apply_night(_night)
var _night := 0.0
var _lenses: Array[MeshInstance3D] = []

func _ready() -> void:
	# Private shader instances isolate all light modes and brightness between ships.
	for lens: MeshInstance3D in $NavigationLights.get_children():
		lens.material_override = lens.material_override.duplicate()
		_lenses.append(lens)
	apply_palette()
	apply_night(standalone_night_amount)
	if not Engine.is_editor_hint(): _bind_clock.call_deferred()

func apply_palette() -> void:
	if palette == null or not has_node("Model"): return
	for part: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		var slot := String(part.name).to_snake_case()
		if slot not in ["hull", "deck", "superstructure", "container_a", "container_b", "container_c", "container_d"]: continue
		var material := palette.get(slot) as Material
		if material != null: part.material_override = material

func _bind_clock() -> void:
	if not follow_day_night_cycle: return
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock == null: return
	clock.night_lighting_changed.connect(apply_night)
	apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	_night = clampf(amount, 0.0, 1.0)
	for lens in _lenses:
		var is_anchor := String(lens.get_meta("mode")) == "anchored"
		var active := (is_anchor and navigation_mode == NavigationMode.ANCHORED) or (not is_anchor and navigation_mode == NavigationMode.UNDERWAY)
		lens.visible = active and _night > .001
		(lens.material_override as ShaderMaterial).set_shader_parameter("intensity", _night * navigation_brightness if active else 0.0)
	if has_node("AnchorDayBall"):
		$AnchorDayBall.visible = navigation_mode == NavigationMode.ANCHORED and _night < .5
	if has_node("DeckLights"):
		for light: SpotLight3D in $DeckLights.get_children():
			# Deck illumination is required for this >100 m ship at anchor.
			light.light_energy = _night * 2.0
			light.visible = _night > .001 and (deck_lights_enabled or navigation_mode == NavigationMode.ANCHORED)

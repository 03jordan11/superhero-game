extends StaticBody3D
signal window_materials_changed
## Shared by commercial, residential and industrial scenes; geometry is unchanged.
@export_range(0.0, 1.0, .01) var standalone_night_amount := 0.0
@export_range(0.0, 5.0, .05) var window_emission_energy := 2.0:
	set(value):
		window_emission_energy = value
		if is_node_ready() and _shared_windows: _apply_window_pattern()
@export var follow_day_night_cycle := true
@export var seeded_window_patterns := true
var _night_materials: Array[Material] = []
var _original_mesh: Mesh
var _window_variant: int = 0
var _window_sources: Dictionary = {}
var _night_surfaces: Array[int] = []
var _shared_windows := false
var _clock: Node

func _ready() -> void:
	var visual: MeshInstance3D = $MeshInstance3D
	_original_mesh = visual.mesh
	var library := get_node_or_null("/root/CityWindows")
	for surface in visual.mesh.get_surface_count():
		var source := visual.get_active_material(surface) as StandardMaterial3D
		if source == null or not source.emission_enabled: continue
		var copy: Material = library.make_material(source) if seeded_window_patterns and library != null and source.emission_texture != null else source.duplicate()
		visual.set_surface_override_material(surface, copy)
		_night_materials.append(copy)
		_night_surfaces.append(surface)
		if copy is ShaderMaterial: _window_sources[surface] = source
	if seeded_window_patterns and library != null:
		library.patterns_changed.connect(_apply_window_pattern)
		library.settings_changed.connect(_apply_window_settings)
		_apply_window_pattern()
		_apply_window_settings()
	apply_night(standalone_night_amount)
	_bind_clock.call_deferred()

func _apply_window_pattern() -> void:
	var library := get_node("/root/CityWindows")
	var visual: MeshInstance3D = $MeshInstance3D
	visual.mesh = library.mesh_with_emission_uvs(_original_mesh)
	_window_variant = library.variant_for(_original_mesh.resource_path, global_position)
	for surface in _original_mesh.get_surface_count():
		var material := visual.get_active_material(surface) as ShaderMaterial
		if material != null:
			if _shared_windows and _window_sources.has(surface):
				visual.set_surface_override_material(surface, library.shared_material(_original_mesh, surface, _window_sources[surface], _window_variant, window_emission_energy, _clock))
			else:
				material.set_shader_parameter("room_data", library.texture_for(_original_mesh, surface, _window_variant))
	_night_materials.clear()
	for surface in _night_surfaces: _night_materials.append(visual.get_active_material(surface))
	window_materials_changed.emit()

func _apply_window_settings() -> void:
	# CityWindows updates each shared resource once, instead of once per placement.
	if _shared_windows: return
	var library := get_node("/root/CityWindows")
	for material in _night_materials:
		if material is ShaderMaterial: library.apply_settings(material, _original_mesh.resource_path)

func _bind_clock() -> void:
	if not follow_day_night_cycle: return
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null:
		_clock = clock
		_shared_windows = seeded_window_patterns and not _window_sources.is_empty()
		if _shared_windows: _apply_window_pattern()
		clock.night_lighting_changed.connect(_on_clock_night)
		_on_clock_night(clock.night_lighting)

func _on_clock_night(amount: float) -> void:
	if not _shared_windows:
		apply_night(amount)
		return
	# Non-window signs/fixtures retain their existing private materials.
	for material in _night_materials:
		if material is StandardMaterial3D:
			material.emission_energy_multiplier = window_emission_energy * clampf(amount, 0, 1)

func apply_night(amount: float) -> void:
	# Explicit per-building previews/overrides must never recolor other placements.
	var detached := _shared_windows
	if _shared_windows:
		_shared_windows = false
		var visual: MeshInstance3D = $MeshInstance3D
		for surface in _window_sources:
			visual.set_surface_override_material(surface, visual.get_active_material(surface).duplicate())
		_night_materials.clear()
		for surface in _night_surfaces: _night_materials.append(visual.get_active_material(surface))
	for material in _night_materials:
		if material is ShaderMaterial:
			material.set_shader_parameter("emission_energy", window_emission_energy * clampf(amount, 0, 1))
		else:
			material.emission_energy_multiplier = window_emission_energy * clampf(amount, 0, 1)
	if detached: window_materials_changed.emit()

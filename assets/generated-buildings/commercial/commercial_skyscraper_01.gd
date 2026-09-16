extends StaticBody3D
## Only material emission changes; repeated placements share the mesh geometry.
@export_range(0.0,1.0,.01) var standalone_night_amount:=0.0
@export_range(0.0,5.0,.05) var window_emission_energy:=2.0
@export var follow_day_night_cycle:=true
@export var seeded_window_patterns:=true
var _night_materials: Array[StandardMaterial3D]=[]
var _original_mesh: Mesh
var _window_variant: int = 0
func _ready() -> void:
	var visual: MeshInstance3D=$MeshInstance3D
	_original_mesh=visual.mesh
	for s in visual.mesh.get_surface_count():
		var source:=visual.get_active_material(s) as StandardMaterial3D
		if source==null or not source.emission_enabled:continue
		var copy:=source.duplicate() as StandardMaterial3D
		visual.set_surface_override_material(s,copy);_night_materials.append(copy)
	if seeded_window_patterns:
		var library:=get_node_or_null("/root/CityWindows")
		if library!=null:
			library.patterns_changed.connect(_apply_window_pattern)
			_apply_window_pattern()
	apply_night(standalone_night_amount);_bind_clock.call_deferred()
func _apply_window_pattern() -> void:
	var library:=get_node("/root/CityWindows")
	var visual: MeshInstance3D=$MeshInstance3D
	visual.mesh=library.mesh_with_emission_uvs(_original_mesh)
	_window_variant=library.variant_for(_original_mesh.resource_path,global_position)
	for surface in _original_mesh.get_surface_count():
		var material:=visual.get_active_material(surface) as StandardMaterial3D
		if material==null or not material.emission_enabled: continue
		material.emission_texture=library.texture_for(_original_mesh,surface,_window_variant)
		material.emission_on_uv2=true
func _bind_clock() -> void:
	if not follow_day_night_cycle:return
	var clock:=get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock!=null:
		clock.night_lighting_changed.connect(apply_night);apply_night(clock.night_lighting)
func apply_night(amount: float) -> void:
	for material in _night_materials:material.emission_energy_multiplier=window_emission_energy*clampf(amount,0,1)

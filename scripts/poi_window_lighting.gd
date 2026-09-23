extends Node3D
## POI windows share the city palette, but get one stable rank per actual opening.
const SHADER = preload("res://assets/buildings/materials/poi_windows.gdshader")
const MASKS := {
	"bank1": preload("res://assets/buildings/materials/window_masks/bank1.png"),
	"bank1_great": preload("res://assets/buildings/materials/window_masks/bank1_great.png"),
	"bank2": preload("res://assets/buildings/materials/window_masks/bank2.png"),
	"city_hall": preload("res://assets/buildings/materials/window_masks/city_hall.png"),
	"police_station": preload("res://assets/buildings/materials/window_masks/police_station.png"),
	"hospital": preload("res://assets/buildings/materials/window_masks/hospital.png"),
	"hospital_curtain": preload("res://assets/buildings/materials/window_masks/hospital_curtain.png"),
	"firehouse": preload("res://assets/buildings/materials/window_masks/firehouse.png"),
}
@export_range(0, 1, .01) var standalone_night_amount := 0.0
@export_range(0, 5, .05) var window_emission_energy := 2.0
@export_range(0, 5, .05) var sign_emission_energy := 1.5
@export_range(0, 5, .05) var entrance_light_energy := 1.8
@export var follow_day_night_cycle := true
var _night_materials: Array[Material] = []
var _entrance_lights: Array[Light3D] = []
var _room_count := 0
var _asset_key: String
var _room_texture: Texture2D
var _library: Node

func _ready() -> void:
	_asset_key = get_script().resource_path
	_library = get_node("/root/CityWindows")
	var copies: Dictionary = {}
	for instance: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		var original := instance.mesh
		var changed := false
		var surfaces: Array = []
		for surface in original.get_surface_count():
			var arrays := original.surface_get_arrays(surface)
			var source := instance.get_active_material(surface) as StandardMaterial3D
			if source != null and source.emission_enabled:
				var kind := _mask_kind(source)
				if not copies.has(source):
					var copy: Material = source.duplicate() if kind.is_empty() else _make_material(source, kind)
					copies[source] = copy
					_night_materials.append(copy)
				instance.set_surface_override_material(surface, copies[source])
				if not kind.is_empty():
					_assign_rooms(arrays, kind == "hospital_curtain")
					changed = true
			surfaces.append(arrays)
		if changed:
			var mesh := ArrayMesh.new()
			for surface in original.get_surface_count():
				mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), surfaces[surface])
				mesh.surface_set_material(surface, original.surface_get_material(surface))
			instance.mesh = mesh
	if "/hospital/" in _asset_key:
		for light: Light3D in find_children("*", "Light3D", true, false): _entrance_lights.append(light)
	_library.patterns_changed.connect(_rebuild_pattern)
	_library.settings_changed.connect(_apply_window_settings)
	_rebuild_pattern()
	_apply_window_settings()
	apply_night(standalone_night_amount)
	_bind_clock.call_deferred()

func _mask_kind(source: StandardMaterial3D) -> String:
	if source.emission_texture == null: return ""
	var path := source.emission_texture.resource_path
	if "lamps" in path: return ""
	if "curtain" in path: return "hospital_curtain"
	if "great_window" in path: return "bank1_great"
	return _asset_key.get_base_dir().get_file()

func _make_material(source: StandardMaterial3D, kind: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("facade_albedo", source.albedo_texture)
	material.set_shader_parameter("facade_tint", source.albedo_color)
	material.set_shader_parameter("facade_roughness", source.roughness)
	material.set_shader_parameter("facade_metallic", source.metallic)
	material.set_shader_parameter("facade_specular", source.metallic_specular)
	material.set_shader_parameter("window_mask", MASKS[kind])
	material.set_shader_parameter("curtain_windows", kind == "hospital_curtain")
	return material

func _assign_rooms(arrays: Array, curtain: bool) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parents: Array[int] = []
	var shared_vertices: Dictionary = {}
	for i in vertices.size():
		parents.append(i)
		# Imported seams can duplicate a vertex; position + UV identifies the join.
		var key := "%s|%s" % [vertices[i], uvs[i]]
		if shared_vertices.has(key): parents[i] = shared_vertices[key]
		else: shared_vertices[key] = i
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	for triangle in range(0, indices.size(), 3):
		var first := _root(parents, indices[triangle])
		for j in [1, 2]: parents[_root(parents, indices[triangle + j])] = first
	var rooms: Dictionary = {}
	for i in vertices.size():
		var component := _root(parents, i)
		if not rooms.has(component): rooms[component] = []
		rooms[component].append(i)
	var uv2 := PackedVector2Array()
	uv2.resize(vertices.size())
	for component in rooms:
		var first_row := 0
		var count := 1
		if curtain:
			var low := INF
			var high := -INF
			for i in rooms[component]:
				low = minf(low, uvs[i].y)
				high = maxf(high, uvs[i].y)
			first_row = _curtain_row(low + .00001)
			count = (_curtain_row(high - .00001) - first_row + 1) * 4
		for i in rooms[component]: uv2[i] = Vector2(_room_count, first_row)
		_room_count += count
	arrays[Mesh.ARRAY_TEX_UV2] = uv2

func _curtain_row(v: float) -> int:
	return floori(v) * 12 + floori(clampf((fposmod(v, 1.0) * 1024.0 - 4.0) / 85.0, 0, 11))

func _root(parents: Array[int], vertex: int) -> int:
	while parents[vertex] != vertex:
		parents[vertex] = parents[parents[vertex]]
		vertex = parents[vertex]
	return vertex

func _rebuild_pattern() -> void:
	if _room_count == 0: return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(("%d|%s|%s" % [_library.city_seed, _asset_key, global_position]).hash())
	var order: Array[int] = []
	for i in _room_count: order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := order[i]; order[i] = order[j]; order[j] = temp
	var image := Image.create(_room_count, 1, false, Image.FORMAT_RGBAF)
	for rank in _room_count:
		image.set_pixel(order[rank], 0, Color((rank + .5) / _room_count, rng.randf() * .999999, rng.randf_range(.88, 1), rng.randf()))
	_room_texture = ImageTexture.create_from_image(image)
	for material in _night_materials:
		if material is ShaderMaterial:
			material.set_shader_parameter("room_data", _room_texture)
			material.set_shader_parameter("room_count", float(_room_count))

func _apply_window_settings() -> void:
	for material in _night_materials:
		if material is ShaderMaterial: _library.apply_settings(material, _asset_key)

func _bind_clock() -> void:
	if not follow_day_night_cycle: return
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null:
		clock.night_lighting_changed.connect(apply_night)
		apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	var night := clampf(amount, 0, 1)
	for material in _night_materials:
		if material is ShaderMaterial:
			material.set_shader_parameter("emission_energy", window_emission_energy * night)
		else:
			var energy := sign_emission_energy if "/hospital/" in _asset_key else window_emission_energy
			material.emission_energy_multiplier = energy * night
	for light in _entrance_lights:
		light.light_energy = entrance_light_energy * night
		light.visible = night > .001

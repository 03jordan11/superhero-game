extends Node
## Shared window masks and seeded room data. Tuning changes shader uniforms only.
signal patterns_changed
signal settings_changed
const WINDOW_SHADER = preload("res://assets/generated-buildings/commercial/materials/city_windows.gdshader")
const DEFAULTS := {"lit_window_percent": 50.0, "use_district_percentages": true,
	"commercial_percent": 10.0, "residential_percent": 7.0, "industrial_percent": 5.0,
	"warm_window_percent": 60.0, "brightness": 2.0,
	"bank_percent": 2.0, "police_percent": 20.0, "city_hall_percent": 10.0,
	"hospital_percent": 30.0, "firehouse_percent": 10.0}
const PALETTE = preload("res://assets/buildings/materials/city_window_palette.tres")

@export_group("Window occupancy")
@export_range(0, 100, 1, "suffix:%") var lit_window_percent := 50.0:
	set(value):
		if is_finite(value): lit_window_percent = clampf(value, 0, 100); settings_changed.emit()
@export var use_district_percentages := true:
	set(value):
		use_district_percentages = value
		settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var commercial_percent := 10.0:
	set(value):
		if is_finite(value): commercial_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var residential_percent := 7.0:
	set(value):
		if is_finite(value): residential_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var industrial_percent := 5.0:
	set(value):
		if is_finite(value): industrial_percent = clampf(value, 0, 100); settings_changed.emit()
@export_group("Window colors")
@export_range(0, 100, 1, "suffix:%") var warm_window_percent := 60.0:
	set(value):
		if is_finite(value): warm_window_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 3, 0.05) var brightness := 2.0:
	set(value):
		if is_finite(value): brightness = clampf(value, 0, 3); settings_changed.emit()
@export_group("Landmark windows")
@export_range(0, 100, 1, "suffix:%") var bank_percent := 2.0:
	set(value):
		if is_finite(value): bank_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var police_percent := 20.0:
	set(value):
		if is_finite(value): police_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var city_hall_percent := 10.0:
	set(value):
		if is_finite(value): city_hall_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var hospital_percent := 30.0:
	set(value):
		if is_finite(value): hospital_percent = clampf(value, 0, 100); settings_changed.emit()
@export_range(0, 100, 1, "suffix:%") var firehouse_percent := 10.0:
	set(value):
		if is_finite(value): firehouse_percent = clampf(value, 0, 100); settings_changed.emit()
@export_group("Stable patterns")
@export_range(1, 12, 1) var variants_per_asset := 6:
	set(value):
		variants_per_asset = clampi(value, 1, 12)
		if is_inside_tree(): rebuild_patterns()
@export var city_seed: int = 8421:
	set(value):
		city_seed = clampi(value, 0, 2147483646)
		if is_inside_tree(): rebuild_patterns()

var _meshes: Dictionary = {}
var _textures: Dictionary = {}
var _masks: Dictionary = {}
var _shared_materials: Dictionary = {}
var _shared_clocks: Dictionary = {}

func _ready() -> void:
	settings_changed.connect(_update_shared_material_settings)
	PALETTE.changed.connect(func(): settings_changed.emit())

func start_new_game(seed_override: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	set_city_seed(rng.randi_range(1, 2147483646) if seed_override < 0 else seed_override)

func set_city_seed(value: int) -> void:
	city_seed = value

func rebuild_patterns() -> void:
	_textures.clear()
	# Placements select their new variant when patterns_changed is delivered.
	_shared_materials.clear()
	patterns_changed.emit()

func save_data() -> Dictionary:
	var data := {"seed": city_seed, "pattern_version": 2}
	for key in DEFAULTS: data[key] = get(key)
	return data

func restore_data(data: Dictionary) -> void:
	# Legacy saves keep their seed and get the new, explicit occupancy defaults.
	set_block_signals(true)
	for key in DEFAULTS:
		var value: Variant = data.get(key, DEFAULTS[key])
		if DEFAULTS[key] is bool:
			set(key, value if value is bool else DEFAULTS[key])
		else:
			set(key, _finite_number(value, DEFAULTS[key]))
	set_block_signals(false)
	settings_changed.emit()
	set_city_seed(int(clampf(_finite_number(data.get("seed", 8421), 8421), 0, 2147483646)))

func _finite_number(value: Variant, fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

func variant_for(asset: String, placement: Vector3) -> int:
	var key := "%d|%s|%.2f|%.2f|%.2f" % [city_seed, asset, placement.x, placement.y, placement.z]
	return int(key.hash()) % variants_per_asset

func percent_for(asset: String) -> float:
	if "/bank1/" in asset or "/bank2/" in asset: return bank_percent
	if "/police_station/" in asset: return police_percent
	if "/city_hall/" in asset: return city_hall_percent
	if "/hospital/" in asset: return hospital_percent
	if "/firehouse/" in asset: return firehouse_percent
	if not use_district_percentages: return lit_window_percent
	if "/residential/" in asset: return residential_percent
	if "/industrial/" in asset: return industrial_percent
	return commercial_percent

func apply_settings(material: ShaderMaterial, asset: String) -> void:
	PALETTE.apply_to(material)
	material.set_shader_parameter("occupancy", percent_for(asset) / 100.0)
	material.set_shader_parameter("warm_fraction", warm_window_percent / 100.0)
	material.set_shader_parameter("brightness", brightness)

func make_material(source: StandardMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WINDOW_SHADER
	material.set_shader_parameter("facade_albedo", source.albedo_texture)
	material.set_shader_parameter("facade_tint", source.albedo_color)
	material.set_shader_parameter("facade_roughness", source.roughness)
	material.set_shader_parameter("facade_metallic", source.metallic)
	material.set_shader_parameter("facade_specular", source.metallic_specular)
	PALETTE.apply_to(material)
	material.set_shader_parameter("window_mask", mask_for(source.emission_texture))
	return material

func shared_material(original: Mesh, surface: int, source: StandardMaterial3D, variant: int, energy: float, clock: Node) -> ShaderMaterial:
	var clock_id := clock.get_instance_id()
	if not _shared_clocks.has(clock_id):
		_shared_clocks[clock_id] = weakref(clock)
		clock.night_lighting_changed.connect(_update_shared_night.bind(clock_id))
		clock.tree_exiting.connect(_release_shared_clock.bind(clock_id))
	# Keep different source overrides, patterns, intensity and clocks independent.
	var key := [original, surface, source, variant, energy, clock_id]
	if not _shared_materials.has(key):
		var material := make_material(source)
		material.set_shader_parameter("room_data", texture_for(original, surface, variant))
		material.set_shader_parameter("emission_energy", energy * clampf(clock.night_lighting, 0, 1))
		apply_settings(material, original.resource_path)
		_shared_materials[key] = material
	return _shared_materials[key]

func _update_shared_night(amount: float, clock_id: int) -> void:
	for key: Array in _shared_materials:
		if key[5] == clock_id:
			_shared_materials[key].set_shader_parameter("emission_energy", key[4] * clampf(amount, 0, 1))

func _update_shared_material_settings() -> void:
	for key: Array in _shared_materials:
		apply_settings(_shared_materials[key], key[0].resource_path)

func _release_shared_clock(clock_id: int) -> void:
	for key: Array in _shared_materials.keys():
		if key[5] == clock_id: _shared_materials.erase(key)
	var clock: Node = _shared_clocks[clock_id].get_ref()
	if is_instance_valid(clock):
		clock.night_lighting_changed.disconnect(_update_shared_night.bind(clock_id))
		clock.tree_exiting.disconnect(_release_shared_clock.bind(clock_id))
	_shared_clocks.erase(clock_id)

func mesh_with_emission_uvs(original: Mesh) -> Mesh:
	if _meshes.has(original): return _meshes[original]
	var mesh := ArrayMesh.new()
	var cpu_arrays: Array = []
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var source := original.surface_get_material(surface) as StandardMaterial3D
		if source != null and source.emission_enabled and source.emission_texture != null:
			var size := surface_image_size(original, surface)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV].duplicate()
			for vertex in uvs.size(): uvs[vertex] *= Vector2(64, 64) / Vector2(size)
			arrays[Mesh.ARRAY_TEX_UV2] = uvs
		mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
		mesh.surface_set_material(surface, source)
		cpu_arrays.append(arrays)
	mesh.set_meta("hlod_cpu_arrays", cpu_arrays)
	_meshes[original] = mesh
	return mesh

func surface_image_size(mesh: Mesh, surface: int) -> Vector2i:
	var high := Vector2.ZERO
	for uv in mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]: high = high.max(uv)
	# All three generated packs use four 16-pixel rooms per 64-pixel tile.
	return Vector2i(maxi(1, ceili(high.x * 4.0)), maxi(1, ceili(high.y * 4.0))) * 16

func mask_for(texture: Texture2D) -> Texture2D:
	if _masks.has(texture): return _masks[texture]
	var source := texture.get_image()
	var silhouette := Image.create(16, 16, false, Image.FORMAT_R8)
	# Recover the full window silhouette from lit cells in the authored tile.
	# Originally dark rooms can light up without lighting frames or walls.
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).r > 0.1:
				silhouette.set_pixel(x % 16, y % 16, Color.WHITE)
	var mask := Image.create(64, 64, false, Image.FORMAT_R8)
	for y in 4:
		for x in 4:
			if eligible_cell(texture, Vector2i(x, y)):
				mask.blit_rect(silhouette, Rect2i(0, 0, 16, 16), Vector2i(x, y) * 16)
	mask.generate_mipmaps()
	var result := ImageTexture.create_from_image(mask)
	result.set_meta("hlod_cpu_image", mask)
	_masks[texture] = result
	return result

func eligible_cell(texture: Texture2D, cell: Vector2i) -> bool:
	# Foundry clerestory artwork has solid wall in the other three tile rows.
	return not "foundry_windows" in texture.resource_path or cell.y % 4 == 0

func texture_for(original: Mesh, surface: int, variant: int) -> Texture2D:
	var key := "%s|%d|%d|%d" % [original.resource_path, surface, variant, city_seed]
	if _textures.has(key): return _textures[key]
	var size := surface_image_size(original, surface) / 16
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
	image.fill(Color(1, 0, 0, 0))
	var source := original.surface_get_material(surface) as StandardMaterial3D
	var order: Array[int] = []
	for i in size.x * size.y:
		if eligible_cell(source.emission_texture, Vector2i(i % size.x, i / size.x)): order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(key.hash())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := order[i]; order[i] = order[j]; order[j] = temp
	for rank in order.size():
		var cell := order[rank]
		# R: occupancy rank; G: temperature; B: brightness; A: warm shade.
		image.set_pixel(cell % size.x, cell / size.x,
			Color((rank + 0.5) / order.size(), rng.randf() * 0.999999, rng.randf_range(0.88, 1.0), rng.randf()))
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("hlod_cpu_image", image)
	_textures[key] = texture
	return texture

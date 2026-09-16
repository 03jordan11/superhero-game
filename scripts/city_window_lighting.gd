extends Node
## Original window pixels, sparsified once per asset/variant and shared citywide.
## No per-frame updates, window lights, or procedural replacement of window shapes.
signal patterns_changed

@export_group("Window occupancy")
@export_range(0.0, 0.95, 0.01) var industrial_windows_off := 0.75:
	set(value):
		industrial_windows_off = clampf(value, 0.0, 0.95)
		if is_inside_tree(): rebuild_patterns()
@export_range(0.0, 0.4, 0.01) var residential_extra_windows_off := 0.20:
	set(value):
		residential_extra_windows_off = clampf(value, 0.0, 0.4)
		if is_inside_tree(): rebuild_patterns()
@export_range(0.0, 0.8, 0.01) var additional_windows_off := 0.40:
	set(value):
		additional_windows_off = clampf(value, 0.0, 0.8)
		if is_inside_tree(): rebuild_patterns()
@export_range(0.0, 0.2, 0.01) var building_variation := 0.10:
	set(value):
		building_variation = clampf(value, 0.0, 0.2)
		if is_inside_tree(): rebuild_patterns()
@export_range(1, 12, 1) var variants_per_asset := 6:
	set(value):
		variants_per_asset = clampi(value, 1, 12)
		if is_inside_tree(): rebuild_patterns()
@export_range(0.5, 1.0, 0.01) var minimum_window_brightness := 0.88:
	set(value):
		minimum_window_brightness = clampf(value, 0.5, 1.0)
		if is_inside_tree(): rebuild_patterns()
@export var city_seed: int = 8421:
	set(value):
		city_seed = clampi(value, 0, 2147483646)
		if is_inside_tree(): rebuild_patterns()

var _meshes: Dictionary = {}
var _textures: Dictionary = {}

func start_new_game(seed_override: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	set_city_seed(rng.randi_range(1, 2147483646) if seed_override < 0 else seed_override)

func set_city_seed(value: int) -> void:
	city_seed = clampi(value, 0, 2147483646)

## Call after changing Inspector controls during a running game.
func rebuild_patterns() -> void:
	_textures.clear()
	patterns_changed.emit()

func save_data() -> Dictionary:
	return {"seed": city_seed, "pattern_version": 1}

func restore_data(data: Dictionary) -> void:
	# Legacy saves get a consistent fallback, never a new seed on every load.
	var value: Variant = data.get("seed", 8421)
	if not (value is int or value is float) or not is_finite(float(value)):
		value = 8421
	set_city_seed(int(clampf(float(value), 0, 2147483646)))

func variant_for(asset: String, placement: Vector3) -> int:
	var key := "%d|%s|%.2f|%.2f|%.2f" % [city_seed, asset, placement.x, placement.y, placement.z]
	return int(key.hash()) % maxi(variants_per_asset, 1)

func reduction_for(variant: int, residential := false, industrial := false) -> float:
	var spread := 0.0 if variants_per_asset <= 1 else float(variant) / float(variants_per_asset - 1) * 2.0 - 1.0
	if industrial: return clampf(industrial_windows_off + spread * minf(building_variation, 0.05), 0.0, 0.95)
	return clampf(additional_windows_off + (residential_extra_windows_off if residential else 0.0) + spread * building_variation, 0.0, 0.8)

func mesh_with_emission_uvs(original: Mesh) -> Mesh:
	var key := original
	if _meshes.has(key): return _meshes[key]
	var mesh := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var source := original.surface_get_material(surface) as StandardMaterial3D
		if source != null and source.emission_enabled and source.emission_texture != null:
			var size := surface_image_size(original, surface)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV].duplicate()
			for vertex in uvs.size():
				uvs[vertex] *= source.emission_texture.get_size() / Vector2(size)
			arrays[Mesh.ARRAY_TEX_UV2] = uvs
		mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
		mesh.surface_set_material(surface, source)
	_meshes[key] = mesh
	return mesh

func surface_image_size(mesh: Mesh, surface: int) -> Vector2i:
	var high := Vector2.ZERO
	for uv in mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]: high = high.max(uv)
	# Current commercial assets have four 16-pixel window cells per source tile.
	return Vector2i(maxi(1, ceili(high.x * 4.0)), maxi(1, ceili(high.y * 4.0))) * 16

func texture_for(original: Mesh, surface: int, variant: int) -> Texture2D:
	var source := original.surface_get_material(surface) as StandardMaterial3D
	var key := "%s|%d|%d|%d|%s" % [original.resource_path, surface, variant, city_seed, str([additional_windows_off, building_variation, minimum_window_brightness])]
	var residential := original.resource_path.begins_with("res://assets/generated-buildings/residential/")
	var industrial := original.resource_path.begins_with("res://assets/generated-buildings/industrial/")
	if residential: key += "|residential:" + str(residential_extra_windows_off)
	if industrial: key += "|industrial:" + str(industrial_windows_off)
	if _textures.has(key): return _textures[key]
	var image := make_image(source.emission_texture.get_image(), surface_image_size(original, surface), int(key.hash()), reduction_for(variant, residential, industrial), industrial)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture

func make_image(original: Image, size: Vector2i, pattern_seed: int, reduction: float, sparse_industrial := false) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for y in range(0, size.y, original.get_height()):
		for x in range(0, size.x, original.get_width()):
			image.blit_rect(original, Rect2i(Vector2i.ZERO, original.get_size()), Vector2i(x, y))
	var candidates: Array[Vector2i] = []
	for y in size.y / 16:
		for x in size.x / 16:
			if image.get_pixel(x * 16 + 5, y * 16 + 5).r > 0.1:
				candidates.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := candidates[i]; candidates[i] = candidates[j]; candidates[j] = temp
	var off: Dictionary = {}
	var target := roundi(candidates.size() * reduction)
	for cell in candidates:
		if off.size() >= target: break
		if off.has(cell) or (not sparse_industrial and not _can_switch_off(cell, off)): continue
		off[cell] = true
		# Occasional short horizontal pairs; never multi-floor rectangular edits.
		var neighbor := cell + Vector2i.RIGHT
		if off.size() % 7 == 0 and off.size() < target and neighbor in candidates and _can_switch_off(neighbor, off):
			off[neighbor] = true
	for cell in candidates:
		if off.has(cell):
			image.fill_rect(Rect2i(cell * 16, Vector2i(16, 16)), Color.BLACK)
		elif rng.randf() < 0.35:
			var strength := rng.randf_range(minimum_window_brightness, 1.0)
			for y in 16:
				for x in 16:
					var pixel := cell * 16 + Vector2i(x, y)
					image.set_pixelv(pixel, image.get_pixelv(pixel) * strength)
	return image

func _can_switch_off(cell: Vector2i, off: Dictionary) -> bool:
	# Limit new dark groups to two cells, avoiding strips and rectangles.
	if off.has(cell): return false
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if off.has(cell + direction) and off.has(cell + direction * 2): return false
		if off.has(cell + direction) and off.has(cell - direction): return false
	for x in [-1, 1]:
		for y in [-1, 1]:
			if off.has(cell + Vector2i(x, 0)) and off.has(cell + Vector2i(0, y)) and off.has(cell + Vector2i(x, y)): return false
	return true

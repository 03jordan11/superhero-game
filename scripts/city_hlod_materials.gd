extends RefCounted
## One texture-array material for all simplified city proxy faces.
## Source facade/roof textures and window data do not create extra surfaces.
const WINDOW_SHADER := preload("res://assets/generated-buildings/commercial/materials/city_windows.gdshader")
const POI_SHADER := preload("res://assets/buildings/materials/poi_windows.gdshader")
const SHADER := preload("res://assets/generated-buildings/commercial/materials/corridor_hlod.gdshader")
var material := ShaderMaterial.new()
var sources: Array[Material] = []
var _slots := {}
var _room_sizes: Array[Vector2i] = []
var _data: Image
var _data_texture: ImageTexture
var _arrays := {}
var _images := {}
var room_images: Array[Image] = []
var proxy_recipes := {}
var authored_boxes := {}
var fallback := StandardMaterial3D.new()
var _tinted := {}

func with_vertex_tint(source: Material, tint: Color) -> Material:
	if not source is StandardMaterial3D or not source.vertex_color_use_as_albedo: return source
	var key := [source, tint]
	if not _tinted.has(key):
		var copy: StandardMaterial3D = source.duplicate()
		copy.albedo_color *= tint if source.vertex_color_is_srgb else tint.linear_to_srgb()
		copy.vertex_color_use_as_albedo = false
		_tinted[key] = copy
	return _tinted[key]

func _init() -> void:
	material.shader = SHADER
	fallback.albedo_color = Color(0.32, 0.34, 0.36)

func slot(source: Material) -> int:
	if not source is StandardMaterial3D and not (source is ShaderMaterial and source.shader in [WINDOW_SHADER, POI_SHADER]): source = fallback
	if not _slots.has(source):
		_slots[source] = sources.size()
		sources.append(source)
	return _slots[source]

func source_arrays(mesh: Mesh, surface: int) -> Array:
	var key := [mesh, surface]
	if not _arrays.has(key):
		_arrays[key] = mesh.get_meta("hlod_cpu_arrays")[surface] if mesh.has_meta("hlod_cpu_arrays") else mesh.surface_get_arrays(surface)
	return _arrays[key]

func _image(texture: Texture2D, format: Image.Format, fill: Color) -> Image:
	if texture == null:
		var blank := Image.create(1, 1, false, format)
		blank.fill(fill)
		return blank
	if not _images.has(texture):
		_images[texture] = texture.get_meta("hlod_cpu_image") if texture.has_meta("hlod_cpu_image") else texture.get_image()
	var copy := _images[texture].duplicate() as Image
	if copy.is_compressed(): copy.decompress()
	copy.clear_mipmaps()
	copy.convert(format)
	return copy

func finish() -> bool:
	if sources.is_empty(): return true
	var facades: Array[Image] = []
	var masks: Array[Image] = []
	var rooms: Array[Image] = []
	var facade_size := Vector2i.ONE
	var room_size := Vector2i.ONE
	for source in sources:
		var windows := source is ShaderMaterial
		var facade: Texture2D = source.get_shader_parameter("facade_albedo") if windows else source.albedo_texture
		var mask: Texture2D = source.get_shader_parameter("window_mask") if windows else null
		var room: Texture2D = source.get_shader_parameter("room_data") if windows else null
		facades.append(_image(facade, Image.FORMAT_RGBA8, Color.WHITE))
		masks.append(_image(mask, Image.FORMAT_R8, Color.BLACK))
		rooms.append(_image(room, Image.FORMAT_RGBAF, Color(1, 0, 0, 0)))
		facade_size = facade_size.max(facades[-1].get_size().clamp(Vector2i.ONE, Vector2i(256, 256)))
		room_size = room_size.max(rooms[-1].get_size())
		_room_sizes.append(rooms[-1].get_size())
	for i in sources.size():
		facades[i].resize(facade_size.x, facade_size.y, Image.INTERPOLATE_NEAREST)
		facades[i].generate_mipmaps()
		masks[i].resize(64, 64, Image.INTERPOLATE_NEAREST)
		masks[i].generate_mipmaps()
		var padded := Image.create(room_size.x, room_size.y, false, Image.FORMAT_RGBAF)
		padded.fill(Color(1, 0, 0, 0))
		padded.blit_rect(rooms[i], Rect2i(Vector2i.ZERO, rooms[i].get_size()), Vector2i.ZERO)
		rooms[i] = padded
	room_images = rooms
	for pair in [["facades", facades], ["masks", masks], ["rooms", rooms]]:
		var array := Texture2DArray.new()
		var error := array.create_from_images(pair[1])
		if error != OK:
			push_warning("HLOD texture array unavailable; using original buildings: " + error_string(error))
			return false
		material.set_shader_parameter(pair[0], array)
	_data = Image.create(sources.size(), 4, false, Image.FORMAT_RGBAF)
	_data_texture = ImageTexture.create_from_image(_data)
	material.set_shader_parameter("material_data", _data_texture)
	refresh()
	return true

func refresh() -> void:
	if _data == null: return
	for i in sources.size():
		var source := sources[i]
		var windows := source is ShaderMaterial
		var tint: Color = source.get_shader_parameter("facade_tint") if windows else source.albedo_color
		_data.set_pixel(i, 0, tint.srgb_to_linear())
		var roughness: float = source.get_shader_parameter("facade_roughness") if windows else source.roughness
		var metallic: float = source.get_shader_parameter("facade_metallic") if windows else source.metallic
		var specular: float = source.get_shader_parameter("facade_specular") if windows else source.metallic_specular
		_data.set_pixel(i, 1, Color(roughness, metallic, specular, (2.0 if source.shader == POI_SHADER else 1.0) if windows else 0.0))
		if windows:
			_data.set_pixel(i, 2, Color(_room_sizes[i].x, _room_sizes[i].y, source.get_shader_parameter("occupancy"), source.get_shader_parameter("warm_fraction")))
			_data.set_pixel(i, 3, Color(source.get_shader_parameter("emission_energy"), source.get_shader_parameter("brightness"), 0, 0))
	_data_texture.update(_data)
	preload("res://assets/buildings/materials/city_window_palette.tres").apply_to(material)

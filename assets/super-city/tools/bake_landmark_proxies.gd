extends SceneTree
## Run with the graphical renderer, not --headless. Rebuild after editing a POI.
const OUTPUT := "res://assets/super-city/landmark_proxies/"
const PATHS := ["Bank1", "Bank2", "BoxingGymExterior", "CityHall", "Firehouse", "Hospital",
	"ParkingGarage", "ParkingGarage2", "ParkingGarage3", "ParkingGarage4", "ParkingGarage5",
	"ParkingGarage6", "ParkingGarage7", "ParkingGarage8", "PoliceStation", "Sidewalks/GasStationHideout", "Landmarks/CentralPark"]
const NORMALS := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]
const TILE := 512
const BUILDER = preload("res://scripts/city_chunk_hlod.gd")
var viewport: SubViewport
var camera: Camera3D
var content: Node3D
var copies: Array[Dictionary] = []
var views: Array[Dictionary] = []
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
var material_cache: Dictionary = {}
var poi_emission_shader: Shader
var poi_albedo_shader: Shader
var single_view := false
var output_dir := OUTPUT
var paths: Array = PATHS
var proxy_shader_path := OUTPUT + "landmark_proxy.gdshader"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	paused = true
	AudioServer.set_bus_mute(0, true)
	root.get_node("CityWindows").start_new_game(8421)
	var world := load("res://scenes/main.tscn").instantiate() as Node3D
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	root.add_child(world)
	world.get_node("SuperCity/CityBuildingChunks").set_process(false)
	if world.get_node_or_null("SuperCity/LandmarkProxies") != null:
		world.get_node("SuperCity/LandmarkProxies").set_process(false)
	if world.get_node_or_null("SuperCity/RegionalProxies") != null:
		world.get_node("SuperCity/RegionalProxies").set_process(false)
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	viewport = SubViewport.new()
	viewport.size = Vector2i(TILE, TILE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewport.add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 10000.0
	viewport.add_child(camera)
	camera.make_current()
	_prepare_shaders()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var inventory := []
	# Optional explicit source paths after -- rebuild only those entries.
	var requested := OS.get_cmdline_user_args()
	if not requested.is_empty():
		for path in requested: assert(path in paths,"Unknown proxy source: "+path)
		paths = paths.filter(func(path): return path in requested)
		if FileAccess.file_exists(output_dir+"inventory.json"):
			var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output_dir+"inventory.json"))
			for record in previous.landmarks:
				if record.path not in paths: inventory.append(record)
	for path: String in paths:
		inventory.append(await bake(world.get_node("SuperCity/" + path), path))
	var file := FileAccess.open(output_dir + "inventory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"description": "Static geometry counts, not frame draw-call or FPS measurements.", "landmarks": inventory}, "\t"))
	file.close()
	world.free()
	viewport.free()
	print("LANDMARK_BAKE_COMPLETE: ", inventory.size(), " one-surface replacements")
	quit()

func _prepare_shaders() -> void:
	var code := FileAccess.get_file_as_string("res://assets/buildings/materials/poi_windows.gdshader")
	code = code.replace("render_mode diffuse_burley, specular_schlick_ggx;", "render_mode unshaded;")
	poi_albedo_shader = Shader.new()
	poi_albedo_shader.code = code.replace("EMISSION = window_light_color", "EMISSION = vec3(0.0) * window_light_color")
	poi_emission_shader = Shader.new()
	poi_emission_shader.code = code.replace("ALBEDO = texture(facade_albedo, UV).rgb * facade_tint.rgb;", "ALBEDO = vec3(0.0);").replace("EMISSION =", "ALBEDO =")

func _bake_material(source: Material, emission: bool) -> Material:
	var key := [source, emission]
	if material_cache.has(key): return material_cache[key]
	var result: Material
	if source is StandardMaterial3D:
		var copy := source.duplicate() as StandardMaterial3D
		copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		copy.normal_enabled = false
		copy.ao_enabled = false
		if emission:
			copy.albedo_texture = source.emission_texture if source.emission_enabled else null
			copy.albedo_color = source.emission if source.emission_enabled else Color.BLACK
			copy.vertex_color_use_as_albedo = false
		copy.emission_enabled = false
		result = copy
	elif source is ShaderMaterial and source.shader.resource_path.ends_with("poi_windows.gdshader"):
		var copy := source.duplicate() as ShaderMaterial
		copy.shader = poi_emission_shader if emission else poi_albedo_shader
		copy.set_shader_parameter("emission_energy", 1.0)
		copy.set_shader_parameter("brightness", 1.0)
		result = copy
	elif source is ShaderMaterial and not emission:
		# Preserve the authored world-aligned paving and park water colors.
		var copy := source.duplicate() as ShaderMaterial
		var shader := Shader.new()
		shader.code = source.shader.code.replace("render_mode cull_back;", "").replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
		copy.shader = shader
		result = copy
	else:
		var copy := StandardMaterial3D.new()
		copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		copy.albedo_color = Color.BLACK if emission else Color.WHITE
		result = copy
	material_cache[key] = result
	return result

func bake(source: Node3D, path: String) -> Dictionary:
	print("Baking landmark: ", path)
	content = Node3D.new()
	viewport.add_child(content)
	copies.clear()
	views.clear()
	vertices.clear()
	normals.clear()
	uvs.clear()
	indices.clear()
	var bounds := AABB()
	var first := true
	var source_triangles := 0
	var source_surfaces := 0
	var is_park := path.ends_with("CentralPark")
	single_view = is_park
	var tile := 1024 if is_park else TILE
	viewport.size = Vector2i(tile, tile)
	for visual: GeometryInstance3D in source.find_children("*", "GeometryInstance3D", true, false):
		if not include_visual(source, visual): continue
		if not visual.is_visible_in_tree() or str(visual.name) == "Fireflies": continue
		var clone: GeometryInstance3D
		var mesh: Mesh
		var instances := 1
		if visual is MeshInstance3D and visual.mesh != null:
			mesh = visual.mesh
			clone = MeshInstance3D.new()
			clone.mesh = mesh
		elif visual is MultiMeshInstance3D and visual.multimesh != null:
			mesh = visual.multimesh.mesh
			instances = visual.multimesh.instance_count if visual.multimesh.visible_instance_count < 0 else visual.multimesh.visible_instance_count
			clone = MultiMeshInstance3D.new()
			clone.multimesh = visual.multimesh
		else: continue
		content.add_child(clone)
		clone.transform = source.global_transform.affine_inverse() * visual.global_transform
		var box: AABB = clone.transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		var materials: Array[Material] = []
		for surface in mesh.get_surface_count():
			source_surfaces += 1
			source_triangles += BUILDER.new()._triangle_count(mesh.surface_get_arrays(surface)) * instances
			materials.append(visual.get_active_material(surface) if visual is MeshInstance3D else visual.material_override)
		copies.append({"node": clone, "materials": materials})
	assert(is_park or source_triangles <= 10000, "Complete POI exceeds 10,000-triangle budget: " + path)
	var boxes: Array = BUILDER.new()._read_boxes(source, false)
	if path.begins_with("ParkingGarage"):
		var dimensions: Vector3 = source.get_dimensions()
		boxes = [AABB(Vector3(-dimensions.x * 0.5, 0, -27), dimensions)]
		# The long entrance alley is ground, not a full-height extension of the garage.
		boxes.append(AABB(bounds.position, Vector3(bounds.size.x, 0.35, bounds.size.z)))
	elif is_park:
		var ground := source.get_node("Terrain/Ground/MeshInstance3D") as MeshInstance3D
		bounds = source.global_transform.affine_inverse() * ground.global_transform * ground.get_aabb()
		# Boundary elevation avoids floating the whole park at the height of its hills.
		boxes.clear()
	else:
		# Retain broad thin slabs/grounds, but not every bench, railing and bollard.
		for collider: CollisionShape3D in source.find_children("*", "CollisionShape3D", true, false):
			if not collider.shape is BoxShape3D: continue
			var size: Vector3 = collider.shape.size
			if size.y >= 2 or size.x < 4 or size.z < 4: continue
			boxes.append(source.global_transform.affine_inverse() * collider.global_transform * AABB(-size * 0.5, size))
	var albedo := Image.create(tile if is_park else tile * 3, tile if is_park else tile * 2, false, Image.FORMAT_RGBA8)
	albedo.fill(Color(0, 0, 0, 0))
	var emission := Image.create(1 if is_park else tile * 3, 1 if is_park else tile * 2, false, Image.FORMAT_RGBA8)
	emission.fill(Color.BLACK)
	for side in NORMALS.size():
		if is_park and side != 4:
			views.append({})
			continue
		var n: Vector3 = NORMALS[side]
		var up := Vector3.FORWARD if side == 4 else Vector3.UP
		var right := up.cross(n)
		var span := maxf(absf(bounds.size.dot(right)), absf(bounds.size.dot(up))) * 1.02
		var centre := bounds.get_center()
		views.append({"right": right, "up": up, "span": span, "centre": centre})
		camera.size = span
		camera.position = centre + n * (bounds.size.length() + 10.0)
		camera.look_at(centre, up)
		for night in [false, true]:
			if night and is_park: continue
			for pair in copies:
				for s in pair.materials.size():
					var material := _bake_material(pair.materials[s], night)
					if pair.node is MeshInstance3D: pair.node.set_surface_override_material(s, material)
					else: pair.node.material_override = material
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			(emission if night else albedo).blit_rect(image, Rect2i(0, 0, tile, tile), Vector2i.ZERO if is_park else Vector2i(side % 3 * tile, side / 3 * tile))
	if build_custom_geometry(source, path, bounds):
		pass
	elif is_park:
		var p := bounds.position
		var e := bounds.end
		var y := 0.05
		_quad([Vector3(p.x,y,e.z), Vector3(e.x,y,e.z), Vector3(e.x,y,p.z), Vector3(p.x,y,p.z)], Vector3.UP, 4)
	else:
		for box: AABB in boxes: _box(box)
		if path == "CityHall":
			# Low-sided drums and domes preserve the civic silhouette, with new geometry.
			_dome(Vector3(0,58.4,3), Vector3(14.4,14,14.4), 16, 4)
			_cylinder(Vector3(0,44.5,3), 13.5, 13.9, 16)
			_cylinder(Vector3(0,72.4,3), 2.8, 5.6, 8)
			for x in [-64.0,64.0]:
				_cylinder(Vector3(x,39,1), 9.0, 2, 12)
				_dome(Vector3(x,41,1), Vector3(9.4,4.8,9.4), 12, 3)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = load(proxy_shader_path)
	var name := str(source.name)
	albedo.save_png(output_dir + name + "_facade.png")
	emission.save_png(output_dir + name + "_night.png")
	albedo.generate_mipmaps()
	emission.generate_mipmaps()
	material.set_shader_parameter("facade", ImageTexture.create_from_image(albedo))
	material.set_shader_parameter("night_facade", ImageTexture.create_from_image(emission))
	mesh.surface_set_material(0, material)
	var mesh_path := output_dir + name + ".res"
	assert(ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS) == OK)
	var record := {"path": path, "mesh": mesh_path, "bounds_position": _list(bounds.position), "bounds_size": _list(bounds.size), "source_triangles": source_triangles, "proxy_triangles": indices.size()/3, "source_surfaces": source_surfaces, "proxy_surfaces": mesh.get_surface_count()}
	print(JSON.stringify(record))
	content.free()
	return record

func include_visual(_source: Node3D, _visual: GeometryInstance3D) -> bool:
	return true

func build_custom_geometry(_source: Node3D, _path: String, _bounds: AABB) -> bool:
	return false

func _list(v: Vector3) -> Array: return [v.x, v.y, v.z]

func _quad(points: Array, normal: Vector3, side: int) -> void:
	var offset := vertices.size()
	var view: Dictionary = views[side]
	for p: Vector3 in points:
		vertices.append(p)
		normals.append(normal)
		var local: Vector3 = p - view.centre
		var uv := Vector2(0.5 + local.dot(view.right) / view.span, 0.5 - local.dot(view.up) / view.span)
		uvs.append(uv if single_view else (uv + Vector2(side % 3, side / 3)) / Vector2(3, 2))
	indices.append_array(PackedInt32Array([offset,offset+2,offset+1,offset,offset+3,offset+2]))

func _box(box: AABB) -> void:
	for side in NORMALS.size():
		var n: Vector3 = NORMALS[side]
		var u: Vector3 = views[side].right
		var v: Vector3 = views[side].up
		var mid := box.get_center() + n * box.size * 0.5
		var a := u * absf(u.dot(box.size)) * 0.5
		var b := v * absf(v.dot(box.size)) * 0.5
		_quad([mid-a-b, mid+a-b, mid+a+b, mid-a+b], n, side)

func _round_quad(points: Array) -> void:
	var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
	var side := 0
	for i in NORMALS.size():
		if NORMALS[i].dot(normal) > NORMALS[side].dot(normal): side = i
	_quad(points, normal, side)

func _cylinder(base: Vector3, radius: float, height: float, sides: int) -> void:
	for i in sides:
		var a := base + Vector3(cos(TAU*i/sides),0,sin(TAU*i/sides))*radius
		var b := base + Vector3(cos(TAU*(i+1)/sides),0,sin(TAU*(i+1)/sides))*radius
		_round_quad([b,a,a+Vector3.UP*height,b+Vector3.UP*height])
		_quad([base+Vector3.UP*height,b+Vector3.UP*height,a+Vector3.UP*height,base+Vector3.UP*height],Vector3.UP,4)

func _dome(base: Vector3, size: Vector3, sides: int, rings: int) -> void:
	for ring in rings:
		var a := PI*0.5*ring/rings
		var b := PI*0.5*(ring+1)/rings
		for i in sides:
			var p := []
			for pair in [[i+1,a],[i,a],[i,b],[i+1,b]]:
				var angle: float = TAU*pair[0]/sides
				p.append(base + Vector3(cos(angle)*cos(pair[1]), sin(pair[1]), sin(angle)*cos(pair[1]))*size)
			_round_quad(p)

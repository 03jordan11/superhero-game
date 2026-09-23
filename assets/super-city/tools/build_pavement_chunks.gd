extends SceneTree
## Bake Main's final road and sidewalk placements. Never rewrites source modules.
const RUNTIME = preload("res://scripts/pavement_chunks.gd")
const OUT := RUNTIME.OUT
var styles: Array[Array] = []
var near_material: ShaderMaterial
var far_material: ShaderMaterial

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Pavement bake timed out"); quit(1))
	paused = true
	DirAccess.make_dir_recursive_absolute(OUT)
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	var city: Node3D = world.get_node("SuperCity")
	if city.has_node("PavementChunks"): city.get_node("PavementChunks").free()
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	root.add_child(world)
	await process_frame
	await process_frame
	var data := {"sources":RUNTIME.snapshot(city), "source_hashes":{}, "chunks":[], "source_meshes":0, "source_surfaces":0, "near_triangles":0, "far_triangles":0}
	var cells := {}
	for mesh in RUNTIME.source_meshes(city):
		if not RUNTIME.POSE.authored_visible(mesh, city): continue
		var pose := RUNTIME.POSE.pose_in(mesh, city)
		var center := (pose * mesh.get_aabb()).get_center()
		var key := Vector2i(floori(center.x / 500.0), floori(center.z / 500.0))
		if not cells.has(key): cells[key] = []
		cells[key].append(mesh)
		data.source_meshes += 1
		data.source_surfaces += mesh.mesh.get_surface_count()
		for i in mesh.mesh.get_surface_count():
			var settings := RUNTIME.material_settings(mesh.get_active_material(i))
			if not styles.has(settings): styles.append(settings)
	make_materials()
	for path in [RUNTIME.ROAD_SHADER, RUNTIME.SIDEWALK_SHADER]:
		data.source_hashes[path] = str(hash((load(path) as Shader).code))
	var baked := Node3D.new()
	baked.name = "PavementChunks"
	baked.set_script(RUNTIME)
	for key: Vector2i in cells:
		var chunk := Node3D.new()
		chunk.name = "Grid_%s_%s" % [key.x, key.y]
		chunk.position = Vector3(key.x * 500.0, 0, key.y * 500.0)
		chunk.visible = false
		baked.add_child(chunk)
		chunk.owner = baked
		var near := surface()
		var far := surface()
		var paths: Array[String] = []
		for mesh: MeshInstance3D in cells[key]:
			var pose := RUNTIME.POSE.pose_in(mesh, city)
			pose.origin -= chunk.position
			append(near, far, mesh, pose)
			paths.append(str(city.get_path_to(mesh)))
		var full := save_mesh(near, near_material, "FullDetail", chunk, baked)
		var distant := save_mesh(far, far_material, "DistantProxy", chunk, baked)
		var near_count := full.mesh.get_faces().size() / 3
		var far_count := distant.mesh.get_faces().size() / 3
		data.near_triangles += near_count
		data.far_triangles += far_count
		data.chunks.append({"name":str(chunk.name), "sources":paths, "near_triangles":near_count, "far_triangles":far_count})
	var packed := PackedScene.new()
	assert(packed.pack(baked) == OK)
	assert(ResourceSaver.save(packed, OUT + "pavement_chunks.tscn") == OK)
	FileAccess.open(OUT + "inventory.json", FileAccess.WRITE).store_string(JSON.stringify(data, "\t"))
	print("PAVEMENT: %d meshes / %d surfaces -> %d chunks, one surface each at either LOD; triangles %d near / %d far; %d road styles" % [data.source_meshes, data.source_surfaces, data.chunks.size(), data.near_triangles, data.far_triangles, styles.size()])
	baked.free()
	world.free()
	quit()

func surface() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func append(near: SurfaceTool, far: SurfaceTool, node: MeshInstance3D, pose: Transform3D) -> void:
	var normal_pose := pose.basis.inverse().transposed()
	var axis := Vector2(pose.basis.x.x, pose.basis.x.z).normalized().abs()
	for surface_index in node.mesh.get_surface_count():
		var mat := node.get_active_material(surface_index)
		var kind := RUNTIME.material_kind(mat)
		var style := styles.find(RUNTIME.material_settings(mat))
		assert(style >= 0 and style < 65536)
		var color := Color(float(style % 256) / 255.0, float(style / 256) / 255.0, 0, 1)
		var arrays := node.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv := PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] != null: uv = arrays[Mesh.ARRAY_TEX_UV]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for triangle in range(0, indices.size(), 3):
			var top := true
			for corner in 3:
				if (normal_pose * normals[indices[triangle + corner]]).normalized().y < 0.99: top = false
			for corner in 3:
				var i := indices[triangle + corner]
				var texcoord := uv[i] if kind == 2 else Vector2(vertices[i].x, vertices[i].z)
				for tool in [near, far] if top else [near]:
					tool.set_normal((normal_pose * normals[i]).normalized())
					tool.set_color(color)
					tool.set_uv(texcoord)
					tool.set_uv2(axis)
					tool.add_vertex(pose * vertices[i])

func save_mesh(tool: SurfaceTool, mat: Material, label: String, chunk: Node3D, owner_node: Node3D) -> MeshInstance3D:
	tool.set_material(mat)
	tool.index()
	var mesh := tool.commit()
	assert(mesh != null and mesh.get_surface_count() == 1)
	var path := OUT + str(chunk.name) + "_" + label + ".res"
	assert(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) == OK)
	mesh.take_over_path(path)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	# Flat ground never needs its own shadow-map submission.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(node)
	node.owner = owner_node
	return node

func make_materials() -> void:
	var table := Image.create(3, styles.size(), false, Image.FORMAT_RGBAF)
	var asphalt: Texture2D
	for i in styles.size():
		var values := styles[i]
		var kind: int = values[0]
		if kind == 0:
			table.set_pixel(0, i, Color(values[1], values[2], values[3], values[4]))
			table.set_pixel(1, i, Color(float(values[5]), values[6], values[7], int(values[8]) + 2 * int(values[9])))
			var texture: Texture2D = load(values[10])
			assert(asphalt == null or asphalt == texture)
			asphalt = texture
		elif kind == 1:
			assert(values[2] == "res://assets/super-city/textures/sidewalk.res")
		else:
			assert(values[2] == Color.WHITE and values[3] == Vector3.ONE)
		table.set_pixel(2, i, Color(kind, float(values[1]) if kind == 1 else 4.0, 0, 0))
	var texture := ImageTexture.create_from_image(table)
	assert(ResourceSaver.save(texture, OUT + "road_parameters.res") == OK)
	texture.take_over_path(OUT + "road_parameters.res")
	generate_shader()
	near_material = ShaderMaterial.new()
	near_material.shader = load(OUT + "pavement.gdshader")
	near_material.set_shader_parameter("parameters", texture)
	near_material.set_shader_parameter("asphalt", asphalt)
	near_material.set_shader_parameter("paving", load("res://assets/super-city/textures/sidewalk.res"))
	near_material.set_shader_parameter("legacy_road", load("res://assets/super-city/textures/road_6m.res"))
	far_material = near_material.duplicate()
	far_material.set_shader_parameter("distant_detail", true)
	for row in [[near_material, "near.tres"], [far_material, "far.tres"]]:
		assert(ResourceSaver.save(row[0], OUT + row[1]) == OK)
		row[0].take_over_path(OUT + row[1])

func generate_shader() -> void:
	# Reuse the exact authored lane/crosswalk logic; only its parameter source changes.
	var original := FileAccess.get_file_as_string(RUNTIME.ROAD_SHADER).replace("\r\n", "\n")
	var functions := original.substr(original.find("// Physical metres"))
	functions = functions.replace("void fragment() {", "vec3 road_albedo() {\n\tfloat width_m = settings_a.x;\n\tfloat cross_width_m = settings_a.y;\n\tfloat length_m = settings_a.z;\n\tfloat dash_offset_m = settings_a.w;\n\tbool junction = settings_b.x > 0.5;\n\tint arms = int(round(settings_b.y));\n\tint crosswalks = int(round(settings_b.z));\n\tint flags = int(round(settings_b.w));\n\tbool crossing_north = (flags & 1) != 0;\n\tbool crossing_south = (flags & 2) != 0;")
	functions = functions.replace("\tALBEDO = base;\n\tROUGHNESS = 0.98;", "\treturn base;")
	var header := """shader_type spatial;
// Generated by build_pavement_chunks.gd from the modular road shader.
uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D legacy_road : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D parameters : filter_nearest, repeat_disable;
uniform bool distant_detail = false;
varying vec3 local_position;
varying vec3 world_position;
varying vec2 marking_position;
varying float top_face;
varying flat vec4 settings_a;
varying flat vec4 settings_b;
varying flat vec2 surface_kind;
void vertex() {
	int row = int(round(COLOR.r * 255.0)) + 256 * int(round(COLOR.g * 255.0));
	settings_a = texelFetch(parameters, ivec2(0, row), 0);
	settings_b = texelFetch(parameters, ivec2(1, row), 0);
	surface_kind = texelFetch(parameters, ivec2(2, row), 0).rg;
	local_position = vec3(UV.x, 0.0, UV.y);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	marking_position = vec2(dot(world_position.xz, UV2), dot(world_position.xz, UV2.yx));
	top_face = max(NORMAL.y, 0.0);
}
"""
	var fragment := """
void fragment() {
	if (surface_kind.x > 1.5) {
		ALBEDO = texture(legacy_road, UV).rgb;
	} else if (surface_kind.x > 0.5) {
		ALBEDO = texture(paving, world_position.xz / surface_kind.y).rgb;
	} else if (distant_detail) {
		ALBEDO = texture(asphalt, world_position.xz / 4.0).rgb;
	} else {
		ALBEDO = road_albedo();
	}
	ROUGHNESS = 0.98;
}
"""
	FileAccess.open(OUT + "pavement.gdshader", FileAccess.WRITE).store_string(header + functions + fragment)

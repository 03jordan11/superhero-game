extends Node3D
## Baked city road/sidewalk visuals only; authored modules retain physics and sockets.
const OUT := "res://assets/super-city/pavement_chunks/"
const ROAD_SHADER := "res://assets/super-city/modular-roads/road.gdshader"
const SIDEWALK_SHADER := "res://assets/super-city/modular-sidewalks/sidewalk.gdshader"
const ROAD_PARAMETERS := ["width_m", "cross_width_m", "length_m", "dash_offset_m", "junction", "arms", "crosswalks", "crossing_north", "crossing_south"]
const POSE = preload("res://scripts/riverbank_chunks.gd")
@export var enabled := true:
	set(value):
		enabled = value
		if prepared: _apply_enabled()
@export_enum("Automatic", "Full detail", "Distant proxies") var force_lod := 0
@export_range(25, 1000, 25, "suffix:m") var near_distance_m := 300.0
@export_range(0, 150, 5, "suffix:m") var switching_margin_m := 50.0
var prepared := false
var valid_bake := false
var prepared_chunks := 0
var total_chunks := 0
var sources: Array[MeshInstance3D] = []
var flags: Array[bool] = []
var entries: Array[Dictionary] = []
var _elapsed := 0.0

static func source_meshes(city: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for group in ["Roads", "Sidewalks"]:
		for mesh: MeshInstance3D in city.get_node(group).find_children("*", "MeshInstance3D", true, false):
			if group == "Sidewalks" and not mesh.get_parent().has_meta("sidewalk_module"): continue
			# Parking lots and embedded POIs have their own materials/proxies.
			var supported := mesh.mesh != null
			if supported:
				for i in mesh.mesh.get_surface_count():
					if material_kind(mesh.get_active_material(i)) < 0: supported = false
			if supported: result.append(mesh)
	return result

static func material_kind(mat: Material) -> int:
	if mat is ShaderMaterial:
		if mat.shader.resource_path == ROAD_SHADER: return 0
		if mat.shader.resource_path == SIDEWALK_SHADER: return 1
	elif mat is StandardMaterial3D and mat.resource_path == "res://assets/super-city/materials/road_6m.tres": return 2
	return -1

static func material_settings(mat: Material) -> Array:
	var kind := material_kind(mat)
	var values: Array = [kind]
	if kind == 0:
		for key in ROAD_PARAMETERS: values.append(mat.get_shader_parameter(key))
		values.append(mat.get_shader_parameter("asphalt").resource_path)
	elif kind == 1:
		values.append(mat.get_shader_parameter("tile_size"))
		values.append(mat.get_shader_parameter("paving").resource_path)
	elif kind == 2:
		values.append(mat.albedo_texture.resource_path)
		values.append(mat.albedo_color)
		values.append(mat.uv1_scale)
	return values

static func snapshot(city: Node3D) -> Dictionary:
	var result := {}
	for mesh in source_meshes(city):
		var row := {"visible": POSE.authored_visible(mesh, city)}
		if row.visible:
			row.transform = var_to_str(POSE.pose_in(mesh, city))
			var surfaces: Array = []
			for i in mesh.mesh.get_surface_count():
				surfaces.append([hash(mesh.mesh.surface_get_arrays(i)), material_settings(mesh.get_active_material(i))])
			row.surfaces = var_to_str(surfaces)
		result[str(city.get_path_to(mesh))] = row
	return result

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")
	_wait_for_modules.call_deferred()

func _wait_for_modules() -> void:
	# Bound callbacks disconnect if fast travel unloads the city during setup.
	get_tree().process_frame.connect(_wait_one_more_frame, CONNECT_ONE_SHOT)

func _wait_one_more_frame() -> void:
	get_tree().process_frame.connect(_prepare, CONNECT_ONE_SHOT)

func _prepare() -> void:
	# @tool road and sidewalk modules have finished their deferred rebuilds.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "inventory.json"))
	var city := get_parent() as Node3D
	valid_bake = JSON.stringify(snapshot(city), "", true) == JSON.stringify(data.sources, "", true)
	for path: String in data.source_hashes:
		# ResourceLoader also resolves shaders converted/remapped in exported builds.
		if str(hash((load(path) as Shader).code)) != data.source_hashes[path]: valid_bake = false
	total_chunks = data.chunks.size()
	for path: String in data.sources:
		if not data.sources[path].visible: continue
		var mesh := city.get_node_or_null(NodePath(path)) as MeshInstance3D
		if mesh == null: continue
		sources.append(mesh)
		flags.append(mesh.visible)
	for record: Dictionary in data.chunks:
		var chunk := get_node(NodePath(record.name)) as Node3D
		var near := chunk.get_node("FullDetail") as MeshInstance3D
		var far := chunk.get_node("DistantProxy") as MeshInstance3D
		entries.append({"node":chunk, "near":near, "far":far, "bounds":chunk.transform * near.get_aabb(), "state":-1})
		prepared_chunks += 1
	prepared = true
	if not valid_bake: push_warning("Pavement bake is stale; originals retained. Run assets/super-city/tools/build_pavement_chunks.gd")
	_apply_enabled()

func _apply_enabled() -> void:
	for i in sources.size(): sources[i].visible = false if enabled and valid_bake else flags[i]
	for entry in entries:
		entry.node.visible = false
		entry.state = -1
	update_visibility()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.1: return
	_elapsed = 0.0
	update_visibility()

func update_visibility() -> void:
	if not prepared or not enabled or not valid_bake: return
	var camera := get_viewport().get_camera_3d()
	for entry in entries:
		var state := 0
		if force_lod != 0: state = force_lod - 1
		elif camera != null:
			var box: AABB = global_transform * entry.bounds
			var distance := camera.global_position.distance_to(camera.global_position.clamp(box.position, box.end))
			state = 1 if distance > near_distance_m + (0.0 if entry.state == 1 else switching_margin_m) else 0
		if entry.state == state: continue
		entry.state = state
		entry.node.visible = true
		entry.near.visible = state == 0
		entry.far.visible = state == 1

func _exit_tree() -> void:
	for i in sources.size():
		if is_instance_valid(sources[i]): sources[i].visible = flags[i]

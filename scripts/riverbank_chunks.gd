extends Node3D
## Offline meshes replace visuals only. Original collisions and lights stay active.
const INVENTORY := "res://assets/waterfront/chunks/inventory.json"
@export var enabled := true:
	set(value):
		enabled = value
		if prepared: _apply_enabled()
@export_enum("Automatic", "Full detail", "Distant proxies") var force_lod := 0
@export_range(25,1000,25,"suffix:m") var near_distance_m := 300.0
@export_range(0,150,5,"suffix:m") var switching_margin_m := 50.0
var prepared := false
var valid_bake := false
var prepared_chunks := 0
var total_chunks := 0
var entries: Array[Dictionary] = []
var sources: Array[MeshInstance3D] = []
var flags: Array[bool] = []
var _material: ShaderMaterial
var _elapsed := 0.0

static func pose_in(node: Node3D, region: Node3D) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent != region:
		if parent is Node3D: pose = parent.transform*pose
		parent = parent.get_parent()
	return pose

static func authored_visible(node: Node3D, region: Node3D) -> bool:
	while node != region:
		if not node.visible: return false
		node = node.get_parent() as Node3D
	return true

static func snapshot(region: Node3D) -> Dictionary:
	var rows := {}
	for mesh: MeshInstance3D in region.find_children("*","MeshInstance3D",true,false):
		if str(region.get_path_to(mesh)).begins_with("RiverbankChunks/"): continue
		var visible_source := authored_visible(mesh,region)
		var row := {"visible":visible_source}
		if visible_source:
			row.transform = var_to_str(pose_in(mesh,region))
			row.geometry = str(hash(mesh.mesh.get_faces()))
			var mat := mesh.get_active_material(0) as StandardMaterial3D
			if mat == null: return {} # Unsupported edited material: keep originals.
			row.material = var_to_str([mat.albedo_color,mat.roughness,mat.metallic,mat.emission,
				mat.get_meta("night_glow",0.0),mat.albedo_texture,mat.transparency])
		rows[str(region.get_path_to(mesh))] = row
	return rows

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")
	_prepare.call_deferred()

func _prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY))
	var region := get_parent() as Node3D
	valid_bake = JSON.stringify(snapshot(region),"",true) == JSON.stringify(data.sources,"",true)
	total_chunks = data.chunks.size()
	for path: String in data.sources:
		if not data.sources[path].visible: continue
		var source := region.get_node_or_null(NodePath(path)) as MeshInstance3D
		if source == null: continue
		sources.append(source)
		flags.append(source.visible)
	for record: Dictionary in data.chunks:
		var chunk := get_node(NodePath(record.name)) as Node3D
		var near := chunk.get_node("FullDetail") as MeshInstance3D
		var far := chunk.get_node("DistantProxy") as MeshInstance3D
		if _material == null: _material = near.mesh.surface_get_material(0).duplicate()
		near.material_override = _material
		far.material_override = _material
		entries.append({"node":chunk,"near":near,"far":far,"bounds":chunk.transform*near.get_aabb(),"state":-1})
		prepared_chunks += 1
	prepared = true
	if not valid_bake: push_warning("Riverbank bake is stale; originals retained. Run assets/waterfront/tools/build_riverbank_chunks.gd")
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
	var waterfront := get_parent().get_parent()
	# Same clock amount and brightness as the original lamp lenses, including pause.
	_material.set_shader_parameter("night_amount",waterfront._night*waterfront.night_light_brightness)
	var camera := get_viewport().get_camera_3d()
	for entry in entries:
		var state := 0 # A missing camera keeps full detail visible.
		if force_lod != 0:
			state = force_lod-1
		elif camera != null:
			var box: AABB = global_transform*entry.bounds
			var distance := camera.global_position.distance_to(camera.global_position.clamp(box.position,box.end))
			state = 1 if distance > near_distance_m+(0.0 if entry.state == 1 else switching_margin_m) else 0
		if entry.state == state: continue
		entry.state = state
		entry.node.visible = true
		entry.near.visible = state == 0
		entry.far.visible = state == 1

func _exit_tree() -> void:
	for i in sources.size():
		if is_instance_valid(sources[i]): sources[i].visible = flags[i]

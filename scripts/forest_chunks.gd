extends Node3D
## Authored trees stay editable; only baked chunk meshes render during play.
@export_file("*.json") var inventory_path := ""
@export var enabled := true:
	set(value):
		enabled = value
		if prepared: _apply_enabled()
@export_enum("Automatic", "Full detail", "Distant proxies") var force_lod := 0
@export_range(25.0,1000.0,25.0,"suffix:m") var near_distance_m := 300.0
@export_range(0.0,150.0,5.0,"suffix:m") var switching_margin_m := 50.0
## Zero retains the source trees' authored distance limits.
@export_range(0.0,12000.0,100.0,"suffix:m") var max_distance_m := 0.0
var prepared := false
var prepared_chunks := 0
var total_chunks := 0
var entries: Array[Dictionary] = []
var valid_bake := false
var _elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")
	_prepare.call_deferred()

func _prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
	total_chunks = data.chunks.size()
	var region := get_parent() as Node3D
	var current_trees := 0
	for tree in region.find_children("*","MeshInstance3D",true,false):
		if tree.scene_file_path in data.tree_scenes: current_trees += 1
	valid_bake = current_trees == int(data.tree_count)
	for path: String in data.authored_visibility:
		var source := region.get_node_or_null(NodePath(path)) as Node3D
		valid_bake = valid_bake and source != null and source.visible == bool(data.authored_visibility[path])
	for path: String in data.source_hashes:
		valid_bake = valid_bake and FileAccess.get_sha256(path) == data.source_hashes[path]
	for record: Dictionary in data.chunks:
		var sources: Array[MeshInstance3D] = []
		var flags: Array[bool] = []
		for row: Dictionary in record.sources:
			var tree := region.get_node_or_null(NodePath(row.path)) as MeshInstance3D
			if tree == null:
				valid_bake = false
				continue
			var pose := region.global_transform.affine_inverse()*tree.global_transform
			var expected: Transform3D = str_to_var(row.transform)
			valid_bake = valid_bake and pose.is_equal_approx(expected) and tree.visible == bool(row.visible)
			valid_bake = valid_bake and tree.mesh.resource_path == str(row.mesh)
			valid_bake = valid_bake and is_equal_approx(tree.visibility_range_end,float(row.visibility_end))
			sources.append(tree)
			flags.append(tree.visible)
		var chunk := get_node(NodePath(record.name)) as Node3D
		var bounds := AABB(_vector(record.bounds_position),_vector(record.bounds_size))
		entries.append({"node":chunk,"near":chunk.get_node("FullDetail"),"far":chunk.get_node("DistantProxy"),
			"sources":sources,"flags":flags,"bounds":bounds,"limit":float(record.visibility_end),"state":-1})
		prepared_chunks += 1
	prepared = true
	if not valid_bake: push_warning("Forest bake is stale; keeping editable trees visible. Rebuild assets/trees/tools/build_forest_chunks.gd: "+inventory_path)
	_apply_enabled()

func _vector(row: Array) -> Vector3: return Vector3(row[0],row[1],row[2])

func _apply_enabled() -> void:
	for entry in entries:
		for i in entry.sources.size():
			if is_instance_valid(entry.sources[i]): entry.sources[i].visible = false if enabled and valid_bake else entry.flags[i]
		entry.node.visible = false
		entry.state = -1
	if enabled and valid_bake: update_visibility()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.1: return
	_elapsed = 0.0
	update_visibility()

func update_visibility() -> void:
	if not prepared or not enabled or not valid_bake: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var region := get_parent() as Node3D
	for entry in entries:
		var box: AABB = region.global_transform * entry.bounds
		var closest := camera.global_position.clamp(box.position,box.end)
		var distance := camera.global_position.distance_to(closest)
		var limit: float = max_distance_m if max_distance_m > 0.0 else entry.limit
		var state := 0
		if limit > 0.0 and distance > limit:
			state = 2
		elif force_lod != 0:
			state = force_lod-1
		else:
			var threshold := near_distance_m + (0.0 if entry.state == 1 else switching_margin_m)
			state = 1 if distance > threshold else 0
		if entry.state == state: continue
		entry.state = state
		entry.node.visible = state != 2
		entry.near.visible = state == 0
		entry.far.visible = state == 1

func _exit_tree() -> void:
	for entry in entries:
		for i in entry.sources.size():
			if is_instance_valid(entry.sources[i]): entry.sources[i].visible = entry.flags[i]

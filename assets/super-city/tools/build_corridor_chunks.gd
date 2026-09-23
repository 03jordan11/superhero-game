extends SceneTree
## Offline grouping for the captured east-facing Z=-480 road, west of the river.
## Saves only the chunk scene/manifest; never repacks or moves source buildings.
const OUTPUT := "res://assets/super-city/chunks/"
const CHUNK_SCRIPT := preload("res://scripts/city_building_chunk.gd")
const LENGTH := 250.0
const START_X := -1500.0
const END_X := 100.0 # End of this connected road at the western riverbank.
const ROAD_Z := -480.0
var city: Node3D

func _initialize() -> void:
	build.call_deferred()

func relative(node: Node3D) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != city:
		if parent is Node3D: transform = parent.transform * transform
		parent = parent.get_parent()
	return transform

func shown(node: Node) -> bool:
	while node != city:
		if node is Node3D and not node.visible: return false
		node = node.get_parent()
	return true

func is_building_root(node: Node) -> bool:
	if not node.scene_file_path.begins_with("res://assets/buildings/"): return false
	var parent := node.get_parent()
	while parent != city:
		if parent.scene_file_path.begins_with("res://assets/buildings/"): return false
		parent = parent.get_parent()
	return true

func mesh_bounds(building: Node3D) -> AABB:
	var bounds := AABB()
	var started := false
	for mesh in building.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not shown(mesh): continue
		var box: AABB = relative(mesh) * mesh.get_aabb()
		bounds = bounds.merge(box) if started else box
		started = true
	return bounds

func vector(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

func build() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	city = main.get_node("SuperCity")
	var candidates: Array[Node3D] = []
	for district in city.get_node("Districts").get_children():
		for building in district.get_children():
			if building.get_node_or_null("MeshInstance3D") is MeshInstance3D:
				candidates.append(building)
	for node in city.find_children("*", "Node3D", true, false):
		if is_building_root(node) and node != city.get_node("CityHall"):
			candidates.append(node)
	candidates.sort_custom(func(a: Node, b: Node) -> bool: return str(city.get_path_to(a)) < str(city.get_path_to(b)))
	var sections := {}
	for building in candidates:
		if not shown(building): continue
		var bounds := mesh_bounds(building)
		if not bounds.has_volume(): continue
		var centre := bounds.get_center()
		if centre.x < START_X or centre.x >= END_X or centre.z < ROAD_Z - LENGTH or centre.z >= ROAD_Z + LENGTH: continue
		var side := "Left" if centre.z < ROAD_Z else "Right"
		var index := floori((centre.x - START_X) / LENGTH)
		var key := "%s_%02d" % [side, index + 1]
		if not sections.has(key): sections[key] = {"side": side, "index": index, "members": [], "bounds": bounds}
		sections[key].members.append(str(city.get_path_to(building)))
		sections[key].bounds = sections[key].bounds.merge(bounds)
	var root_node := Node3D.new()
	root_node.name = "CorridorBuildingChunks"
	root_node.set_script(preload("res://scripts/corridor_hlod.gd"))
	root_node.set_meta("corridor_axis", "+X, Z=-480; left=-Z, right=+Z")
	root_node.set_meta("chunk_length_m", LENGTH)
	root_node.set_meta("lod_status", "Simplified distant proxies: one mesh, one surface per chunk")
	var manifest := {"road_z": ROAD_Z, "start_x": START_X, "end_x": END_X, "cell_size_m": LENGTH, "excluded": ["CityHall"], "assignment": "Whole building by authored visible mesh-bounds centre; original paths preserved", "chunks": []}
	var total := 0
	for side in ["Left", "Right"]:
		var side_node := Node3D.new()
		side_node.name = side
		root_node.add_child(side_node)
		side_node.owner = root_node
		for index in ceili((END_X - START_X) / LENGTH):
			var key := "%s_%02d" % [side, index + 1]
			if not sections.has(key): continue
			var section: Dictionary = sections[key]
			var chunk := Node3D.new()
			chunk.set_script(CHUNK_SCRIPT)
			chunk.name = key
			chunk.position = Vector3(START_X + (index + 0.5) * LENGTH, 0.0, ROAD_Z + (-0.5 if side == "Left" else 0.5) * LENGTH)
			var paths: Array[NodePath] = []
			for path: String in section.members: paths.append(NodePath("../../../" + path))
			chunk.building_paths = paths
			chunk.source_bounds = AABB(section.bounds.position - chunk.position, section.bounds.size)
			side_node.add_child(chunk)
			chunk.owner = root_node
			manifest.chunks.append({"name": key, "side": side, "index": index + 1, "centre": vector(chunk.position), "cell": [chunk.position.x - LENGTH / 2, chunk.position.z - LENGTH / 2, LENGTH, LENGTH], "bounds_position": vector(section.bounds.position), "bounds_size": vector(section.bounds.size), "members": section.members})
			total += paths.size()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var packed := PackedScene.new()
	var result := packed.pack(root_node)
	if result == OK: result = ResourceSaver.save(packed, OUTPUT + "corridor_chunks.tscn")
	if result != OK:
		push_error("Could not save corridor chunks: " + error_string(result))
		root_node.free()
		main.free()
		quit(1)
		return
	FileAccess.open(OUTPUT + "corridor_chunks.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t") + "\n")
	print("CORRIDOR_CHUNKS: %d chunks, %d whole buildings; CityHall excluded" % [manifest.chunks.size(), total])
	root_node.free()
	main.free()
	quit()

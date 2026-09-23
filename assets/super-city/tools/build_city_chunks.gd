extends "res://assets/super-city/tools/build_corridor_chunks.gd"
## Offline 500 m grid over every ordinary city building. POIs are excluded.
const CITY_CELL := 500.0

func eligible(node: Node) -> bool:
	if not node.scene_file_path.begins_with("res://assets/generated-buildings/"): return false
	var parent := node.get_parent()
	while parent != city:
		if parent.scene_file_path.begins_with("res://assets/buildings/"): return false
		parent = parent.get_parent()
	return shown(node)

func build() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	city = main.get_node("SuperCity")
	var sections := {}
	var excluded := []
	var candidates: Array[Node] = city.find_children("*", "Node3D", true, false)
	candidates.sort_custom(func(a: Node, b: Node): return str(city.get_path_to(a)) < str(city.get_path_to(b)))
	for node in candidates:
		if is_building_root(node): excluded.append(str(city.get_path_to(node)))
		if not eligible(node): continue
		var bounds := mesh_bounds(node)
		if not bounds.has_volume(): continue
		var centre := bounds.get_center()
		var cell := Vector2i(floori(centre.x / CITY_CELL), floori(centre.z / CITY_CELL))
		if not sections.has(cell): sections[cell] = {"members": [], "bounds": bounds}
		sections[cell].members.append(str(city.get_path_to(node)))
		sections[cell].bounds = sections[cell].bounds.merge(bounds)
	var root_node := Node3D.new()
	root_node.name = "CityBuildingChunks"
	root_node.set_script(preload("res://scripts/corridor_hlod.gd"))
	root_node.set_meta("chunk_length_m", CITY_CELL)
	root_node.set_meta("lod_status", "City-wide 500 m simplified proxies; POIs excluded")
	var grid := Node3D.new()
	grid.name = "Grid"
	root_node.add_child(grid)
	grid.owner = root_node
	var manifest := {"cell_size_m": CITY_CELL, "scope": "All ordinary generated city buildings; POIs excluded", "excluded": excluded, "assignment": "Whole building by authored visible bounds centre; source paths unchanged", "chunks": []}
	var cells: Array = sections.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	var total := 0
	for cell: Vector2i in cells:
		var section: Dictionary = sections[cell]
		var chunk := Node3D.new()
		chunk.set_script(CHUNK_SCRIPT)
		chunk.name = "Cell_X%s_Z%s" % [str(cell.x).replace("-", "N"), str(cell.y).replace("-", "N")]
		chunk.position = Vector3((cell.x + 0.5) * CITY_CELL, 0, (cell.y + 0.5) * CITY_CELL)
		chunk.cell_size_m = Vector2(CITY_CELL, CITY_CELL)
		var paths: Array[NodePath] = []
		for path: String in section.members: paths.append(NodePath("../../../" + path))
		chunk.building_paths = paths
		chunk.source_bounds = AABB(section.bounds.position - chunk.position, section.bounds.size)
		grid.add_child(chunk)
		chunk.owner = root_node
		manifest.chunks.append({"name": str(chunk.name), "grid": [cell.x, cell.y], "centre": vector(chunk.position), "cell": [cell.x * CITY_CELL, cell.y * CITY_CELL, CITY_CELL, CITY_CELL], "bounds_position": vector(section.bounds.position), "bounds_size": vector(section.bounds.size), "members": section.members})
		total += paths.size()
	var packed := PackedScene.new()
	var error := packed.pack(root_node)
	if error == OK: error = ResourceSaver.save(packed, OUTPUT + "city_chunks.tscn")
	if error == OK:
		FileAccess.open(OUTPUT + "city_chunks.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t") + "\n")
		print("CITY_CHUNKS: %d chunks, %d ordinary buildings; %d POI roots excluded" % [cells.size(), total, excluded.size()])
	else: push_error("Cannot save city chunks: " + error_string(error))
	root_node.free()
	main.free()
	quit(0 if error == OK else 1)

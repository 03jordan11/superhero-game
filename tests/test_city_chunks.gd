extends "res://tests/test_corridor_chunks.gd"
## Validate city-wide coverage, 500 m cells, uniqueness and POI exclusion.
func run() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	city = main.get_node("SuperCity")
	var groups := city.get_node("CityBuildingChunks")
	check(city.get_node_or_null("CorridorBuildingChunks") == null, "Old corridor controller is not mounted alongside city proxies")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/chunks/city_chunks.json"))
	var members := {}
	var chunks := 0
	for row in groups.get_children():
		for chunk in row.get_children():
			chunks += 1
			check(chunk.cell_size_m == Vector2(500, 500), "500 m square cell")
			check(chunk.get_buildings().size() == chunk.building_paths.size(), "Every source path resolves")
			var entries: Array = manifest.chunks.filter(func(entry): return entry.name == str(chunk.name))
			check(entries.size() == 1, "One manifest record per chunk")
			var chunk_box: AABB = relative(chunk) * chunk.source_bounds
			for building: Node3D in chunk.get_buildings():
				var path := str(city.get_path_to(building))
				check(not members.has(path), "Unique building ownership: " + path)
				members[path] = true
				check(building.scene_file_path.begins_with("res://assets/generated-buildings/"), "POI never assigned to a proxy")
				check(path in entries[0].members, "Scene agrees with manifest")
				var bounds := AABB()
				var first := true
				for mesh in building.find_children("*", "MeshInstance3D", true, false):
					if mesh.mesh == null or not shown(mesh): continue
					var box: AABB = relative(mesh) * mesh.get_aabb()
					check(chunk_box.grow(0.01).encloses(box), "Chunk contains member geometry")
					bounds = box if first else bounds.merge(box)
					first = false
				var midpoint := bounds.get_center()
				check(absf(midpoint.x - chunk.position.x) <= 250 and absf(midpoint.z - chunk.position.z) <= 250, "Whole building lies in correct grid cell")
	check(chunks == manifest.chunks.size(), "All manifest chunks present")
	var expected := 0
	for node in city.find_children("*", "Node3D", true, false):
		if not node.scene_file_path.begins_with("res://assets/generated-buildings/") or not shown(node): continue
		var ancestor: Node = node.get_parent()
		var in_poi := false
		while ancestor != city:
			if ancestor.scene_file_path.begins_with("res://assets/buildings/"): in_poi = true
			ancestor = ancestor.get_parent()
		if in_poi: continue
		expected += 1
		check(members.has(str(city.get_path_to(node))), "Every ordinary building is covered")
	check(members.size() == expected and expected == 1955, "All 1,955 ordinary buildings covered exactly once")
	for path: String in manifest.excluded:
		check(city.get_node_or_null(path) != null, "Excluded POI remains at its original path")
		check(not members.has(path), "POI excluded: " + path)
	check(manifest.excluded.size() == 16, "All 16 POI roots excluded")
	main.free()
	print("CITY_CHUNKS_TEST: %d chunks, %d ordinary buildings, %d excluded POIs, %d failures" % [chunks, members.size(), manifest.excluded.size(), failures])
	quit(1 if failures else 0)

func shown(node: Node) -> bool:
	while node != city:
		if node is Node3D and not node.visible: return false
		node = node.get_parent()
	return true

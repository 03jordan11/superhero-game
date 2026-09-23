extends SceneTree
## Read-only map export of saved Main/SuperCity placements; never enters gameplay.
const DEST := "res://artifacts/city_planning_map/"
var city: Node3D
var buildings: Array = []
var roads: Array = []
var areas: Array = []
var landmarks: Array = []

func _initialize() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	city = main.get_node("SuperCity")
	for district in city.get_node("Districts").get_children():
		for building in district.get_children():
			if not shown(building): continue
			var mesh := building.get_node_or_null("MeshInstance3D") as MeshInstance3D
			if mesh == null or mesh.mesh == null: continue
			buildings.append([str(building.name), str(district.name), footprint(mesh), snappedf(mesh.get_aabb().size.y * relative(mesh).basis.y.length(), 0.1)])
	for node in city.find_children("*", "Node3D", true, false):
		if not shown(node): continue
		if node.has_method("road_rects"):
			for rect: Rect2 in node.road_rects():
				roads.append(rect_polygon(rect, relative(node)))
		if node.scene_file_path.begins_with("res://assets/buildings/") and not has_building_parent(node):
			var bounds := AABB()
			var started := false
			for mesh in node.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh == null or not shown(mesh): continue
				var box: AABB = relative(mesh) * mesh.get_aabb()
				bounds = bounds.merge(box) if started else box
				started = true
			if started:
				var polygon := rect_polygon(Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z), Transform3D.IDENTITY)
				buildings.append([str(node.name), "Landmark", polygon, snappedf(bounds.size.y, 0.1)])
				landmarks.append([str(node.name), snappedf(bounds.get_center().x, 0.1), snappedf(bounds.get_center().z, 0.1)])
	# Authored park and water geometry supplies geographic context.
	for path in ["Landmarks/CentralPark", "Waterfront/Water"]:
		var branch := city.get_node_or_null(path)
		if branch == null: continue
		for mesh in branch.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null or not shown(mesh): continue
			if path.contains("CentralPark") and str(branch.get_path_to(mesh)) != "Terrain/Ground/MeshInstance3D": continue
			if str(mesh.name) == "Seabed": continue
			if str(mesh.name) == "River":
				# Preserve the curved riverbanks instead of filling its rectangular bounds.
				var transform := relative(mesh)
				for surface in mesh.mesh.get_surface_count():
					var arrays: Array = mesh.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
					if indices.is_empty():
						for i in vertices.size(): indices.append(i)
					for i in range(0, indices.size(), 3):
						areas.append(["water", [point(transform * vertices[indices[i]]), point(transform * vertices[indices[i + 1]]), point(transform * vertices[indices[i + 2]])]])
				continue
			areas.append(["park" if path.contains("CentralPark") else "water", footprint(mesh)])
	for spec in [["SouthRiverBridge", "south_suspension", 20], ["CityHallBridge", "city_hall_arch", 28], ["NorthRiverBridge", "north_arch", 20]]:
		var bridge := city.get_node(spec[0]) as Node3D
		if not shown(bridge): continue
		var profile: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bridges/" + spec[1] + "/deck_profile.json"))
		var points: Array = []
		for row in profile: points.append(point(relative(bridge) * Vector3(-spec[2] / 2.0, row[1], row[0])))
		profile.reverse()
		for row in profile: points.append(point(relative(bridge) * Vector3(spec[2] / 2.0, row[1], row[0])))
		roads.append(points)
	var data := {"buildings": buildings, "roads": roads, "areas": areas, "landmarks": landmarks, "source": "Saved scenes/main.tscn including SuperCity overrides", "footprints": "Transformed mesh bounds; landmark bounds include their placed grounds and props", "source_sha256": {"main": FileAccess.get_sha256("res://scenes/main.tscn"), "super_city": FileAccess.get_sha256("res://scenes/super_city.tscn")}}
	DirAccess.make_dir_recursive_absolute(DEST)
	FileAccess.open(DEST + "layout.json", FileAccess.WRITE).store_string(JSON.stringify(data) + "\n")
	print("CITY_MAP: %d building/landmark footprints, %d road polygons, %d areas" % [buildings.size(), roads.size(), areas.size()])
	main.free()
	quit()

func has_building_parent(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != city:
		if parent.scene_file_path.begins_with("res://assets/buildings/"): return true
		parent = parent.get_parent()
	return false

func shown(node: Node) -> bool:
	while node != city:
		if node is Node3D and not node.visible: return false
		node = node.get_parent()
	return true

func relative(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != city:
		if parent is Node3D: result = parent.transform * result
		parent = parent.get_parent()
	return result

func point(v: Vector3) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.z, 0.1)]

func rect_polygon(rect: Rect2, transform: Transform3D) -> Array:
	return [point(transform * Vector3(rect.position.x, 0, rect.position.y)), point(transform * Vector3(rect.end.x, 0, rect.position.y)), point(transform * Vector3(rect.end.x, 0, rect.end.y)), point(transform * Vector3(rect.position.x, 0, rect.end.y))]

func footprint(mesh: MeshInstance3D) -> Array:
	var bounds := mesh.get_aabb()
	return rect_polygon(Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z), relative(mesh))

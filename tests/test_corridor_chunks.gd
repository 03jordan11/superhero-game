extends SceneTree
## Validate the authored membership against the actual Main scene and mesh bounds.
const CHUNK_SCRIPT := preload("res://scripts/city_building_chunk.gd")
var failures := 0
var city: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func relative(node: Node3D) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != city:
		if parent is Node3D: transform = parent.transform * transform
		parent = parent.get_parent()
	return transform

func run() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	city = main.get_node("SuperCity")
	# Keep validating the archived corridor fixture independently of the new grid.
	var groups := load("res://assets/super-city/chunks/corridor_chunks.tscn").instantiate() as Node3D
	city.add_child(groups)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/chunks/corridor_chunks.json"))
	var members := {}
	var chunk_count := 0
	check(groups.get_child_count() == 2, "Two corridor sides")
	for side in groups.get_children():
		check(side.name in [&"Left", &"Right"], "Named left/right groups")
		check(side.get_child_count() == 7, "Seven 250 m sections on each side")
		for chunk in side.get_children():
			chunk_count += 1
			check(chunk.get_script() == CHUNK_SCRIPT, "Chunk uses the authoring script")
			check(chunk.cell_size_m == Vector2(250, 250), "250 m cell dimensions")
			check(chunk.get_buildings().size() == chunk.building_paths.size(), "Every building NodePath resolves: " + str(chunk.name))
			check(chunk.get_child_count(true) == 0, "No runtime geometry or duplicated buildings")
			check(not chunk.is_processing() and not chunk.is_physics_processing(), "No per-frame chunk work")
			var box: AABB = relative(chunk) * chunk.source_bounds
			var entry: Dictionary = manifest.chunks.filter(func(c: Dictionary) -> bool: return c.name == str(chunk.name))[0]
			check(entry.members.size() == chunk.building_paths.size(), "Manifest agrees with scene membership")
			for building in chunk.get_buildings():
				var path := str(city.get_path_to(building))
				check(not members.has(path), "Building belongs to one chunk: " + path)
				members[path] = true
				check(path != "CityHall" and not path.begins_with("CityHall/"), "City Hall excluded")
				check(path in entry.members, "Manifest records the same source path")
				check(building is StaticBody3D or building.scene_file_path.begins_with("res://assets/buildings/"), "Whole source building root")
				var source_bounds := AABB()
				var started := false
				for mesh in building.find_children("*", "MeshInstance3D", true, false):
					if mesh.mesh == null: continue
					var cursor: Node = mesh
					var visible := true
					while cursor != city:
						if cursor is Node3D and not cursor.visible: visible = false
						cursor = cursor.get_parent()
					if not visible: continue
					var mesh_box: AABB = relative(mesh) * mesh.get_aabb()
					check(box.grow(0.01).encloses(mesh_box), "Chunk bounds contain visible geometry: " + path)
					source_bounds = source_bounds.merge(mesh_box) if started else mesh_box
					started = true
				var centre := source_bounds.get_center()
				check(centre.x >= -1500 and centre.x < 100, "Western connected corridor only")
				check(centre.z >= -730 and centre.z < -230, "Within the corridor strip")
				check((centre.z < -480) == (side.name == &"Left"), "Correct side looking east")
				check(absf(centre.x - chunk.position.x) <= 125 and absf(centre.z - chunk.position.z) <= 125, "Whole building assigned by centre to its cell")
	check(chunk_count == manifest.chunks.size(), "Scene/manifest chunk counts agree")
	check(members.has("Sidewalks/GasStationHideout"), "Main-only gas station override remains accessible")
	check(members.has("PoliceStation"), "Police station included independently of City Hall")
	check(city.get_node("CityHall").visible, "City Hall remains visible")
	main.free()
	# Running a detached group confirms editor guide geometry is not created in game.
	var runtime_groups := load("res://assets/super-city/chunks/corridor_chunks.tscn").instantiate() as Node3D
	root.add_child(runtime_groups)
	await process_frame
	check(runtime_groups.find_children("*", "GeometryInstance3D", true, false).is_empty(), "No editor guide draw calls at runtime")
	runtime_groups.free()
	print("CORRIDOR_CHUNKS_TEST: %d chunks, %d unique buildings, %d failures" % [chunk_count, members.size(), failures])
	quit(1 if failures else 0)

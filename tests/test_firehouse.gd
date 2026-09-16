extends SceneTree
const FOLDER := "res://assets/buildings/firehouse/"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var preview: Node3D = load(FOLDER + "firehouse_preview.tscn").instantiate()
	root.add_child(preview)
	var hall: Node3D = preview.get_node("Firehouse")
	var clock: Node = preview.get_node("DayNightCycle")
	var independent: Node3D = load(FOLDER + "firehouse.tscn").instantiate()
	independent.follow_day_night_cycle = false
	independent.position.x = 100
	root.add_child(independent)
	await process_frame
	await process_frame
	var triangle_count := 0
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in hall.find_children("*", "MeshInstance3D", true, false):
		assert(not str(mesh.name).to_lower().contains("sill"), "Window sills must be textured")
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			assert(mesh.get_active_material(surface) != null, "Missing material")
			triangle_count += mesh.mesh.surface_get_array_index_len(surface) / 3
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "firehouse_manifest.json"))
	assert(triangle_count == int(manifest.total_triangles), "Manifest disagrees with actual imported geometry")
	assert(triangle_count < 10000, "Complete POI exceeds triangle budget")
	assert(absf(bounds.size.x - 34.65) < .05 and absf(bounds.end.y - 26.875) < .05, "Metre scale changed")
	assert(absf(bounds.size.z - 23.705) < .05)
	assert(hall.get_node("Props").get_child_count() == 2)
	assert(hall._night_materials.size() == 2, "Expected window and fixture emission")
	clock.set_time(0)
	for i in hall._night_materials.size():
		assert(hall._night_materials[i] != independent._night_materials[i])
		assert(hall._night_materials[i].emission_energy_multiplier > 0)
		assert(is_zero_approx(independent._night_materials[i].emission_energy_multiplier))
	var late: Node3D = load(FOLDER + "firehouse.tscn").instantiate()
	late.position.x = 200
	root.add_child(late)
	await process_frame
	await process_frame
	assert(late._night_materials[0].emission_energy_multiplier > 0, "Night spawn did not synchronize")
	clock.set_time(13)
	for mat: StandardMaterial3D in hall._night_materials:
		assert(is_zero_approx(mat.emission_energy_multiplier), "Daytime emission remains")
	var emission := (load(FOLDER + "firehouse_details_emission.png") as Texture2D).get_image()
	# All four cell corners are opaque trim with no emission.
	for y in [0, 511, 512, 1023]:
		for x in [0, 511, 512, 1023]:
			assert(emission.get_pixel(x, y).r == 0)
	await physics_frame
	await physics_frame
	var space := hall.get_world_3d().direct_space_state
	var roof := ray(space, Vector3(3, 35, 0), Vector3(3, 10, 0))
	assert(not roof.is_empty() and absf(roof.position.y - 13.68) < .02, "Main roof collision missing")
	var tower := ray(space, Vector3(-14, 40, 7.25), Vector3(-14, 20, 7.25))
	assert(not tower.is_empty() and absf(tower.position.y - 25.525) < .02, "Tower roof collision missing")
	for x in [-7.5, -.5, 6.5, 13.5]:
		var door := ray(space, Vector3(x, 2, 15), Vector3(x, 2, 9))
		assert(not door.is_empty() and absf(door.position.z - 11) < .03, "Closed bay must be solid")
	assert(ray(space, Vector3(0, 5, 20), Vector3(0, -1, 20)).is_empty(), "Asset contains unwanted outer ground")
	var bench: Node3D = hall.get_node("Props/Bench_00")
	assert(bench.scene_file_path == FOLDER + "props/bench.tscn")
	var old_position := bench.global_position
	assert(ray(space, old_position + Vector3.UP * 3, old_position - Vector3.UP).get("collider") == bench.get_node("Collision"))
	bench.position.x += 60
	await physics_frame
	await physics_frame
	assert(ray(space, old_position + Vector3.UP * 3, old_position - Vector3.UP).is_empty(), "Moved bench left ghost collision")
	print("FIREHOUSE_TEST_PASS: %d triangles; scale, materials, no sill meshes, roof and closed-bay collision, independent props, night/day and night spawn" % triangle_count)
	late.free()
	independent.free()
	preview.free()
	quit()

func ray(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish))

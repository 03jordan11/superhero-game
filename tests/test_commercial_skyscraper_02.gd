extends SceneTree
const ASSET := "res://assets/generated-buildings/commercial/commercial_skyscraper_02.tscn"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.name = "Daylight"
	world.add_child(environment)
	for label in ["Sun", "Moon"]:
		var light := DirectionalLight3D.new()
		light.name = label
		world.add_child(light)
	var clock: Node = load("res://scripts/day_night_cycle.gd").new()
	clock.cycle_running = false
	world.add_child(clock)
	var building: StaticBody3D = load(ASSET).instantiate()
	world.add_child(building)
	await process_frame
	await process_frame
	var mesh: Mesh = building.get_node("MeshInstance3D").mesh
	var hvac: Mesh = building.get_node("RooftopHVAC/MeshInstance3D").mesh
	# Compare actual pre-edit geometry when the local audit snapshot is present.
	var baseline := "res://artifacts/skyscraper_02/before/commercial_skyscraper_02.res"
	if FileAccess.file_exists(baseline):
		var old_mesh: Mesh = load(baseline)
		assert(old_mesh.get_faces().size() / 3 == 108)
	assert(mesh.get_faces().size() / 3 == 56)
	assert(hvac.get_faces().size() / 3 == 48)
	assert(mesh.get_faces().size() / 3 + hvac.get_faces().size() / 3 <= 108)
	assert(mesh.get_aabb().size.is_equal_approx(Vector3(30,110,21.04)))
	assert(hvac == load("res://assets/props/rooftop_hvac/rooftop_hvac.res"))
	var door_count := 0
	for surface in mesh.get_surface_count():
		var material: StandardMaterial3D = mesh.surface_get_material(surface)
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, vertices.size(), 3):
			var cross := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			assert(cross.length() > .00001 and cross.dot(normals[i]) < 0)
		if material.resource_path.ends_with("signs_and_doors.tres"):
			door_count += vertices.size() / 3
			for v in vertices:
				assert(v.y < 3.59 and is_equal_approx(absf(v.z),10.52), "Only relocated doors; no name plaque")
	assert(door_count == 4)
	assert(building._night_materials.size() == 2)
	clock.set_time(12)
	for mat in building._night_materials:
		assert(is_zero_approx(mat.emission_energy_multiplier))
	clock.set_time(0)
	for mat in building._night_materials:
		assert(is_equal_approx(mat.emission_energy_multiplier,2.0))
		assert(mat.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY)
	var late: StaticBody3D = load(ASSET).instantiate()
	late.position.x = 100
	world.add_child(late)
	await process_frame
	await process_frame
	assert(late._night_materials[0] != building._night_materials[0])
	assert(is_equal_approx(late._night_materials[0].emission_energy_multiplier,2.0))
	clock.set_time(12)
	assert(is_zero_approx(late._night_materials[0].emission_energy_multiplier))
	var mask: Image = building._night_materials[0].emission_texture.get_image()
	var lit_pixels := 0
	for y in 64:
		for x in 64:
			if mask.get_pixel(x,y).r > .1:
				lit_pixels += 1
				assert(x%16 >= 2 and x%16 < 14 and y%16 >= 2 and y%16 <= 14)
	assert(lit_pixels > 0 and lit_pixels < 16*12*13)
	var city: Node = load("res://scenes/super_city.tscn").instantiate()
	var count := 0
	for node in city.find_children("*", "StaticBody3D", true, false):
		if node.scene_file_path != ASSET:
			continue
		count += 1
		assert(node.get_node("CollisionShape3D").shape.size.is_equal_approx(Vector3(30,104,21.04)))
		assert(node.get_node("CollisionShape3D").position.y == 52)
		assert(node.get_node("RooftopHVAC").position.y == 110)
	assert(count == 15)
	city.free()
	await physics_frame
	await physics_frame
	var state := world.get_world_3d().direct_space_state
	for probe in [[Vector3(14,120,0),104.0], [Vector3(10,120,0),110.0], [Vector3(0,120,0),112.8]]:
		var start: Vector3 = probe[0]
		var hit := state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start-Vector3(0,30,0)))
		assert(not hit.is_empty() and is_equal_approx(hit.position.y,probe[1]))
	var old_podium := state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(15.5,6,-20),Vector3(15.5,6,20)))
	assert(old_podium.is_empty(), "Removed podium must not leave invisible collision")
	world.free()
	print("SKYSCRAPER_02_PASS: 104 triangles; 15 city placements; flush base; doors only; terrace/roof/HVAC collision; window-only emission and clock transitions.")
	quit()

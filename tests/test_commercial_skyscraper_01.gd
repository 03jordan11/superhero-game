extends SceneTree
const ASSET := "res://assets/generated-buildings/commercial/commercial_skyscraper_01.tscn"
func _initialize() -> void: run.call_deferred()
func triangles(mesh: Mesh) -> int:
	var count := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		count += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null and not a[Mesh.ARRAY_INDEX].is_empty() else a[Mesh.ARRAY_VERTEX].size()) / 3
	return count
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new(); environment.name = "Daylight"; world.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.name = "Sun"; world.add_child(sun)
	var moon := DirectionalLight3D.new(); moon.name = "Moon"; world.add_child(moon)
	var clock: Node = load("res://scripts/day_night_cycle.gd").new(); clock.cycle_running = false; world.add_child(clock)
	var building: StaticBody3D = load(ASSET).instantiate(); world.add_child(building)
	var independent: StaticBody3D = load(ASSET).instantiate(); independent.follow_day_night_cycle = false; independent.position.x = 100; world.add_child(independent)
	await process_frame
	await process_frame
	var mesh: Mesh = building.get_node("MeshInstance3D").mesh
	assert(triangles(mesh) == 48)
	var hvac: Mesh = building.get_node("RooftopHVAC/MeshInstance3D").mesh
	assert(triangles(hvac) == 48)
	assert(is_equal_approx(mesh.get_aabb().end.y, 132))
	assert(is_equal_approx(building.get_node("RooftopHVAC").position.y + hvac.get_aabb().end.y, 134.8))
	# No tenant plaque: the atlas is used only by the two low entrance doors.
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as StandardMaterial3D
		if mat.resource_path.ends_with("signs_and_doors.tres"):
			for vertex: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				assert(vertex.y < 3.59)
		if mat.resource_path.ends_with("_podium.tres"):
			assert(not mat.emission_enabled)
			var stone := mat.albedo_texture.get_image()
			for y in stone.get_height():
				for x in stone.get_width(): assert(stone.get_pixel(x,y).r > .5, "Unexpected dark window pixel in podium")
	assert(building._night_materials.size() == 1)
	var lit: StandardMaterial3D = building._night_materials[0]
	assert(lit.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "Mask must suppress emission on walls")
	assert(lit != independent._night_materials[0])
	clock.set_time(12)
	assert(is_zero_approx(lit.emission_energy_multiplier))
	clock.set_time(0)
	assert(is_equal_approx(lit.emission_energy_multiplier, 2.0))
	assert(is_zero_approx(independent._night_materials[0].emission_energy_multiplier))
	var late: Node3D = load(ASSET).instantiate(); late.position.x = 200; world.add_child(late)
	await process_frame
	await process_frame
	assert(is_equal_approx(late._night_materials[0].emission_energy_multiplier, 2.0))
	clock.set_time(12)
	assert(is_zero_approx(late._night_materials[0].emission_energy_multiplier))
	var mask: Image = lit.emission_texture.get_image()
	var bright := 0
	for y in 64:
		for x in 64:
			if mask.get_pixel(x,y).r > .1:
				bright += 1
				assert(x%16 >= 3 and x%16 < 12 and x%16 != 8 and y%16 >= 2 and y%16 <= 11)
	assert(bright > 0 and bright < 16 * 80)
	# Test the real inherited city instances, without starting unrelated city systems.
	var city: Node = load("res://scenes/super_city.tscn").instantiate()
	var placements := 0
	for node in city.find_children("*", "StaticBody3D", true, false):
		if node.scene_file_path != ASSET: continue
		placements += 1
		assert(node.get_node("CollisionShape3D").shape.size.is_equal_approx(Vector3(22,6,20.04)))
		assert(node.get_node("CollisionShape3D").position.y == 3)
		assert(node.get_node("TowerCollision").shape.size == Vector3(20,126,18))
		assert(node.get_node("RooftopHVAC").position.y == 132)
	assert(placements == 28)
	city.free()
	await physics_frame
	await physics_frame
	# Landing rays hit the actual flat roof beside the HVAC and the unit itself.
	var state := world.get_world_3d().direct_space_state
	var roof := state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(8,150,0),Vector3(8,120,0)))
	assert(not roof.is_empty() and is_equal_approx(roof.position.y,132))
	var unit := state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,150,0),Vector3(0,120,0)))
	assert(not unit.is_empty() and is_equal_approx(unit.position.y,134.8))
	world.free()
	print("SKYSCRAPER_01_PASS: 96 triangles; 28 city placements; roof/HVAC collision; blank podium; no plaque; glass-only emission; real day/night clock and isolated instances.")
	quit()

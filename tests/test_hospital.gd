extends SceneTree
const HOSPITAL := preload("res://assets/buildings/hospital/hospital.tscn")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var day: Node3D = HOSPITAL.instantiate()
	var night: Node3D = HOSPITAL.instantiate()
	day.follow_day_night_cycle = false
	night.follow_day_night_cycle = false
	root.add_child(day)
	root.add_child(night)
	await process_frame
	assert(day._night_materials.size() == 3, "Expected room, curtain and sign emission materials")
	assert(night._night_materials.size() == 3)
	day.apply_night(0.0)
	night.apply_night(1.0)
	assert(day._entrance_lights.size() == 2 and night._entrance_lights.size() == 2)
	assert(not day._entrance_lights[0].visible and night._entrance_lights[0].visible)
	for index in day._night_materials.size():
		assert(day._night_materials[index] != night._night_materials[index], "Material state leaked between hospitals")
		assert(is_zero_approx(day._night_materials[index].emission_energy_multiplier))
		assert(night._night_materials[index].emission_energy_multiplier > 0.0)
	night.apply_night(0.5)
	assert(is_equal_approx(night._night_materials[0].emission_energy_multiplier, night.window_emission_energy * 0.5) or is_equal_approx(night._night_materials[0].emission_energy_multiplier, night.sign_emission_energy * 0.5))
	var meshes := day.get_node("Model").find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 25)
	var bounds := AABB()
	var first := true
	var triangle_count := 0
	for node: MeshInstance3D in meshes:
		assert(str(node.name) != "Window sills", "Removed sill boxes returned")
		assert(not str(node.name).contains("Upper lantern"), "Removed upper bays returned")
		assert(not str(node.name).contains("Tower emblem") and not str(node.name).contains("Tower H"))
		var box := node.global_transform * node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in node.mesh.get_surface_count():
			triangle_count += node.mesh.surface_get_array_index_len(surface) / 3
			assert(node.get_active_material(surface) != null)
			if str(node.name).contains("Canopy"):
				var material := node.get_active_material(surface) as StandardMaterial3D
				assert(material.emission_texture == null, "Canopy must not reuse a glowing window atlas")
	assert(triangle_count <= 10000, "Hospital exceeds the hard POI triangle limit")
	print("Hospital imported triangle count: ", triangle_count)
	assert(bounds.size.y > 131.0 and bounds.size.y < 133.0, "GLB scale or axis mismatch")
	assert(bounds.size.x > 104.0 and bounds.size.x < 106.0)
	assert(day.get_node("ExteriorCollision").get_child_count() == 14)
	var mask := Image.load_from_file("res://assets/buildings/hospital/hospital_windows_emission.png")
	assert(mask.get_size() == Vector2i(1024, 1024))
	assert(mask.get_pixel(0, 0).r == 0.0, "Window frames must not emit")
	var lit := 0
	for row in 8:
		for column in 8:
			if mask.get_pixel(column * 128 + 32, row * 128 + 32).r > 0.1:
				lit += 1
	assert(lit > 12 and lit < 50, "The atlas should contain both occupied and dark rooms")
	# Courtyard remains open, facade and traversable rooftops block physics rays.
	night.position.x = 500
	await physics_frame
	await physics_frame
	var space := day.get_world_3d().direct_space_state
	var open := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,3,50), Vector3(0,3,21)))
	assert(open.is_empty(), "Entrance court was blocked by a broad box collider")
	var tower := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,160,-17), Vector3(0,110,-17)))
	assert(not tower.is_empty() and is_equal_approx(tower.position.y,128.0))
	# Removed right sign and upper bays must not retain invisible collision.
	var old_sign := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(19,2,40),Vector3(19,2,30)))
	assert(old_sign.is_empty())
	var old_upper_bay := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30,75,20),Vector3(30,75,7)))
	assert(old_upper_bay.is_empty())
	for side in [-1.0,1.0]:
		var rounded_end := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(side*35,20,45),Vector3(side*35,20,20)))
		assert(not rounded_end.is_empty() and rounded_end.position.z > 33.0)
	day.free()
	night.free()
	print("HOSPITAL_TEST_PASS: revised mesh, canopy material, isolated emission, masks, removed signs/bays, rounded wing and courtyard collision")
	quit()

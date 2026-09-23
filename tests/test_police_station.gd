extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for bank_name: String in ["police_station"]:
		var folder := "res://assets/buildings/%s/" % bank_name
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + bank_name + "_manifest.json"))
		var preview: Node3D = load(folder + bank_name + "_preview.tscn").instantiate()
		root.add_child(preview)
		var hall: Node3D = preview.get_node("PoliceStation")
		var independent: Node3D = load(folder + bank_name + ".tscn").instantiate()
		independent.follow_day_night_cycle = false
		independent.position.x = 500
		root.add_child(independent)
		await process_frame
		await process_frame
		var triangles := 0
		var first := true
		var bounds := AABB()
		for mesh: MeshInstance3D in hall.find_children("*", "MeshInstance3D", true, false):
			assert(not str(mesh.name).to_lower().contains("sill"), "Window sills must be textured")
			var box := mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface in mesh.mesh.get_surface_count():
				assert(mesh.get_active_material(surface) != null)
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
		assert(triangles < 10000, "Complete precinct exceeds hard POI budget")
		assert(triangles == int(manifest.base_triangles), "Building geometry preserved after removing bench props")
		var lo: Array = manifest.bounds_min_blender
		var hi: Array = manifest.bounds_max_blender
		assert(absf(bounds.size.x - (hi[0] - lo[0])) < .05)
		# Building-only depth; the source manifest also included benches.
		assert(absf(bounds.size.z - 29.95) < .05)
		assert(absf(bounds.end.y - hi[2]) < .05)
		assert(hall._night_materials.size() == 2)
		var clock: Node = preview.get_node("DayNightCycle")
		clock.set_time(0)
		for i in hall._night_materials.size():
			assert(_energy(hall._night_materials[i]) > 0)
			assert(is_zero_approx(_energy(independent._night_materials[i])))
			assert(hall._night_materials[i] != independent._night_materials[i])
		var late: Node3D = load(folder + bank_name + ".tscn").instantiate()
		late.position.x = 1000
		root.add_child(late)
		await process_frame
		await process_frame
		for mat: Material in late._night_materials:
			assert(_energy(mat) > 0, "Night spawn did not synchronize")
		clock.set_time(13)
		for i in hall._night_materials.size():
			assert(is_zero_approx(_energy(hall._night_materials[i])))
			assert(is_zero_approx(_energy(late._night_materials[i])))
		var mask := (load(folder + bank_name + "_windows_emission.png") as Texture2D).get_image()
		for row in 8:
			for col in 8:
				assert(mask.get_pixel(col * 128, row * 128).r == 0, "Painted frame emits")
		await physics_frame
		await physics_frame
		var space := hall.get_world_3d().direct_space_state
		for roof: Dictionary in manifest.roof_tests:
			var x: float = roof.position[0]
			var z: float = roof.position[2]
			var hit := ray(space, Vector3(x, 170, z), Vector3(x, 0, z))
			assert(not hit.is_empty() and absf(hit.position.y - float(roof.height)) < .05, "%s roof collision mismatch at %s: %s" % [bank_name, roof.position, hit])
		var door_z := 15.94
		assert(not ray(space, Vector3(6.3, 1.5, door_z + 3), Vector3(6.3, 1.5, door_z - 1)).is_empty(), "Closed entry lacks collision")
		assert(not ray(space, Vector3(1.5, 1.5, -16), Vector3(1.5, 1.5, -11)).is_empty(), "Closed rear door lacks collision")
		assert(ray(space, Vector3(0, 4, 25), Vector3(0, -1, 25)).is_empty(), "POI includes unwanted outer ground")
		var props := hall.get_node("Props")
		assert(props.get_child_count() == 0, "Removed benches leave no mesh or collision nodes")
		print("POLICE_TEST_PASS: %s = %d triangles; scale, materials, textured sills, collision, props and day/night lighting" % [bank_name, triangles])
		late.free()
		independent.free()
		preview.free()
	quit()

func ray(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish))


func _energy(material: Material) -> float:
	return material.get_shader_parameter("emission_energy") if material is ShaderMaterial else material.emission_energy_multiplier

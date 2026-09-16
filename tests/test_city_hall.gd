extends SceneTree
## Imported geometry, independent props and actual CharacterBody3D stair traversal.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var hall: Node3D = load("res://assets/buildings/city_hall/city_hall.tscn").instantiate()
	root.add_child(hall)
	await physics_frame
	await physics_frame
	var bounds := AABB()
	var first := true
	var triangle_count := 0
	for mesh: MeshInstance3D in hall.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		assert(not str(mesh.name) in ["Wing columns", "Roof balustrades", "Link balustrades", "Sculpted landscape", "Perimeter sidewalk", "Window sills", "Arch surrounds", "Grounds lawn", "Stair forecourt", "Central park connection"], "Removed decoration/landscape returned")
		if str(mesh.name) == "Grand staircase":
			assert(absf(mesh.get_aabb().size.x - 42) < .01, "Stairs must be slightly wider than the 36 m portico")
			var textured_treads := false
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				textured_treads = textured_treads or material.albedo_texture != null
			assert(textured_treads, "Stair edge contrast texture missing")
		if str(mesh.name) == "Drum columns":
			assert(absf(mesh.get_aabb().position.y - 44.5) < .01, "Drum columns float above the pedestal")
		if str(mesh.name) == "Facade glazing":
			for surface in mesh.mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					assert(not (absf(vertex.x) < 13 and absf(vertex.z + 12.05) < .02 and vertex.y > 35), "Obstructed upper rear windows remain")
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			assert(mesh.get_active_material(surface) != null, "Missing imported material")
			triangle_count += mesh.mesh.surface_get_array_index_len(surface) / 3
	assert(absf(bounds.size.x - 184.65) < .1 and absf(bounds.size.z - 133.575) < .1, "Site must end at the retaining walls and stair foot")
	assert(absf(bounds.end.y - 78) < .1, "Dome scale/axis changed")
	assert(triangle_count < 6000, "Textured trim and box columns should reduce base geometry")
	var props := hall.get_node("GardenProps")
	assert(props.get_child_count() == 44)
	assert(props.find_children("Table_*", "", false, false).size() == 6)
	assert(props.find_children("Bench_*", "", false, false).size() == 24)
	assert(props.find_children("Hedge_*", "", false, false).size() == 14)
	for prop: Node3D in props.get_children():
		assert(prop.scene_file_path.begins_with("res://assets/buildings/city_hall/props/"))
		assert(prop.has_node("Mesh") and prop.has_node("Collision"), "Prop must carry mesh and collision together")
	var space := hall.get_world_3d().direct_space_state
	var court := ray(space, Vector3(0, 90, -35), Vector3(0, 0, -35))
	assert(not court.is_empty() and absf(court.position.y - 8.15) < .03, "Courtyard is obstructed or lacks ground")
	var rear_access := ray(space, Vector3(0, 10, -95), Vector3(0, 10, -14))
	assert(rear_access.is_empty(), "Rear courtyard access is blocked")
	var roof := ray(space, Vector3(64, 65, -30), Vector3(64, 30, -30))
	assert(not roof.is_empty() and absf(roof.position.y - 39) < .05, "Wing roof needs landing collision")
	var dome := ray(space, Vector3(0, 100, 3), Vector3(0, 40, 3))
	assert(not dome.is_empty() and absf(dome.position.y - 78) < .05)
	# Old perimeter/slopes have no leftover paving or raised collision.
	assert(not hall.get_node("ExteriorCollision").has_node("SculptedLandscape"))
	for x: float in [-108.0, -99.0, 99.0, 108.0]:
		for z: float in [-108.0, -80.0, 20.0, 50.0, 98.0]:
			var hit := ray(space, Vector3(x, 12, z), Vector3(x, -1, z))
			assert(hit.is_empty(), "Removed outer grounds left ghost collision")
	assert(ray(space, Vector3(0, 2, 75), Vector3(0, -1, 75)).is_empty(), "Removed walkup left ghost collision")
	var back_wall := ray(space, Vector3(0, 4, -80), Vector3(0, 4, -60))
	assert(not back_wall.is_empty() and absf(back_wall.position.z + 65) < .02, "Rear retaining wall missing")
	for side: float in [-1.0, 1.0]:
		var wall := ray(space, Vector3(side * 100, 4, 0), Vector3(side * 80, 4, 0))
		assert(not wall.is_empty() and absf(absf(wall.position.x) - 92) < .02)
		for tier in 4:
			var z := 65.0 - tier * 7.4
			var lawn := ray(space, Vector3(side * 50, 12, z), Vector3(side * 50, -1, z))
			assert(not lawn.is_empty() and absf(lawn.position.y - (tier + 1) * 2) < .02, "Front garden terrace must be flat and supported")
	# Removing a prop also removes its collision, without touching the building model.
	var table := props.get_node("Table_00") as Node3D
	var table_position := table.global_position
	var table_hit := ray(space, table_position + Vector3.UP * 3, table_position - Vector3.UP)
	assert(table_hit.get("collider") == table.get_node("Collision"))
	table.position.x += 400
	await physics_frame
	await physics_frame
	var cleared := ray(space, table_position + Vector3.UP * 3, table_position - Vector3.UP)
	assert(cleared.get("collider") == hall.get_node("ExteriorCollision"), "Moved furniture left ghost collision")
	# Traverse the center and both edges of the narrowed stair opening.
	var walkers: Array[CharacterBody3D] = []
	for x: float in [-18.0, 0.0, 18.0]:
		var walker := CharacterBody3D.new()
		walker.floor_snap_length = .35
		var capsule := CapsuleShape3D.new()
		capsule.radius = .35
		capsule.height = 1.8
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		walker.add_child(shape)
		root.add_child(walker)
		walker.position = Vector3(x, 1.6, 67)
		walkers.append(walker)
	for frame in 520:
		await physics_frame
		for walker in walkers:
			walker.velocity.x = 0
			walker.velocity.z = -6
			walker.velocity.y = -1 if walker.is_on_floor() else walker.velocity.y - 20.0 / 60.0
			walker.move_and_slide()
	for walker in walkers:
		assert(walker.position.z < 31 and walker.position.y > 8.8, "Walker caught on stairs: %s" % walker.position)
		print("Central stair ascent passed: ", walker.position)
		walker.free()
	print("CITY_HALL_TEST_PASS: metre scale, reduced geometry, textured central stairs, retaining walls, flat garden terraces, removed slope/sidewalk collision, courtyard, props, roof/dome, stair traversal.")
	hall.free()
	quit()

func ray(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish))

extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	assert(main.get_node("SuperCity/CityHall").transform.is_equal_approx(city.get_node("CityHall").transform))
	main.free()
	for child in city.get_children():
		if child.name not in ["CityHall", "Roads", "Sidewalks"]: child.free()
	city.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(city)
	await physics_frame
	await physics_frame
	var hall := city.get_node("CityHall") as Node3D
	assert(hall.position.is_equal_approx(Vector3(-301,0.019211411,-404)))
	var wall: MeshInstance3D = hall.get_node("Model/Front setback wall 1")
	var total := 0
	var base := 0
	for mi: MeshInstance3D in hall.find_children("*", "MeshInstance3D", true, false):
		var count := mi.mesh.get_faces().size()/3
		total += count
		if hall.get_node("Model").is_ancestor_of(mi): base += count
	assert(total <= 10000)
	for side: String in ["Left", "Right"]:
		var cheek: MeshInstance3D = hall.get_node("Model/Continuous stair side "+side)
		assert(cheek.mesh.get_surface_count() == 1)
		assert(cheek.get_active_material(0) == wall.get_active_material(0))
		assert(hall.get_node("ExteriorCollision/ContinuousStairSide"+side).shape is ConcavePolygonShape3D)
	assert(not hall.has_node("Model/Landing piers") and not hall.has_node("Model/Stair cheek walls"))
	var roads := city.get_node("Roads/roads_2_1")
	var road := roads.get_node("CityHallEastConnection") as Node3D
	assert(road.length_m == 120 and road.width_m == 20)
	assert(roads.get_node("Junction_434").active_arms == 15)
	assert(roads.get_node("Junction_435").active_arms == 11)
	assert(not city.has_node("Sidewalks/sidewalks_2_1/Paving_049_1_1"))
	assert(not city.has_node("Sidewalks/sidewalks_2_1/Straight_031_1_1"))
	assert(city.get_node("Sidewalks/CityHallSurrounds").get_child_count() == 4)
	var space := city.get_world_3d().direct_space_state
	var probes := 0
	for z in range(-480,-319):
		for x: float in [-208,-200,-192]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,1,z),Vector3(x,-1,z)))
			assert(not hit.is_empty() and absf(hit.position.y-0.03) < 0.002,"Road seam at "+str(Vector2(x,z))+" hit="+str(hit))
			probes += 1
	for point: Vector2 in [Vector2(-301,-340),Vector2(-360,-340),Vector2(-240,-340),Vector2(-301,-464),Vector2(-360,-464),Vector2(-240,-464),Vector2(-216,-420),Vector2(-216,-360)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,1,point.y),Vector3(point.x,-1,point.y)))
		assert(not hit.is_empty() and absf(hit.position.y-0.03)<0.002,"Sidewalk gap at "+str(point))
	if "--write-audit" in OS.get_cmdline_user_args():
		var counts := {}
		for prop in hall.get_node("GardenProps").get_children():
			var kind: String = prop.scene_file_path.get_file().get_basename()
			counts[kind] = counts.get(kind,0)+1
		var audit := {"base_triangles":base,"complete_poi_triangles":total,"placed_prop_triangles":total-base,"prop_counts":counts,"source":"Actual Godot-imported highest-detail meshes, per placed instance"}
		FileAccess.open("res://assets/buildings/city_hall/TRIANGLE_AUDIT.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t")+"\n")
	print("CITY_HALL_SURROUNDS_PASS: %d road collision probes, sidewalk joins, continuous walls, saved placement, %d complete POI triangles" % [probes,total])
	city.free()
	quit()



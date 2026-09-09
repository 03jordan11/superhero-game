extends SceneTree
## Physics probes of the city surfaces only. No player is created or exercised.
const OUT = "res://assets/super-city/"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("probe_city")

func probe_city() -> void:
	var scene = load("res://scenes/super_city.tscn").instantiate()
	# The user may have added a player since the city was authored.
	# Keep these checks limited to static surfaces; do not run player behavior.
	if scene.has_node("Player"):
		scene.get_node("Player").free()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var space = scene.get_world_3d().direct_space_state
	var probes: Array = []
	for entry in [["20m street",Vector3(-560,10,380),0.03],["4m sidewalk",Vector3(-572,10,380),0.03],["central park",Vector3(-300,10,0),0.025],["river placeholder",Vector3(250,10,40),-1.4],["flat crossing",Vector3(280,10,160),0.03],["pier apron",Vector3(1160,10,900),0.03],["bay placeholder",Vector3(0,10,910),-1.4],["ground at city edge",Vector3(-1490,10,-900),0.0]]:
		var query = PhysicsRayQueryParameters3D.create(entry[1],entry[1]-Vector3(0,30,0),1)
		var hit = space.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y-entry[2]) > 0.02:
			failures.append("Missing/incorrect collision surface: "+entry[0])
		else:
			probes.append({"surface":entry[0],"height_m":hit.position.y,"body":str(hit.collider.name)})
	# Broad low-altitude surface coverage: skips footprint interiors, tests streets,
	# alleys, exposed earth, park and blue placeholders after terrain cutouts.
	var layout = JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	var footprints: Array[Rect2] = []
	for building in layout.buildings:
		var r: Array = building.rect
		footprints.append(Rect2(r[0],r[1],r[2],r[3]).grow(0.5))
	var coverage_count = 0
	var boundary_samples = 0
	for x in range(-1485,1500,35):
		for z in range(-985,1000,35):
			var p = Vector2(x,z)
			var occupied = false
			for rect in footprints:
				if rect.has_point(p):
					occupied = true
					break
			if occupied:
				continue
			var query = PhysicsRayQueryParameters3D.create(Vector3(x,2,z),Vector3(x,-5,z),1)
			if space.intersect_ray(query).is_empty():
				# A zero-width ray can miss exactly on a shared triangle edge.
				# Require coverage in all four adjacent quadrants to distinguish
				# this numerical seam from an actual gap in the authored surface.
				var covered_neighbors = 0
				for offset in [Vector2(-0.01,-0.01),Vector2(-0.01,0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01)]:
					var neighbor = p+offset
					var adjacent = PhysicsRayQueryParameters3D.create(Vector3(neighbor.x,2,neighbor.y),Vector3(neighbor.x,-5,neighbor.y),1)
					if not space.intersect_ray(adjacent).is_empty():
						covered_neighbors += 1
				if covered_neighbors == 4:
					boundary_samples += 1
				else:
					failures.append("Surface hole at "+str(p))
			coverage_count += 1
	var file = FileAccess.open(OUT+"tools/surface_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"probes":probes,"coverage_samples":coverage_count,"shared_edges_verified_with_four_adjacent_rays":boundary_samples},"\t"))
	for failure in failures:
		push_error(failure)
	print("City surface validation: %d height probes, %d coverage samples, %d failures" % [probes.size(),coverage_count,failures.size()])
	quit(0 if failures.is_empty() else 1)

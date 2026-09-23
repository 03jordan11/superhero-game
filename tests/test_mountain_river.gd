extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Mountain river test timed out"); quit(1))
	var original: Node = load("res://scenes/city_life.tscn").instantiate()
	var original_mountain: MeshInstance3D = original.get_node("Highway/PinePassMountains")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	check(not main.has_node("MountainRiver"),"No duplicate river at Main root")
	check(main.has_node("SuperCity/MountainRiver"),"Main inherits the city's river")
	var inherited: MeshInstance3D = main.get_node("SuperCity/CityLife/Highway/PinePassMountains")
	check(inherited.mesh.get_faces() == original_mountain.mesh.get_faces(),"Main uses the original solid mountain geometry")
	main.free()
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:city.get_node(label).free()
	root.add_child(city)
	await process_frame
	await physics_frame
	await physics_frame
	var mountain: MeshInstance3D = city.get_node("CityLife/Highway/PinePassMountains")
	var mountain_mesh: Mesh = mountain.get_meta("occlusion_source_mesh",mountain.mesh)
	check(mountain_mesh.get_faces() == original_mountain.mesh.get_faces(),"Standalone city preserves original mountain vertices")
	var solid: ConcavePolygonShape3D = mountain.get_node("Solid/CollisionShape3D").shape
	var original_solid: ConcavePolygonShape3D = original_mountain.get_node("Solid/CollisionShape3D").shape
	check(solid.get_faces() == original_solid.get_faces(),"Original solid mountain collision preserved")
	for path in ["CityLife/Highway/NorthernGround","CoastalRegion/Landscape/CoastalTerrain"]:
		var terrain: MeshInstance3D = city.get_node(path)
		var source: Mesh = terrain.get_meta("occlusion_source_mesh",terrain.mesh)
		check(source.resource_path.begins_with("res://assets/trees/boundary_terrain/"),"River-carved terrain uses boundary-clipped mesh")
	var space := city.get_world_3d().direct_space_state
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mountain-river/report.json"))
	var mountain_hits := 0
	var channel_hits := 0
	for row in report.river_rows:
		if row[0] > -1010:continue
		var p := Vector3(row[1],1500,row[0])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*2000))
		check(not hit.is_empty(),"Solid surface beneath river center at "+str(row[0]))
		if not hit.is_empty():
			if hit.collider == mountain.get_node("Solid"):mountain_hits+=1
			elif hit.position.y < row[2]-4:channel_hits+=1
	check(mountain_hits>0,"River meets the intact mountain instead of a canyon")
	check(channel_hits>0,"River remains visible on its forest approach")
	var river := city.get_node("MountainRiver")
	# Every remaining river triangle must lie outside the mountain volume.
	var mountain_body: StaticBody3D = mountain.get_node("Solid")
	var previous_layer := mountain_body.collision_layer
	mountain_body.collision_layer=1<<19
	var trimmed_probes := 0
	for child in river.get_children():
		if not child is MeshInstance3D: continue
		var part: MeshInstance3D = child
		var label := str(part.name)
		var triangles := part.mesh.get_faces()
		for i in range(0,triangles.size(),3):
			var center := part.to_global((triangles[i]+triangles[i+1]+triangles[i+2])/3)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,1500,center.z),Vector3(center.x,-500,center.z),1<<19))
			check(hit.is_empty() or center.y>=hit.position.y-.02,"No remaining "+label+" triangle beneath mountain at "+str(center)+" hit "+str(hit.get("position")))
			trimmed_probes+=1
		if part.has_node("Solid/CollisionShape3D"):
			check(part.get_node("Solid/CollisionShape3D").shape.get_faces()==triangles,"Trimmed collision matches "+label)
	mountain_body.collision_layer=previous_layer
	print("TRIMMED_GEOMETRY: ",trimmed_probes," triangle probes")
	var clock := city.get_node("DayNightCycle")
	clock.cycle_running=false
	clock.set_time(0);check(float(river._water.get_shader_parameter("night_amount"))>.9,"Night water synchronized")
	clock.set_time(12);check(float(river._water.get_shader_parameter("night_amount"))<.1,"Day water synchronized")
	var elapsed: float = river._elapsed
	paused=true;await process_frame;await process_frame
	check(river._elapsed==elapsed,"Pause freezes river motion");paused=false
	print("SOLID_MOUNTAIN_RIVER: %d solid mountain probes, %d open channel probes, %d failures"%[mountain_hits,channel_hits,failures])
	original.free();city.free();quit(1 if failures else 0)

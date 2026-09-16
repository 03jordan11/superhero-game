extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value:
		failures+=1
		push_error(label)

func run() -> void:
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(label).free()
	root.add_child(city)
	var waterfront=city.get_node("Waterfront")
	var cycle=city.get_node("DayNightCycle")
	cycle.cycle_running=false
	await process_frame
	await physics_frame
	await physics_frame
	check(city.get_node("WaterPlaceholders/RiverAndBay_BluePlaceholder/CollisionShape3D").disabled,"Water placeholder collision disabled")
	check(not city.get_node("WaterPlaceholders/RiverAndBay_BluePlaceholder/MeshInstance3D").visible,"Blue placeholder hidden")
	var space:=city.get_world_3d().direct_space_state
	for point in [Vector3(200,10,-600),Vector3(600,10,1600)]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*60))
		check(not hit.is_empty() and hit.position.y < -8,"Open water has a submerged floor, no invisible surface")
	for point in [Vector3(1066,10,1000),Vector3(1200,10,1050),Vector3(1140,10,1198),Vector3(300,8,2080),Vector3(300,20,2185),Vector3(300,20,2266),Vector3(300,20,2315)]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*40))
		check(not hit.is_empty() and hit.position.y> -0.1 and hit.normal.y>0.7,"Solid dock, island ramp or yard at "+str(point))
	# Terrain rays outside buildings catch reversed cliff triangles or missing island land.
	for p in [Vector3(-165,25,0),Vector3(165,25,0),Vector3(0,25,140)]:
		var point: Vector3=p+Vector3(300,0,2400)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*40))
		check(not hit.is_empty() and hit.position.y>5 and hit.normal.y>0.5,"Island terrain is solid and faces upward")
	var gate:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(300,17,2270),Vector3(300,17,2340)))
	check(gate.is_empty(),"Prison gate is open for traversal")
	await probe_island_walk()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	for crossing in data.crossings:
		var row: Array=data.river_curve_rows[clampi(int((float(crossing)+1000)/10),0,180)]
		var p:=Vector3((row[1]+row[2])*.5,5,crossing)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*10))
		check(not hit.is_empty() and absf(hit.position.y-0.03)<0.1,"Existing road crossing preserved")
	check(waterfront.get_node("Boats").get_child_count()==9,"Nine flavor boats")
	var kinds: Dictionary={}
	for boat in waterfront._boats:
		kinds[boat.get_meta("kind")]=true
		check(boat is AnimatableBody3D and boat.has_node("HullCollision"),"Boat hull supports landings")
		var p: Vector3=boat.position
		if p.z<800:
			var row: Array=data.river_curve_rows[clampi(int((p.z+1000)/10),0,180)]
			check(p.x>row[1]+8 and p.x<row[2]-8,"River boats stay inside channel")
	check(kinds.size()==4,"Tug, ferry, fishing boat and sailboat")
	cycle.set_time(12)
	for light in waterfront._lights: check(not light.visible,"Daytime lights off")
	cycle.set_time(0)
	for light in waterfront._lights: check(light.visible,"Nighttime lights on")
	var elapsed: float=waterfront._elapsed
	var pose: Transform3D=waterfront._boats[0].transform
	paused=true
	await process_frame
	await process_frame
	check(waterfront._elapsed==elapsed and waterfront._boats[0].transform==pose,"Pause freezes boats and water")
	paused=false
	waterfront.boat_motion_enabled=false
	waterfront.searchlights_enabled=false
	await physics_frame
	await physics_frame
	check(waterfront._boats[0].transform.is_equal_approx(waterfront._boats[0].get_meta("rest")),"Boat motion toggle restores resting pose")
	for light in waterfront._lights:
		if light.has_meta("searchlight"): check(not light.visible,"Searchlights can be disabled")
	print("Waterfront: %d failures"%failures)
	city.free()
	quit(0 if failures==0 else 1)

func probe_island_walk() -> void:
	var walker:=CharacterBody3D.new()
	walker.position=Vector3(300,3.05,2140)
	walker.floor_snap_length=0.4
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.height=2.0
	capsule.radius=0.5
	shape.shape=capsule
	walker.add_child(shape)
	root.add_child(walker)
	for frame in 1400:
		await physics_frame
		if walker.position.z>=2320: break
		walker.velocity.z=9.0
		walker.velocity.y-=20.0/60.0
		walker.move_and_slide()
	check(walker.position.z>=2318,"Player-sized capsule can walk from island landing through the prison gate; stopped at "+str(walker.position))
	if walker.position.z<2318:
		for i in walker.get_slide_collision_count():
			var contact:=walker.get_slide_collision(i)
			print("Blocked by ",contact.get_collider().get_path()," normal ",contact.get_normal())
	walker.free()

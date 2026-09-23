extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("City life test timed out"); quit(1))
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(label).free()
	root.add_child(city)
	var life=city.get_node("CityLife")
	life.set_process(false)
	var clock=city.get_node("DayNightCycle")
	clock.cycle_running=false
	await process_frame
	await physics_frame
	await physics_frame
	var counts: Dictionary=life.get_meta("counts")
	for key in counts: check(counts[key]>0,"Scenery category present: "+key)
	for removed in ["Benches","Diners","HotdogStands","BusStops","Hydrants","Grates","Steam","TrafficControls"]:
		check(not life.has_node(removed),"Removed scenery stays absent: "+removed)
	check(life.get_node("Blimp/Advertisement").stream.get_length()>5,"Recorded advertisement loads")
	var places: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city-life/placements.json"))
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	for path in places.cleared_buildings:
		check(not city.get_node(path).visible and city.get_node(path+"/CollisionShape3D").disabled,"Sandlot replaces courtyard building: "+path)
	for prop in places.props:
		var area:=Rect2(prop.rect[0],prop.rect[1],prop.rect[2],prop.rect[3])
		for road in layout.roads:
			var r: Array=road.rect
			check(not area.intersects(Rect2(r[0],r[1],r[2],r[3])),"Sidewalk furniture stays out of traffic")
		for building in layout.buildings:
			if building.node in places.cleared_buildings: continue
			var r: Array=building.rect
			check(not area.intersects(Rect2(r[0],r[1],r[2],r[3])),"Furniture stays outside buildings")
	var space:=city.get_world_3d().direct_space_state
	# Both carriageways must remain continuous and clear of scenery up to the portal.
	for z in range(-960,-2771,-20):
		var p:=highway_point(z)
		for side in [-7,7]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(side,100,0),p+Vector3(side,-10,0)))
			check(not hit.is_empty() and absf(hit.position.y-p.y)<0.2 and hit.normal.y>0.9,"Highway is clear and solid at "+str(p+Vector3(side,0,0)))
	for side in [-7,7]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1100+side,15,-2760),Vector3(-1100+side,15,-2825)))
		if not hit.is_empty(): print("Tunnel obstruction: ",hit.collider.get_path()," at ",hit.position)
		check(hit.is_empty(),"Tunnel entry has no invisible blocker")
	for step in 60:
		life.elapsed=step*life.blimp_lap_seconds/60
		life.update_animation(0)
		check(life.blimp.position.y-17>241.2,"Blimp clears the tallest roof")
	life.elapsed=0
	life.update_animation(0)
	var pose: Transform3D=life.blimp.transform
	check(life._blinks.size()==5,"Five lightweight blimp beacon lights remain")
	for light in life._blinks: check(light is OmniLight3D and not light.shadow_enabled,"Blimp beacons have no fixture mesh or shadow pass")
	var blimp_triangles:=0
	for mesh in life.blimp.find_children("*","MeshInstance3D",true,false):
		check(not str(mesh.name).begins_with("Strobe"),"Blimp beacon fixture models removed")
		blimp_triangles+=mesh.mesh.get_faces().size()/3
	check(blimp_triangles==1340,"Blimp fixture removal eliminates 21120 triangles")
	var flash: float=life._blinks[0].light_energy
	life.update_animation(0.3)
	check(life._blinks[0].light_energy!=flash,"Blimp beacons flash")
	life.elapsed=life.blimp_lap_seconds
	life.update_animation(0)
	check(life.blimp.transform.is_equal_approx(pose),"Blimp completes a seamless lap")
	clock.set_time(0)
	for light in life._lights: check(light.visible,"Scenery lights turn on at night")
	clock.set_time(12)
	for light in life._lights: check(not light.visible,"Scenery lights switch off by day")
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.position=life.blimp.position+Vector3(10,0,0)
	camera.make_current()
	life._ad_timer=0
	life.update_animation(0)
	await process_frame
	check(life.ad_audio.playing,"Nearby blimp starts its spatial advertisement")
	life.blimp_ad_audio_enabled=false
	life.update_animation(0)
	check(not life.ad_audio.playing,"Advertisement can be muted")
	life.set_process(true)
	paused=true
	var elapsed: float=life.elapsed
	await process_frame
	await process_frame
	check(life.elapsed==elapsed,"Pause freezes blimp animation")
	paused=false
	print("City life: %d failures"%failures)
	city.free()
	camera.free()
	quit(0 if failures==0 else 1)

func highway_point(z: float) -> Vector3:
	var knots: Array[Vector2]=[Vector2(-740,-960),Vector2(-740,-1180),Vector2(-830,-1500),Vector2(-1040,-1900),Vector2(-1100,-2300),Vector2(-1100,-2845)]
	for i in knots.size()-1:
		if z>=knots[i+1].y:
			return Vector3(lerpf(knots[i].x,knots[i+1].x,smoothstep(knots[i].y,knots[i+1].y,z)),0.055+13*smoothstep(-1000,-2000,z),z)
	return Vector3(-1100,13.055,z)

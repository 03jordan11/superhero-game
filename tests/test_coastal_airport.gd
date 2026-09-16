extends SceneTree
const LAND=preload("res://scripts/coastal_landscape.gd")
const FLIGHTS=preload("res://scripts/coastal_airport.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Coastal airport test timed out"); quit(1))
	var city:Node3D=load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(label).free()
	root.add_child(city)
	var region=city.get_node("CoastalRegion")
	region.set_physics_process(false)
	var clock=city.get_node("DayNightCycle")
	clock.cycle_running=false
	await process_frame
	await physics_frame
	await physics_frame
	check(region._planes.size()==2,"Two active airline schedules")
	for plane in region._planes:
		check(plane.position.is_equal_approx(FLIGHTS.flight_position(float(plane.get_meta("phase")))),"Live aircraft transform matches its scheduled starting position")
	check(region.has_node("Airport/ParkedJet0") and region.has_node("Airport/ParkedJet1"),"Two static gate aircraft")
	var pruning: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/mountain-river/report.json"))
	check(region.get_meta("tree_count")==pruning.tree_counts.coastal_region.after,"Coastal tree metadata matches mountain clearing")
	var space:=city.get_world_3d().direct_space_state
	for x in [-22000,-9000,-5000,-1700,1700,5000,9000,22000]:
		for z in [-8000,-900,300]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,1500,z),Vector3(x,-10,z)))
			check(not hit.is_empty() and hit.normal.y>0.5,"Solid extended land at "+str(Vector2(x,z)))
	# Existing bay and prison approaches stay open water, not covered by terrain.
	for p in [Vector3(600,5,1600),Vector3(-1000,5,2300),Vector3(1000,5,2200)]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*50))
		check(not hit.is_empty() and hit.position.y< -8,"Coastal extension preserves the bay")
	for x in range(-4350,-2600,50):
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,7,200),Vector3(x,5,200)))
		check(not hit.is_empty() and absf(hit.position.y-6.1)<0.025 and hit.normal.y>0.99,"Continuous upward-facing runway")
	for x in range(-1490,-3190,-30):
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,100,-480),Vector3(x,-5,-480)))
		check(not hit.is_empty() and hit.normal.y>0.85 and "AirportAccessRoad" in str(hit.collider.get_path()),"Access road remains above coastal terrain at "+str(x))
	var minimum_separation:=INF
	for step in 1320:
		var t:=step*0.25
		var p:=FLIGHTS.flight_position(t)
		minimum_separation=minf(minimum_separation,p.distance_to(FLIGHTS.flight_position(t+100)))
		check(p.is_finite() and p.y>=9.99,"Air route remains valid and above runway grade")
		check(p.distance_to(FLIGHTS.flight_position(t+0.02))<4,"Air route has no position teleports")
		if t>=38 and t<195: check(absf(p.y-10)<0.01,"Taxi/rollout wheels remain on airport grade")
	check(minimum_separation>75,"Scheduled flights remain separated; minimum "+str(minimum_separation))
	check(FLIGHTS.flight_position(95).is_equal_approx(FLIGHTS.flight_position(105)),"Aircraft dwell at the gate")
	check(FLIGHTS.flight_position(120).z>FLIGHTS.flight_position(112).z,"Aircraft push back from the gate")
	check(FLIGHTS.flight_position(210).y>100,"Departures climb away from the runway")
	check(FLIGHTS.flight_position(330).is_equal_approx(FLIGHTS.flight_position(0)),"Flight lap closes")
	var exclusions:Array[RID]=[]
	for plane in region._planes: exclusions.append(plane.get_rid())
	for name_tag in ["ParkedJet0","ParkedJet1"]: exclusions.append(region.get_node("Airport/"+name_tag).get_rid())
	# Probe the fuselage swept poses against actual scenery, ignoring aircraft themselves.
	var body:=BoxShape3D.new()
	body.size=Vector3(4.4,3.8,40)
	for step in 330:
		var p:=FLIGHTS.flight_position(step)
		var forward:Vector3=(FLIGHTS.flight_position(step+0.1)-FLIGHTS.flight_position(step-0.1)).normalized()
		if step>=86 and step<=125: forward=Vector3.FORWARD
		var right:=Vector3.UP.cross(forward).normalized()
		var pose:=Basis(right,forward.cross(right).normalized(),forward)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=body
		query.transform=Transform3D(pose,p+Vector3.UP*0.4)
		query.exclude=exclusions
		var hits:=space.intersect_shape(query,1)
		check(hits.is_empty(),"Flight clears scenery at phase %d: %s"%[step,"clear" if hits.is_empty() else str(hits[0].collider.get_path())])
	clock.set_time(0)
	for mat in region._glows: check(mat.emission_energy_multiplier>0,"Airport lamps illuminate at night, including batched runway lights")
	clock.set_time(12)
	for mat in region._glows: check(mat.emission_energy_multiplier==0,"Airport night lamps turn off by day")
	region.elapsed=0
	region.update_air_traffic(0)
	var blink:float=region._strobes[0].material_override.emission_energy_multiplier
	region.update_air_traffic(0.3)
	check(region._strobes[0].material_override.emission_energy_multiplier!=blink,"Aircraft/tower strobes flash")
	region.air_traffic_running=false
	var position:Vector3=region._planes[0].position
	region.update_air_traffic(2)
	check(region._planes[0].position==position,"Air traffic can be frozen for inspection")
	region.air_traffic_running=true
	region.set_physics_process(true)
	paused=true
	var elapsed:float=region.elapsed
	await process_frame
	await process_frame
	check(region.elapsed==elapsed,"Game pause freezes flights")
	paused=false
	var player:Node=load("res://scenes/player.tscn").instantiate()
	check(player.get_node("SpringArm3D/Camera3D").far>=40000,"Playable camera includes distant landscape")
	player.free()
	print("Coastal airport: %d failures; minimum aircraft separation %.1f m"%[failures,minimum_separation])
	city.free()
	quit(0 if failures==0 else 1)

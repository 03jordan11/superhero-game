extends SceneTree
const PATROL = preload("res://assets/aircraft/helicopter/helicopter_patrol.tscn")
var failures := 0
var building_boxes: Array[AABB] = []
var box_names: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var positions: Array[Vector3] = []
	for hz in [30,60,120]:
		for clockwise in [true,false]:
			var p: Node3D = PATROL.instantiate()
			p.clockwise = clockwise
			root.add_child(p)
			p.set_physics_process(false)
			p.aircraft.set_physics_process(false)
			var dt := 1.0/float(hz)
			var maximum_error := 0.0
			var max_heading_error := 0.0
			for frame in range(hz*280):
				p.advance_guidance(dt)
				p.aircraft.advance_flight(dt)
				var offset: Vector3 = p.aircraft.global_position-p.global_position
				maximum_error = maxf(maximum_error,absf(Vector2(offset.x,offset.z).length()-p.orbit_radius))
				var heading: Vector3 = -p.aircraft.global_basis.z
				max_heading_error = maxf(max_heading_error,heading.angle_to(p.aircraft.velocity.normalized()))
			check(maximum_error<3.0,"Orbit drift at %d Hz: %f"%[hz,maximum_error])
			check(max_heading_error<deg_to_rad(2),"Heading must follow the flight path")
			check(absf(p.aircraft.position.y-p.altitude)<.01,"Level flight must hold height")
			check(absf(absf(p.aircraft.bank_degrees)-15.0)<1.0,"Expected coordinated bank")
			check((p.aircraft.bank_degrees<0)==clockwise,"Bank must lean into circle")
			check(p.aircraft.pitch_degrees< -2.0 and p.aircraft.pitch_degrees> -7.0,"Modest forward pitch")
			check(p.aircraft.get_node("Helicopter").rotors_spinning,"Rotors spinning")
			check(p.aircraft.get_node("Helicopter/ParkedCollision").collision_layer==0,"No stationary collider on moving visual")
			if clockwise: positions.append(p.aircraft.global_position)
			print("ORBIT ",hz," Hz clockwise=",clockwise," max_error=",maximum_error," bank=",p.aircraft.bank_degrees)
			# Route changes should accelerate smoothly, not teleport into another circle.
			var previous: Vector3 = p.aircraft.global_position
			p.orbit_radius=150.0
			p.altitude+=30.0
			p.advance_guidance(dt)
			p.aircraft.advance_flight(dt)
			check(p.aircraft.global_position.distance_to(previous)<3.0,"Route changes must not teleport")
			check(p.effective_speed<38.0,"Tight orbit must reduce speed")
			p.patrol_enabled=false
			p._physics_process(dt)
			check(not p.aircraft.is_physics_processing() and not p.visible,"Disable patrol")
			p.free()
	check(positions[0].distance_to(positions[2])<3.0,"Frame-rate consistency")
	# Exercise the reusable velocity controller independently of orbit guidance.
	var flight: Node3D=load("res://assets/aircraft/helicopter/helicopter_flying.tscn").instantiate()
	root.add_child(flight)
	flight.set_physics_process(false)
	flight.initialize_flight(Vector3(0,300,0),Vector3(0,0,-38))
	flight.set_flight_command(Vector3.ZERO)
	var peak_acceleration:=0.0
	for frame in range(1200):
		flight.advance_flight(1.0/60.0)
		peak_acceleration=maxf(peak_acceleration,flight.acceleration.length())
	check(peak_acceleration<=4.001,"Acceleration cap")
	check(flight.velocity.length()<.1,"Can settle into hover with reusable command")
	flight.free()
	# Read actual placed geometry, including transformed roofs and POI props.
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	check(city.has_node("HelicopterPatrol/Aircraft/Helicopter"),"City integrates the reusable aircraft")
	check(city.find_children("HelicopterPatrol","",true,false).size()==1,"Exactly one patrol")
	gather_boxes(city,Transform3D.IDENTITY)
	var highest_under_route:=-1000.0
	var center:=Vector2(0,-150)
	for box_index in building_boxes.size():
		var box := building_boxes[box_index]
		var near_point:=Vector2(clampf(center.x,box.position.x,box.end.x),clampf(center.y,box.position.z,box.end.z))
		var near_distance:=near_point.distance_to(center)
		var far_distance:=0.0
		for x in [box.position.x,box.end.x]:
			for z in [box.position.z,box.end.z]: far_distance=maxf(far_distance,Vector2(x,z).distance_to(center))
		if near_distance<=560 and far_distance>=540:
			highest_under_route=maxf(highest_under_route,box.end.y)
			if box.end.y>=260: print("HIGH_ROUTE_BOX ",box_names[box_index]," ",box)
	check(highest_under_route<260,"Route must clear visible geometry by at least 20 m")
	print("ROUTE_CLEARANCE: ",280-highest_under_route," m above geometry, including 10 m horizontal aircraft allowance")
	city.free()
	print("HELICOPTER_FLIGHT_PASS failures=",failures)
	quit(1 if failures else 0)
func gather_boxes(node: Node, parent_transform: Transform3D) -> void:
	if node.name=="HelicopterPatrol": return
	var transform:=parent_transform
	if node is Node3D: transform=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh!=null:
		# The 60 km coast mesh includes distant mountains in the same AABB.
		# Refine its triangles so those mountains do not inflate central-city height.
		if node.name=="CoastalTerrain":
			var faces: PackedVector3Array=node.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var bounds:=AABB(transform*faces[i],Vector3.ZERO)
				bounds=bounds.expand(transform*faces[i+1]).expand(transform*faces[i+2])
				building_boxes.append(bounds)
				box_names.append("CoastalTerrain triangle")
		else:
			building_boxes.append(transform*node.mesh.get_aabb())
			box_names.append(String(node.get_parent().name)+"/"+String(node.name))
	for child in node.get_children(): gather_boxes(child,transform)

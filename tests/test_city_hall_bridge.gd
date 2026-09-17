extends SceneTree
var failures := 0
var probes := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func deck_height(x: float) -> float:
	var z := clampf(x-162,-160,160)
	var a := clampf(floorf(z/20)*20,-160,140)
	var t := (z-a)/20
	return lerpf(design_height(a),design_height(a+20),t)
func design_height(z: float) -> float:
	var t := clampf((160-absf(z))/80,0,1)
	return .03+8*t*t*(3-2*t)
func run() -> void:
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:city.get_node(label).free()
	root.add_child(city)
	await process_frame
	await physics_frame
	await physics_frame
	var bridge: Node3D = city.get_node("CityHallBridge")
	check(bridge.get_node("WestRoadJoin").global_position.is_equal_approx(Vector3(2,.03,-320)),"West join meets City Hall avenue")
	check(bridge.get_node("EastRoadJoin").global_position.is_equal_approx(Vector3(322,.03,-320)),"East join meets Junction_463")
	var triangles := 0
	for node in bridge.find_children("*","MeshInstance3D",true,false):
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():triangles += mesh.surface_get_array_index_len(i)/3 if mesh.surface_get_array_index_len(i) else mesh.surface_get_array_len(i)/3
	check(triangles < 2500 and triangles == bridge.get_meta("rendered_triangles"),"Complete imported bridge under 2500 triangles")
	var space := city.get_world_3d().direct_space_state
	for x in range(4,321,4):
		for across in [-16.0,-12.0,-6.0,0.0,6.0,12.0,16.0]:
			var y := deck_height(x)
			if absf(across)>14:y += .15*minf(1,(160-absf(x-162))/20)
			var point := Vector3(x,y,-320+across)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2))
			check(not hit.is_empty() and absf(hit.position.y-y)<.2 and hit.normal.y>.9,"Unobstructed deck/sidewalk at "+str(point))
			probes+=1
	var minimum_clearance := INF
	# Test the full widths of both curved promenades, including the river edges.
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	for z in range(-338,-301,2):
		var index := int(floorf((z+1000.0)/10.0))
		var a: Array = layout.river_curve_rows[index]
		var b: Array = layout.river_curve_rows[index+1]
		var t: float = (z-float(a[0]))/10.0
		for bank in [0,1]:
			var edge: float = lerpf(a[bank+1],b[bank+1],t)
			for inset in [1.0,3.0,6.0,9.0,11.0]:
				var x: float = edge+(-inset if bank==0 else inset)
				var p := Vector3(x,.15,z)
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP))
				check(not ground.is_empty() and ground.position.y>-.1,"Original promenade floor remains at "+str(p))
				var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p+Vector3.UP*15))
				check(not roof.is_empty(),"Bridge spans promenade at "+str(p))
				if not roof.is_empty() and not ground.is_empty():minimum_clearance=minf(minimum_clearance,roof.position.y-ground.position.y)
				probes+=1
	check(minimum_clearance>6.5,"Both river sidewalks retain generous headroom: %.3f m"%minimum_clearance)
	await walk(Vector3(4,1.3,-320),Vector3(320,1.3,-320),12,"west-to-east road")
	await walk(Vector3(320,1.3,-320),Vector3(4,1.3,-320),12,"east-to-west road")
	await walk(Vector3(4,1.3,-304),Vector3(320,1.3,-304),12,"bridge sidewalk")
	for x in [110.5714,226.5714]:
		await walk(Vector3(x,1.3,-350),Vector3(x,1.3,-290),6,"river promenade below bridge")
		await walk(Vector3(x,1.3,-290),Vector3(x,1.3,-350),6,"river promenade reverse")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	check(main.has_node("SuperCity/CityHallBridge"),"Main includes City Hall bridge")
	main.free()
	print("CITY_HALL_BRIDGE: %d triangles; %d surface/clearance probes; minimum clearance %.3f m; seven capsule crossings; %d failures"%[triangles,probes,minimum_clearance,failures])
	city.free();quit(1 if failures else 0)
func walk(start: Vector3, finish: Vector3, speed: float, label: String) -> void:
	var walker := CharacterBody3D.new();walker.position=start;walker.floor_snap_length=.4
	var shape := CollisionShape3D.new();var capsule := CapsuleShape3D.new()
	capsule.height=2;capsule.radius=.45;shape.shape=capsule;walker.add_child(shape);root.add_child(walker)
	for i in 2100:
		await physics_frame
		var delta := finish-walker.position;delta.y=0
		if delta.length()<.3:break
		var velocity := delta.normalized()*speed
		walker.velocity.x=velocity.x;walker.velocity.z=velocity.z;walker.velocity.y-=20.0/60
		walker.move_and_slide()
	check(Vector2(walker.position.x-finish.x,walker.position.z-finish.z).length()<.5 and walker.position.y>0,label+" reached "+str(walker.position))
	walker.free()

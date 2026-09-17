extends SceneTree
var failures := 0
var probes := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:city.get_node(label).free()
	root.add_child(city)
	await process_frame
	await physics_frame
	await physics_frame
	var bridge: Node3D = city.get_node("NorthRiverBridge")
	check(bridge.get_node("WestRoadJoin").global_position.is_equal_approx(Vector3(116,.03,-960)),"West join meets northern west road")
	check(bridge.get_node("EastRoadJoin").global_position.is_equal_approx(Vector3(274,.03,-960)),"East join meets northern east road")
	var triangles := 0
	for node in bridge.find_children("*","MeshInstance3D",true,false):
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():triangles += mesh.surface_get_array_index_len(i)/3 if mesh.surface_get_array_index_len(i) else mesh.surface_get_array_len(i)/3
	check(triangles < 2500 and triangles == bridge.get_meta("rendered_triangles"),"Complete imported bridge under 2500 triangles")
	var space := city.get_world_3d().direct_space_state
	for x in range(118,273,2):
		for across in [-12.0,-8.0,0.0,8.0,12.0]:
			var y := .03
			var point := Vector3(x,y,-960+across)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.8,point-Vector3.UP*.8))
			check(not hit.is_empty() and absf(hit.position.y-y)<.2 and hit.normal.y>.9,"Deck/sidewalk at "+str(point))
			probes+=1
	# Verify neighboring existing roads meet both joins at the same height.
	for x in [115.0,275.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,2,-960),Vector3(x,-2,-960)))
		check(not hit.is_empty() and absf(hit.position.y-.03)<.15,"Existing road surface at "+str(x))
	await walk(Vector3(114,1.3,-960),Vector3(276,1.3,-960),12,"west-to-east road with both joins")
	await walk(Vector3(276,1.3,-960),Vector3(114,1.3,-960),12,"east-to-west road with both joins")
	await walk(Vector3(118,1.3,-948),Vector3(272,1.3,-948),12,"bridge sidewalk")
	for x in [136.0,252.0]:
		await walk(Vector3(x+6,1.3,-920),Vector3(x,1.3,-948),6,"city promenade to bridge walkway")
		await walk(Vector3(x,1.3,-948),Vector3(x+6,1.3,-920),6,"bridge walkway to city promenade")
	var quay: Mesh = city.get_node("RiverFrontage/Quay").mesh
	for surface in quay.get_surface_count():
		for vertex in quay.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			check(vertex.z >= -946.0,"No promenade overlaps the northern bridge or continues north")
	var quay_shape: ConcavePolygonShape3D = city.get_node("RiverFrontage/Quay/Solid/CollisionShape3D").shape
	for vertex in quay_shape.get_faces():
		check(vertex.z >= -946.0,"Removed promenade has no leftover collision")
	var reference: Mesh = load("res://assets/bridges/south_suspension/meshes/Towers.res")
	var railing: Mesh = city.get_node("RiverFrontage/Rail").mesh
	for surface in railing.get_surface_count():
		var arrays := railing.surface_get_arrays(surface)
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			check(vertex.z >= -946.0,"No old river railing inside bridge footprint")
	var red: Material = reference.surface_get_material(0)
	for name in ["CityHallBridge", "NorthRiverBridge"]:
		var frame: MeshInstance3D = city.get_node(name+"/Arches")
		var material: Material = frame.mesh.surface_get_material(0)
		check(material.albedo_color.is_equal_approx(red.albedo_color),name+" matches southern bridge red")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	check(main.has_node("SuperCity/NorthRiverBridge"),"Main includes northern bridge")
	main.free()
	print("NORTH_BRIDGE: %d triangles; %d surface probes; seven capsule crossings; %d failures"%[triangles,probes,failures])
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

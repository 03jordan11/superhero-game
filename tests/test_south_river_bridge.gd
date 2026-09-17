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
	for label in ["TrafficManager", "CivilianCrowd", "Sound", "PreviewCamera"]: city.get_node(label).free()
	root.add_child(city)
	var bridge: Node3D = city.get_node("SouthRiverBridge")
	await process_frame
	await physics_frame
	await physics_frame
	print("BRIDGE_JOINS: ", bridge.get_node("WestRoadJoin").global_position, " / ", bridge.get_node("EastRoadJoin").global_position)
	check(not city.has_node("WaterPlaceholders"), "Unused river placeholder removed")
	check(not city.has_node("Landmarks/CentralPark_GreenPlaceholder"), "Unused park placeholder removed")
	check(city.has_node("Landmarks/CentralPark") and city.has_node("RiverFrontage") and city.has_node("Waterfront"), "Replacement park and river remain")
	check(bridge.get_node("WestRoadJoin").global_position.is_equal_approx(Vector3(2,.03,760)), "West approach meets Junction_451")
	check(bridge.get_node("EastRoadJoin").global_position.is_equal_approx(Vector3(500,.03,760)), "East end meets Straight_177_0")
	var total := 0
	for mesh_node in bridge.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_node.mesh
		for i in mesh.get_surface_count():
			total += mesh.surface_get_array_index_len(i) / 3 if mesh.surface_get_array_index_len(i) else mesh.surface_get_array_len(i) / 3
	check(total <= 10000 and total == bridge.get_meta("rendered_triangles"), "Complete highest-detail bridge including approach respects triangle budget")
	check(bridge.get_node("RoadDeck").mesh.surface_get_material(0).shader.resource_path == "res://assets/super-city/modular-roads/road.gdshader", "Deck reuses existing modular road markings and asphalt")
	check_hanger_connections(bridge)
	var space := city.get_world_3d().direct_space_state
	# Probe across both road joins, all travel lanes and both sidewalk strips.
	for x in range(-8,513,4):
		var t := clampf((200.0-absf(float(x)-300.0))/95.0,0,1)
		var top := .03 + 15*t*t*(3-2*t) if x >= 100 and x <= 500 else .03
		for across in [-12.0,-8.0,-3.0,0.0,3.0,8.0,12.0]:
			var expected := top + (.15 if absf(across)>10 and x >= 100 and x <= 500 else 0.0)
			var p := Vector3(x,expected,760+across)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*4,p-Vector3.UP*2))
			check(not hit.is_empty() and absf(hit.position.y-expected)<.3 and hit.normal.y>.85, "Continuous unobstructed surface at %s (hit %s)" % [p,hit.get("position","none")])
			probes += 1
	# The raised deck leaves the river navigable beneath the central span.
	var clearance := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(300,8,730),Vector3(300,8,790)))
	check(clearance.is_empty(), "Open passage below bridge center")
	await walk_across(Vector3(10,1.3,760), 510.0)
	await walk_across(Vector3(510,1.3,760), 10.0)
	await walk_across(Vector3(10,1.4,772), 510.0)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	check(main.has_node("SuperCity/SouthRiverBridge"), "Gameplay Main includes the bridge")
	main.free()
	print("SOUTH_BRIDGE: %d triangles, %d collision probes, %d failures" % [total, probes, failures])
	city.free(); quit(1 if failures else 0)

func walk_across(start: Vector3, finish_x: float) -> void:
	var walker := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 2.0; capsule.radius = .45
	collision.shape = capsule; walker.add_child(collision)
	walker.floor_snap_length = .4; walker.position = start
	root.add_child(walker)
	var direction := signf(finish_x-start.x)
	for frame in 3000:
		await physics_frame
		if (finish_x-walker.position.x)*direction <= .3: break
		walker.velocity.x = direction*12
		walker.velocity.y -= 20.0/60.0
		walker.move_and_slide()
	check(absf(walker.position.x-finish_x)<.5 and walker.position.y>0, "Player-sized capsule crosses from %s to x=%.1f; reached %s" % [start,finish_x,walker.position])
	walker.free()

func check_hanger_connections(bridge: Node3D) -> void:
	# Derive the actual hanger endpoints from imported geometry, not authoring data.
	var endpoints := {}
	var hangers: Mesh = bridge.get_node("Hangers").mesh
	for vertex in hangers.get_faces():
		var key := Vector2(roundf(vertex.x), snappedf(vertex.z,10.0))
		var limits: Vector2 = endpoints.get(key, Vector2(INF,-INF))
		endpoints[key] = Vector2(minf(limits.x,vertex.y),maxf(limits.y,vertex.y))
	var brackets: PackedVector3Array = bridge.get_node("DeckStructure").mesh.get_faces()
	var cables: PackedVector3Array = bridge.get_node("MainCables").mesh.get_faces()
	var tower_faces: PackedVector3Array = bridge.get_node("Towers").mesh.get_faces()
	check(endpoints.size() == 70, "All 70 suspension hangers remain")
	for key: Vector2 in endpoints:
		var limits: Vector2 = endpoints[key]
		check(enclosed_vertically(Vector3(key.x,limits.x,key.y),brackets), "Hanger bottom embedded in deck bracket at " + str(key))
		check(enclosed_vertically(Vector3(key.x,limits.y,key.y),cables), "Hanger top embedded in main cable at " + str(key))
	# The four main-cable ends must enter the existing solid anchorage caps.
	for side in [-1,1]:
		for end in [-192,192]:
			check(enclosed_vertically(Vector3(side*16,2.7,end),tower_faces), "Main cable seated in anchor cap")
	print("BRIDGE_ATTACHMENTS: checked 70 hangers at both ends and 4 anchor caps")

func enclosed_vertically(point: Vector3, faces: PackedVector3Array) -> bool:
	var below := false
	var above := false
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(point-Vector3.UP*3,point+Vector3.UP*3,faces[i],faces[i+1],faces[i+2])
		if hit == null: continue
		if hit.y < point.y-.001: below = true
		if hit.y > point.y+.001: above = true
	return below and above

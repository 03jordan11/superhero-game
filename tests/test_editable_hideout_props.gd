extends SceneTree
const BASE := "res://assets/buildings/gas_station_hideout/"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func run() -> void:
	var room := (load(BASE + "gas_station_interior.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(room)
	current_scene = room
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "interior_manifest.json"))
	var props := room.get_node("Model/Props")
	var found := {}
	for node: Node in props.find_children("*", "", true, false):
		if node.has_meta("interior_prop"):
			found[String(node.get_meta("interior_prop"))] = node
			check(node.owner == room, "Prop is locally editable: " + String(node.name))
			check(node.has_node("Mesh") and node.get_node("Mesh").owner == room, "Prop mesh is local: " + String(node.name))
	check(found.size() == manifest.props.size(), "All complete furnishings are separate")
	for definition: Dictionary in manifest.collision_boxes:
		if definition.has("prop"):
			var node: Node3D = found[String(definition.prop)]
			check(node.has_node("Collision/Shape"), "Collision follows " + String(node.name))
	check(room.get_node("RoomCollision").get_child_count() == 14, "Only room-shell collision remains at room level")
	check(found.Workbench.has_node("Toolbox") and found.Workbench.has_node("BenchVise"), "Workbench items follow their parent")
	check(found.Desk.has_node("Keyboard"), "Desk equipment follows its parent")
	check(found.StorageRack1.has_node("Rack1Crate1"), "Crates follow their rack")
	for index in 4:
		check(found["CeilingFixture%d" % index].has_node("CeilingLight%d" % index), "Ceiling lamp follows fixture")
	var machine := room.get_node("power_machine") as Node3D
	var machine_bounds := bounds(machine).grow(-0.01)
	for prop_name: String in found:
		if String(prop_name).begins_with("CeilingFixture"): continue
		check(not machine_bounds.intersects(bounds(found[prop_name])), "Machine has visual clearance from " + prop_name)
	# Verify preservation against the pre-edit scene only when explicitly requested.
	if "--baseline" in OS.get_cmdline_user_args():
		var before := (load("res://artifacts/interior-prop-edit/before_interior.tscn") as PackedScene).instantiate()
		check(machine.transform.is_equal_approx(before.get_node("power_machine").transform), "User's exact machine transform preserved")
		for path in ["PlayerSpawn", "ExitDoor"]:
			check(room.get_node(path).transform.is_equal_approx(before.get_node(path).transform), "Original marker preserved: " + path)
		for index in 4:
			var lamp: Node3D = found["CeilingFixture%d" % index].get_node("CeilingLight%d" % index)
			check(lamp.global_transform.is_equal_approx(before.get_node("CeilingLight%d" % index).transform), "Original light placement preserved")
		before.free()
	await physics_frame
	await physics_frame
	var space := room.get_world_3d().direct_space_state
	var bench: Node3D = found.Workbench
	var body: StaticBody3D = bench.get_node("Collision")
	var point: Vector3 = bench.get_node("Collision/Shape").global_position
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0, 1.5), point, 1)
	var hit := space.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == body, "Workbench collision moved to new layout")
	var old_transform := bench.transform
	bench.position.z += 1.5
	await physics_frame
	await physics_frame
	point = bench.get_node("Collision/Shape").global_position
	ray = PhysicsRayQueryParameters3D.create(point + Vector3(0, 0, 1.5), point, 1)
	hit = space.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == body, "Moving a prop moves its physics collision")
	bench.transform = old_transform
	var triangles := 0
	var surfaces := 0
	for mesh: MeshInstance3D in room.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var count: int = mesh.mesh.surface_get_array_index_len(surface)
			triangles += int((count if count > 0 else mesh.mesh.surface_get_array_len(surface)) / 3)
			surfaces += 1
	check(triangles + 2200 <= 10000, "Entire furnished station remains within POI triangle budget")
	var report := {"props":found.size(), "interior_with_machine_triangles":triangles, "interior_surfaces":surfaces,
		"complete_poi_triangles":triangles + 2200, "failures":failures}
	var file := FileAccess.open(BASE + "editable_props_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	if "--render" in OS.get_cmdline_user_args():
		await render_views(room)
	print("EDITABLE_PROPS_TEST ", JSON.stringify(report))
	room.free()
	quit(1 if failures else 0)

func render_views(room: Node3D) -> void:
	root.size = Vector2i(1440, 1000)
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.current = true
	camera.fov = 82
	for view in [["machine_clearance", Vector3(1.9, 2.7, -3.6), Vector3(3.5, 1.6, -8)],
		["garage_layout", Vector3(-2.6, 3.0, -1.1), Vector3(4.0, 1.6, -6.7)],
		["office_props", Vector3(-4.1, 2.4, -1), Vector3(-8, 1.6, -5)]]:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/interior-prop-edit/" + String(view[0]) + ".png")
	camera.free()

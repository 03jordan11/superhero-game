extends SceneTree
const OUT := "res://assets/bridges/south_suspension/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source: Node3D = load(OUT + "south_suspension.glb").instantiate()
	var bridge := Node3D.new()
	bridge.name = "SouthRiverBridge"
	var road := ShaderMaterial.new()
	road.shader = load("res://assets/super-city/modular-roads/road.gdshader")
	road.set_shader_parameter("asphalt", load("res://assets/super-city/textures/junction_20_20_15.res"))
	road.set_shader_parameter("width_m", 20.0)
	road.set_shader_parameter("length_m", 400.0)
	ResourceSaver.save(road, OUT + "bridge_road.tres", ResourceSaver.FLAG_CHANGE_PATH)
	road.take_over_path(OUT + "bridge_road.tres")
	DirAccess.make_dir_recursive_absolute(OUT + "meshes")
	var total := 0
	var counts := {}
	for original in source.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = original.mesh.duplicate()
		if original.name == &"RoadDeck": mesh.surface_set_material(0, road)
		if original.name == &"Walkways": mesh.surface_set_material(0, load("res://assets/super-city/modular-sidewalks/sidewalk.tres"))
		var count := 0
		for surface in mesh.get_surface_count():
			count += mesh.surface_get_array_index_len(surface) / 3 if mesh.surface_get_array_index_len(surface) else mesh.surface_get_array_len(surface) / 3
		counts[str(original.name)] = count
		total += count
		var path := OUT + "meshes/" + str(original.name)
		ResourceSaver.save(mesh, path + ".res", ResourceSaver.FLAG_CHANGE_PATH)
		mesh.take_over_path(path + ".res")
		var display := MeshInstance3D.new()
		display.name = original.name
		display.mesh = mesh
		display.transform = original.transform
		bridge.add_child(display); display.owner = bridge
		if original.name not in [&"MainCables", &"Hangers", &"TowerRecesses"]:
			var body := StaticBody3D.new()
			body.name = "Solid"
			display.add_child(body); body.owner = bridge
			if original.name in [&"RoadDeck", &"Walkways"]:
				# Solid wedges avoid triangle-edge precision gaps on the long ramps.
				# Profile is exported alongside the mesh by Blender, in metres.
				var profile: Array = JSON.parse_string(FileAccess.get_file_as_string(OUT + "deck_profile.json"))
				var strips: Array = [[-10.0, 10.0, 0.0]] if original.name == &"RoadDeck" else [[-14.0, -10.0, .15], [10.0, 14.0, .15]]
				for strip in strips:
					for i in profile.size()-1:
						var a: Array = profile[i]
						var b: Array = profile[i+1]
						var ay: float = a[1] + (a[2] if strip[2] > 0 else 0)
						var by: float = b[1] + (b[2] if strip[2] > 0 else 0)
						var slope: float = (by-ay)/(b[0]-a[0])
						var points := PackedVector3Array()
						for end in [[a[0]-.002, ay-.002*slope], [b[0]+.002, by+.002*slope]]:
							for x in [strip[0],strip[1]]:
								for depth in [0.0, -.55]: points.append(Vector3(x,end[1]+depth,end[0]))
						var collision := CollisionShape3D.new()
						collision.name = "DeckSection%d_%d" % [int(strip[0]),i]
						var shape := ConvexPolygonShape3D.new(); shape.points = points; shape.margin = .001
						collision.shape = shape
						body.add_child(collision); collision.owner = bridge
				continue
			var collision := CollisionShape3D.new()
			collision.name = "Collision"
			collision.shape = mesh.create_trimesh_shape()
			ResourceSaver.save(collision.shape, path + "_collision.res", ResourceSaver.FLAG_CHANGE_PATH)
			collision.shape.take_over_path(path + "_collision.res")
			body.add_child(collision); collision.owner = bridge
	var approach = load("res://assets/super-city/modular-roads/straight_20m.tscn").instantiate()
	approach.name = "WestApproach"
	approach.length_m = 98.0
	approach.position = Vector3(0, 0, -249)
	bridge.add_child(approach); approach.owner = bridge
	# Build the actual exported geometry before counting the complete POI.
	root.add_child(bridge)
	approach.rebuild()
	var approach_mesh: Mesh = approach.get_node("Mesh").mesh
	var approach_count := 0
	for i in approach_mesh.get_surface_count():
		approach_count += approach_mesh.surface_get_array_index_len(i) / 3 if approach_mesh.surface_get_array_index_len(i) else approach_mesh.surface_get_array_len(i) / 3
	counts["WestApproach"] = approach_count
	total += approach_count
	assert(total <= 10000, "Complete bridge exceeds triangle limit")
	bridge.set_meta("rendered_triangles", total)
	bridge.set_meta("blender_source", OUT + "south_suspension.blend")
	for entry in [["WestRoadJoin", Vector3(0, .03, -298)], ["EastRoadJoin", Vector3(0, .03, 200)]]:
		var marker := Marker3D.new(); marker.name = entry[0]; marker.position = entry[1]
		bridge.add_child(marker); marker.owner = bridge
	var packed := PackedScene.new()
	assert(packed.pack(bridge) == OK)
	assert(ResourceSaver.save(packed, OUT + "south_river_bridge.tscn") == OK)
	var f := FileAccess.open(OUT + "triangle_audit.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"source":"Godot imported GLB highest-detail index buffers plus rebuilt approach", "meshes":counts,"total":total}, "\t")); f.close()
	print("BRIDGE_IMPORTED_TRIANGLES: ", total)
	source.free(); bridge.free(); quit()

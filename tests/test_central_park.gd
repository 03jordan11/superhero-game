extends SceneTree
const LAYOUT = preload("res://assets/central-park/tools/park_layout.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	# Check serialized buffers too: instance_count alone cannot catch a headless bake
	# that silently loses all foliage and firefly transforms.
	var scene_text := FileAccess.get_file_as_string("res://scenes/central_park.tscn")
	check(scene_text.count("buffer = PackedFloat32Array(") == scene_text.count("[sub_resource type=\"MultiMesh\""), "Every baked MultiMesh retains its transform buffer")
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(label).free()
	root.add_child(city)
	var park := city.get_node("Landmarks/CentralPark") as Node3D
	var cycle = city.get_node("DayNightCycle")
	cycle.cycle_running = false
	await process_frame
	await physics_frame
	await physics_frame
	check(not city.has_node("Landmarks/CentralPark_GreenPlaceholder"), "Obsolete park placeholder removed")
	check(park.get_meta("tree_count")==400,"First pass retains 400 trees (over two thirds removed)")
	var loaded_trees := preload("res://assets/trees/tools/tree_instances.gd").trees(park)
	check(loaded_trees.size() == 400,"Individual tree scenes retain all placements")
	check(park.get_node("TreeCollisions").get_child_count() == 0,"No separate ghost trunk collisions")
	for tree in loaded_trees:
		check(not tree.get_node("TrunkBody/CollisionShape3D").disabled,"Park trees own their active collisions")
	for pattern in ["*Mushroom*", "*Mooncap*", "*ShoreBoulder*", "*WhisperingStone*", "*StarlitGrotto*", "*Wisps*", "*MysticGlow*"]:
		check(park.find_children(pattern, "", true, false).is_empty(), "Removed decoration stays absent: " + pattern)
	check(park.get_node("Houses").get_child_count()==3,"Three discoverable houses")
	check(park.get_node("Fireflies").multimesh.instance_count==700,"Batched fireflies load")
	check(park.get_node("Foliage/Undergrowth").multimesh.instance_count==140,"Exactly half the bushes remain")
	for species_name in ["oak","birch","pine","willow"]:
		check((load("res://assets/central-park/meshes/tree_%s.res" % species_name) as Mesh).get_faces().size()/3 <= 100,"%s remains within 100 triangles" % species_name)
	check(park.get_node("Foliage/Undergrowth").multimesh.mesh.get_faces().size()/3 <= 20,"Bush remains within 20 triangles")
	var bush_mesh: Mesh = park.get_node("Foliage/Undergrowth").multimesh.mesh
	var bush_faces := bush_mesh.get_faces()
	for i in range(0,bush_faces.size(),3):
		var a := bush_faces[i]
		var b := bush_faces[i+1]
		var c := bush_faces[i+2]
		check((c-a).cross(b-a).dot((a+b+c)/3.0-bush_mesh.get_aabb().get_center()) > 0,"Shrub faces point outward rather than disappearing from outside")
	for lantern in park.get_node("Lanterns").get_children():
		check(lantern.find_children("Frame*", "MeshInstance3D",true,false).is_empty(),"Lantern frame bars removed")
		check(lantern.get_node("Post").mesh is BoxMesh and lantern.get_node("Base").mesh is BoxMesh,"Lantern post and base are boxes")
	var bridge: Node3D = park.get_node("Landmarks/BowBridge")
	check(bridge.find_children("Handrail*","MeshInstance3D",true,false).is_empty() and bridge.find_children("Baluster*","MeshInstance3D",true,false).is_empty(),"Individual railing geometry removed")
	check(bridge.get_node("TexturedRailings").mesh.get_faces().size()/3 == 80,"Flat bridge rail panels use 80 triangles")
	var rail_mat: StandardMaterial3D = bridge.get_node("TexturedRailings").mesh.surface_get_material(0)
	check(rail_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and rail_mat.cull_mode == BaseMaterial3D.CULL_DISABLED,"Railings use double-sided cutout texture")
	var ground_mesh: Mesh = park.get_node("Terrain/Ground/MeshInstance3D").mesh
	var ground_faces := ground_mesh.get_faces()
	check(ground_faces.size()/3 >= 19177 and ground_faces.size()/3 <= 25569,"Terrain has one third to one half fewer triangles")
	check(ground_mesh.surface_get_material(0).albedo_texture != null,"Patchy grass is retained independently of terrain subdivision")
	# Interior edges must meet in pairs, including 4 m / 8 m transitions.
	var ground_edges: Dictionary = {}
	for index in range(0,ground_faces.size(),3):
		for corner in 3:
			var a := ground_faces[index+corner]
			var b := ground_faces[index+(corner+1)%3]
			if (is_equal_approx(a.x,b.x) and is_equal_approx(absf(a.x),254.0)) or (is_equal_approx(a.z,b.z) and is_equal_approx(absf(a.z),302.0)): continue
			var sa := str(a.snapped(Vector3.ONE*.0001))
			var sb := str(b.snapped(Vector3.ONE*.0001))
			var key := sa+"/"+sb if sa<sb else sb+"/"+sa
			ground_edges[key] = int(ground_edges.get(key,0))+1
	for count: int in ground_edges.values():
		check(count == 2,"Adaptive terrain has no unmatched interior edges")
	var space := park.get_world_3d().direct_space_state
	var center: Vector3 = park.to_global(Vector3(32,0,-54))
	var lake_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*10,center+Vector3.DOWN*10))
	check(not lake_hit.is_empty() and lake_hit.position.y < -2.5,"Lake has a real depressed bed, not a solid water surface")
	var tested := 0
	for path in LAYOUT.paths():
		var points: PackedVector2Array = path.points
		for i in range(1,points.size()-1,8):
			var p := points[i]
			var point := park.to_global(Vector3(p.x,LAYOUT.height(p),p.y))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.0,point+Vector3.DOWN*1.0))
			check(not hit.is_empty(),"Trail has walkable ground: "+str(path.name))
			if not hit.is_empty(): check(hit.normal.y>0.75,"Trail slope remains walkable: "+str(path.name))
			tested += 1
	for x in range(-45,113,12):
		var point := park.to_global(Vector3(x,15,18))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*22))
		check(not hit.is_empty() and hit.position.y>0.2,"Bridge deck supports traversal over water")
		if not hit.is_empty():
			for side in [-1,1]:
				var rail_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hit.position+Vector3.UP*.65,hit.position+Vector3(0,.65,side*4)))
				check(not rail_hit.is_empty() and rail_hit.collider == bridge.get_node("RailingCollision"),"Textured railing retains a solid guard")
	for house in park.get_node("Houses").get_children():
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(house.to_global(Vector3(0,1.6,7.8)),house.to_global(Vector3(0,1.6,0))))
		check(hit.is_empty(),"House doorway is open: "+house.name)
		await probe_walk(house.to_global(Vector3(0,1.2,9.5)), house.to_global(Vector3(0,1.2,1)), "Walking into "+house.name)
	var dock := park.get_node("Landmarks/MoonwaterDock") as Node3D
	await probe_walk(dock.to_global(Vector3(8,1.3,0)),dock.to_global(Vector3(-5,1.3,0)),"Walking onto the dock")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/central-park/layout.json"))
	var species: Dictionary = {}
	for tree in manifest.trees:
		var p := Vector2(tree.x,tree.z)
		check(LAYOUT.BOUNDS.has_point(p) and LAYOUT.lake_radius(p)>=1.24,"Trees stay on park land")
		check(not LAYOUT.in_meadow(p, 13.0),"Meadow is clear of trunks and canopy overhang")
		species[tree.kind]=true
	check(species.size()==4,"Oak, pine, birch and willow are all present")
	cycle.set_time(12.0)
	check(not park.get_node("Fireflies").visible,"No fireflies during day")
	for light in park._lights: check(not light.visible,"Park lights off by day")
	cycle.set_time(0.0)
	check(park.get_node("Fireflies").visible,"Warm fireflies appear at night")
	for light in park._lights: check(light.visible,"Park night lights on")
	var elapsed: float = park._elapsed
	paused = true
	await process_frame
	await process_frame
	check(is_equal_approx(elapsed,park._elapsed),"Game pause freezes water and firefly animation")
	paused = false
	park.fireflies_enabled=false
	park.apply_night(1.0)
	check(not park.get_node("Fireflies").visible,"Fireflies can be disabled independently of lanterns")
	for offset in [Vector2.ZERO, Vector2(-55,0), Vector2(55,0), Vector2(0,35), Vector2(0,-35)]:
		var p: Vector2 = LAYOUT.MEADOW + offset
		var meadow_point := park.to_global(Vector3(p.x,5,p.y))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(meadow_point,meadow_point+Vector3.DOWN*10))
		check(not hit.is_empty() and hit.normal.y > .95,"Meadow has gently graded walkable ground")
	print("Central Park: %d trail probes, %d failures"%[tested,failures])
	city.free()
	quit(0 if failures==0 else 1)

func probe_walk(start: Vector3, finish: Vector3, label: String) -> void:
	var walker := CharacterBody3D.new()
	walker.position = start
	walker.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 2.0
	capsule.radius = 0.5
	collision.shape = capsule
	walker.add_child(collision)
	root.add_child(walker)
	for frame in 300:
		await physics_frame
		var remaining := finish-walker.position
		remaining.y=0
		if remaining.length()<0.4: break
		var direction := remaining.normalized()*3.0
		walker.velocity.x=direction.x
		walker.velocity.z=direction.z
		walker.velocity.y -= 20.0/60.0
		walker.move_and_slide()
	var distance := Vector2(walker.position.x-finish.x,walker.position.z-finish.z).length()
	check(distance<0.7,label+" (remaining %.2f m)"%distance)
	walker.free()

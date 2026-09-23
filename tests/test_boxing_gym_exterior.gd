extends SceneTree
const BASE := "res://assets/buildings/boxing_gym/"
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var building := (load(BASE+"boxing_gym_exterior.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(building)
	await physics_frame
	await physics_frame
	var total := 0
	var bounds := AABB()
	var first := true
	for mi: MeshInstance3D in building.find_children("*","MeshInstance3D",true,false):
		total += mi.mesh.get_faces().size()/3
		var box: AABB = mi.global_transform * mi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	check(total > 0 and total <= 10000,"Actual complete exterior fits 10k POI budget")
	check(total == int(building.get_meta("rendered_triangles")),"Audit matches imported geometry")
	check(bounds.size.x < 25.3 and bounds.size.x > 24.8,"Width matches hall plus exterior trim")
	check(bounds.size.z < 24.8 and bounds.size.z > 22.8,"Depth includes entrance canopy")
	check(bounds.size.y < 9.5 and bounds.size.y > 8.8,"Double-height volume plus parapet and roof equipment")
	check(building.get_node("FrontDoor").position.is_equal_approx(Vector3(0,0,11.48)),"Front entrance aligns with indoor door")
	check(building.get_node("RearDoor").position.is_equal_approx(Vector3(-8.65,0,-11.47)),"Rear entrance aligns with indoor rear door")
	for x in [-6.9,6.9]:
		var window: Node3D = building.get_node("FrontWindowLeft" if x<0 else "FrontWindowRight")
		check(window.position.is_equal_approx(Vector3(x,1.82,11.47)),"Front windows align with hall glazing")
	check(building.find_children("UpperWindow*","Node3D",false,false).size()==6,"Six upper side windows match boarded indoor windows")
	check(building.find_children("*","Camera3D",true,false).is_empty(),"Placeable asset contains no preview camera")
	check(building.find_children("*","WorldEnvironment",true,false).is_empty(),"Placeable asset inherits city lighting")
	check(building.find_children("*","CharacterBody3D",true,false).is_empty(),"No player or interior included")
	check(building.get_node("GymEntrance").is_in_group(&"hideout_doors"),"Gym entrance uses existing door interaction")
	var space := building.get_world_3d().direct_space_state
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,10,0),Vector3(0,7,0)))
	check(not roof.is_empty() and absf(roof.position.y-8.2)<.02,"Solid traversable roof")
	var facade := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,13),Vector3(0,1,10)))
	check(not facade.is_empty(),"Closed front facade collision")
	for key: String in ["FrontEntry","FrontReturn","RearEntry"]:
		var p: Vector3 = building.get_node(key).global_position
		check(space.intersect_ray(PhysicsRayQueryParameters3D.create(p-Vector3.UP*.9,p+Vector3.UP*1.1)).is_empty(),"Future entry marker has standing clearance: "+key)
	var unit := building.get_node("RoofUnit1") as Node3D
	var old := unit.position
	unit.position.x -= 5
	await physics_frame
	await physics_frame
	var cleared := space.intersect_ray(PhysicsRayQueryParameters3D.create(old+Vector3.UP*2,old-Vector3.UP*.1))
	check(not cleared.is_empty() and absf(cleared.position.y-8.2)<.02,"Moving roof prop moves collision with it")
	print("GYM_EXTERIOR_TEST triangles=",total," bounds=",bounds," failures=",failures.size())
	building.free()
	quit(0 if failures.is_empty() else 1)

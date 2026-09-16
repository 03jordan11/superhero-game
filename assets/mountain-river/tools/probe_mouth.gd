extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for child in main.get_children():
		if child.name not in ["SuperCity","MountainRiver"]:child.free()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:main.get_node("SuperCity/"+label).free()
	root.add_child(main);await physics_frame;await physics_frame
	print("South wall ",main.get_node("SuperCity/Waterfront/Riverbanks/QuayWall172").transform)
	var space:=main.get_world_3d().direct_space_state
	for x in [270,320,420]:
		for z in [780,790,799.9,800.0,800.1]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,5,z),Vector3(x,-15,z)))
			if not hit.is_empty():print("FLOOR ",x," ",z," ",hit.position," ",hit.collider.get_path())
	for n in main.get_node("SuperCity/Districts/FinancialQuarter").get_children():
		if n.name not in ["FinancialQuarter_1397","FinancialQuarter_1401"]:continue
		var c: CollisionShape3D=n.get_node("CollisionShape3D");print(n.name," COLLISION ",(n.transform*c.transform)*AABB(-c.shape.size*.5,c.shape.size))
	main.free();quit()

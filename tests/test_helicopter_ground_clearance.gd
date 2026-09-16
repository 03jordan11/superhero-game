extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func surface(world: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new(); box.size=size; collision.shape=box
	body.add_child(collision); body.position=center; world.add_child(body)
	return body
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	surface(world,Vector3(0,-1,0),Vector3(1000,2,1000))
	var player: PlayerCharacter=load("res://scenes/player.tscn").instantiate()
	player.position=Vector3(0,2,0); world.add_child(player); player.set_physics_process(false)
	var heli: CharacterBody3D=load("res://scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd").new()
	heli.target=player; heli.position=Vector3(0,140,25); world.add_child(heli)
	heli.set_physics_process(false); heli.gun.enabled=false
	await physics_frame; await physics_frame
	# A diving player continues requesting descent even after reaching street level.
	player.velocity=Vector3(0,-100,0)
	heli.flight.initialize_flight(heli.global_position,Vector3(0,-35,0))
	var lowest:=INF
	for i in range(900):
		heli._physics_process(1.0/60.0)
		lowest=minf(lowest,heli.global_position.y)
	check(lowest>=heli.ground_clearance-.01,"High-speed dive stays above street clearance")
	check(heli.global_position.y<heli.ground_clearance+2,"Settles near safe engagement height")
	# Late recovery and a long frame cannot carry descent through the safety floor.
	heli.global_position=Vector3(0,12.1,25); heli.flight.position=Vector3.ZERO
	heli.flight.initialize_flight(heli.global_position,Vector3(0,-35,0))
	heli._physics_process(.25)
	check(heli.global_position.y>=12,"Frame hitch cannot breach ground clearance")
	# The same protection applies to elevated roofs, not just world Y=0.
	var roof:=surface(world,Vector3(0,25,0),Vector3(200,50,200))
	await physics_frame; await physics_frame
	heli.global_position=Vector3(0,150,25); heli.flight.position=Vector3.ZERO
	heli.flight.initialize_flight(heli.global_position,Vector3(0,-35,0))
	player.position.y=52
	lowest=INF
	for i in range(900):
		heli._physics_process(1.0/60.0)
		lowest=minf(lowest,heli.global_position.y)
	check(lowest>=62-.01,"Diving pursuit stays above elevated roof")
	roof.free()
	# Recover gently from an externally placed low position instead of teleporting.
	await physics_frame
	player.position.y=2; player.velocity=Vector3.ZERO
	heli.global_position=Vector3(0,6,25); heli.flight.position=Vector3.ZERO
	heli.flight.initialize_flight(heli.global_position,Vector3.ZERO)
	heli._physics_process(1.0/60.0)
	check(heli.global_position.y>=6 and heli.global_position.y<7,"Low-altitude recovery climbs without teleporting")
	for i in range(600): heli._physics_process(1.0/60.0)
	check(heli.global_position.y>=11.9,"Low-altitude recovery reaches safe height")
	# Rapid horizontal pursuit cannot outrun climb clearance on a rising hillside.
	var slope:=surface(world,Vector3(0,40,-140),Vector3(200,8,200))
	slope.rotation.x=deg_to_rad(25)
	await physics_frame; await physics_frame
	heli.global_position=Vector3(0,20,0); heli.flight.position=Vector3.ZERO
	heli.flight.initialize_flight(heli.global_position,Vector3(0,0,-60))
	player.position=Vector3(0,75,-200)
	var closest:=INF
	for i in range(900):
		heli._physics_process(1.0/60.0)
		var ray:=PhysicsRayQueryParameters3D.create(heli.global_position,heli.global_position-Vector3.UP*300,1,[heli.get_rid(),player.get_rid()])
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): closest=minf(closest,heli.global_position.y-hit.position.y)
	check(closest>=heli.ground_clearance-.1,"Fast hillside approach preserves ground clearance")
	world.free()
	print("HELICOPTER_GROUND_CLEARANCE_PASS failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	var ship: Node3D=main.get_node("SuperCity/Sidewalks/CargoShip")
	var schedule: Node=ship.get_node("HarborSchedule"); schedule.enabled=false
	root.add_child(main)
	var clock:=get_first_node_in_group(&"day_night_cycle"); clock.cycle_running=false
	main.get_node("Player").set_physics_process(false)
	await physics_frame; await physics_frame
	var dock: Transform3D=schedule.berth_transform
	print("DOCK_POSE ",dock)
	for hour in [3.5,5.0,7.0,9.0,11.0]: print("SAMPLE ",hour," ",schedule.sample_schedule(hour).transform.origin)
	check(dock.origin.distance_to(Vector3(1130.8622,1.0316639,1225.0393))<.01,"Authored dock position retained")
	check(ship.get_node("Collision") is AnimatableBody3D,"Ship has moving-platform collision")
	for hour in [0.0,1.5,2.99,12.0,13.5,14.99]:
		var sample: Dictionary=schedule.sample_schedule(hour)
		check(sample.phase==schedule.Phase.BERTHED and sample.transform.is_equal_approx(dock),"Exactly docked at "+str(hour))
	for hour in [3.01,15.01]: check(schedule.sample_schedule(hour).phase==schedule.Phase.DEPARTING,"Leaves after three hours")
	for hour in [11.0,23.0]: check(schedule.sample_schedule(hour).phase==schedule.Phase.ARRIVING,"Approaches before arrival")
	for boundary in [0.0,3.0,6.5,8.5,12.0,15.0,18.5,20.5,24.0]:
		var a: Transform3D=schedule.sample_schedule(boundary-.00001).transform
		var b: Transform3D=schedule.sample_schedule(boundary+.00001).transform
		check(a.origin.distance_to(b.origin)<.02,"No position jump at schedule boundary "+str(boundary))
		check(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())<.005,"No heading jump at boundary "+str(boundary))
	# Check the entire hull envelope against the actual authored harbor/island.
	var space:=ship.get_world_3d().direct_space_state
	var hull:=BoxShape3D.new(); hull.size=Vector3(24,10,156)
	var q:=PhysicsShapeQueryParameters3D.new(); q.shape=hull; q.collision_mask=1
	q.exclude=[ship.get_node("Collision").get_rid(),main.get_node("Player").get_rid()]
	var obstructions: Dictionary={}
	for i in range(1440):
		var sample: Transform3D=schedule.sample_schedule(float(i)/120.0).transform
		q.transform=sample
		for hit in space.intersect_shape(q,8):
			if not obstructions.has(str(hit.collider.get_path())): obstructions[str(hit.collider.get_path())]=float(i)/120.0
	check(obstructions.is_empty(),"Full route clears harbor and terrain: "+str(obstructions.keys()))
	print("ROUTE_AUDIT ",JSON.stringify(obstructions))
	# Schedule follows explicit clock seeking and freezes when clock/game are paused.
	schedule.enabled=true; clock.set_time(11.0)
	await physics_frame; await physics_frame
	check(ship.global_position.distance_to(schedule.sample_schedule(11.0).transform.origin)<.01,"Clock seek updates ship")
	var held:=ship.global_transform
	for i in range(4): await physics_frame
	check(ship.global_transform.is_equal_approx(held),"Stopped clock freezes vessel")
	paused=true
	clock.set_time(12.0)
	await process_frame; await process_frame
	check(ship.global_transform.is_equal_approx(held),"Game pause freezes vessel")
	paused=false
	await physics_frame; await physics_frame
	check(ship.global_transform.is_equal_approx(dock) and ship.navigation_mode==2,"Noon docks exactly and uses berthed lights")
	clock.set_time(15.1)
	await physics_frame; await physics_frame
	check(ship.navigation_mode==0,"Departure restores underway lights")
	# A real CharacterBody can ride the translated/turning hull collision.
	clock.set_time(11.2)
	await physics_frame; await physics_frame
	var ray:=PhysicsRayQueryParameters3D.create(ship.global_position+Vector3.UP*45,ship.global_position-Vector3.UP*10,1)
	var deck:=space.intersect_ray(ray)
	check(not deck.is_empty() and deck.collider==ship.get_node("Collision"),"Moving deck ray hits ship")
	var rider:=CharacterBody3D.new(); var capsule:=CapsuleShape3D.new(); capsule.height=2; capsule.radius=.35
	var shape:=CollisionShape3D.new(); shape.shape=capsule; rider.add_child(shape)
	rider.floor_snap_length=.5; main.add_child(rider); rider.global_position=deck.position+Vector3.UP*1.1
	for i in range(20):
		rider.velocity.y-=9.8/60; rider.move_and_slide(); await physics_frame
	check(rider.is_on_floor(),"Rider settles on deck")
	var local_start:=ship.to_local(rider.global_position)
	clock.time_scale=1; clock.day_length_minutes=24; clock.cycle_running=true
	for i in range(120):
		rider.velocity.y-=9.8/60; rider.move_and_slide(); await physics_frame
	var drift:=ship.to_local(rider.global_position).distance_to(local_start)
	check(rider.is_on_floor() and drift<1.0,"Rider follows moving ship; drift="+str(drift))
	print("RIDER_DRIFT ",drift)
	main.free()
	print("CARGO_SCHEDULE_PASS failures=",failures)
	quit(1 if failures else 0)

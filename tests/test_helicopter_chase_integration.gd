extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=Node3D.new(); root.add_child(world); current_scene=world
	var player: PlayerCharacter=load("res://scenes/player.tscn").instantiate(); player.position=Vector3(0,2,-40); world.add_child(player); player.set_physics_process(false)
	var explosions:=ExplosionController.new(); world.add_child(explosions)
	var commands=load("res://scripts/ui-scripts/developer_commands.gd").new(player)
	await physics_frame; await physics_frame
	check(commands.COMPLETIONS.has("spawn helicopter_chase"),"Console completion")
	check(commands.execute("help spawn").contains("helicopter_chase"),"Console help")
	check(not commands.execute("spawn helicopter_chase 2").begins_with("Spawned"),"One encounter per command")
	paused=true
	var message: String=commands.execute("spawn helicopter_chase")
	check(message.begins_with("Spawned Helicopter Chase"),"Console encounter registration")
	var encounter: BaseEncounter=get_nodes_in_group(&"encounter")[0]
	var enemy: CharacterBody3D=encounter.helicopter
	var start:=enemy.global_position
	await process_frame; await process_frame
	check(enemy.global_position==start and enemy.gun.shots_fired==0,"Console pause freezes pursuit and firing")
	paused=false
	enemy.set_physics_process(false); enemy.gun.enabled=false
	enemy.global_position=Vector3(0,20,0); enemy.flight.position=Vector3.ZERO
	var car: Vehicle=load("res://scenes/vehicles/normal_car_1.tscn").instantiate()
	car.position=Vector3(-20,22,0); car.freeze=false; car.continuous_cd=true; car.gravity_scale=0
	world.add_child(car); car.linear_velocity=Vector3(40,0,0); car.arm_thrown_impact(40,player)
	for i in range(50): await physics_frame
	check(enemy.get_current_health()<100,"Actual thrown car contact/explosion damages helicopter")
	check(not is_instance_valid(car),"Thrown car detonates on collision")
	print("CAR_HIT_HEALTH ",enemy.get_current_health())
	# A direct laser ray sees the same damage receiver, not an undamageable child.
	var hit: Dictionary=player.laser_eyes._raycast(enemy.global_position+Vector3(-10,2,0),enemy.global_position+Vector3(10,2,0))
	check(not hit.is_empty() and hit.collider==enemy,"Laser ray resolves attack helicopter")
	# Real movement against a tall wall must stay out of the wall and climb.
	var wall:=StaticBody3D.new(); var c:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(100,30,4)
	c.shape=shape; wall.add_child(c); wall.position=Vector3(0,15,0); world.add_child(wall)
	enemy.global_position=Vector3(0,12,30); enemy.flight.position=Vector3.ZERO
	enemy.flight.initialize_flight(enemy.global_position,Vector3(0,0,-15))
	player.position=Vector3(0,2,-50)
	enemy.set_physics_process(true)
	var passed_through:=false
	var highest:=enemy.position.y
	for i in range(360):
		await physics_frame
		highest=maxf(highest,enemy.position.y)
		if absf(enemy.position.z)<3 and enemy.position.y<30: passed_through=true
	check(not passed_through,"Does not pass through tall buildings")
	check(highest>25,"Climbs above blocked route")
	world.free()
	print("HELICOPTER_CHASE_INTEGRATION_PASS failures=",failures)
	quit(1 if failures else 0)

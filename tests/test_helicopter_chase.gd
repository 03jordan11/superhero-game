extends SceneTree
const CHASE=preload("res://scenes/encounters/helicopter-chase/helicopter_chase.tscn")
const DAMAGE=preload("res://scripts/combat-scripts/damage_info.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var floor_body:=StaticBody3D.new(); var floor_shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(500,1,500)
	floor_shape.shape=box; floor_body.position.y=-1; floor_body.add_child(floor_shape); world.add_child(floor_body)
	var player: PlayerCharacter=load("res://scenes/player.tscn").instantiate(); player.position=Vector3(0,2,0); world.add_child(player)
	player.set_physics_process(false)
	player.stats.level=10; player.stats.experience=0
	var scene: BaseEncounter=CHASE.instantiate(); world.add_child(scene)
	await physics_frame; await physics_frame
	check(scene.start_encounter(player),"Encounter can spawn")
	var heli: CharacterBody3D=scene.helicopter
	check(heli.get_current_health()==100 and scene.xp_reward==1000,"Exact health and reward")
	check(heli.get_children().filter(func(n): return n is CollisionShape3D).size()==14,"Visible helicopter has solid hit shapes")
	heli.gun.enabled=false
	for i in range(600):
		heli._physics_process(1.0/60.0)
	check(heli.global_position.distance_to(player.global_position)<40,"Approaches within throwable/power distance")
	check(absf(heli.global_position.y-player.global_position.y-10)<3,"Tracks low altitude")
	player.position=Vector3(60,80,-30)
	for i in range(900): heli._physics_process(1.0/60.0)
	check(heli.global_position.distance_to(player.global_position)<40,"Follows player into flight")
	# Exercise swept slice against real player collider, with and without cover.
	heli.set_physics_process(false)
	player.position=Vector3(0,2,0)
	heli.position=Vector3(0,8,25); heli.flight.position=Vector3.ZERO
	heli.global_basis=Basis.IDENTITY; heli.flight.rotation=Vector3.ZERO; heli.flight.visual.rotation=Vector3.ZERO
	await physics_frame; await physics_frame
	var gun: Node3D=heli.gun
	gun._aim_point=player.global_position; gun._sweep_sign=1
	gun.sweep_degrees=30
	var before:=player.get_current_health()
	check(gun.fire_sweep(.35,.65),"Sweep crossing player hits between sampled rounds")
	check(player.get_current_health()<before,"Uses player bullet damage pipeline")
	check(not gun.fire_sweep(0,.1),"Arc missing the player causes no damage")
	var wall:=StaticBody3D.new(); var c:=CollisionShape3D.new(); var wall_box:=BoxShape3D.new(); wall_box.size=Vector3(15,20,1)
	c.shape=wall_box; wall.add_child(c); wall.position=Vector3(0,5,10); world.add_child(wall)
	await physics_frame; await physics_frame
	before=player.get_current_health()
	check(not gun.fire_sweep(.35,.65) and player.get_current_health()==before,"Cover blocks swept bullet damage")
	wall.free()
	await physics_frame
	# No catch-up burst of damage after a long frame.
	gun.enabled=true; gun.horizontal_error_degrees=0; gun.vertical_error_degrees=0; gun.movement_error_per_mps=0
	gun.begin_burst(0)
	var shots: int=gun.shots_fired
	gun.update_weapon(.8,0)
	check(gun.shots_fired==shots+1,"At most one shot per tick after hitch")
	gun.stop()
	# Power-compatible damage reaches this body via the same ray used by lasers.
	var ray:=PhysicsRayQueryParameters3D.create(heli.global_position+Vector3(-10,2,0),heli.global_position+Vector3(10,2,0),1)
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider==heli,"Powers hit the damageable helicopter body")
	heli.apply_damage(DAMAGE.new(40,Vector3.ZERO,Vector3.ZERO,&"none",player))
	check(heli.get_current_health()==60,"Damage applied exactly once")
	var completed:=[]
	scene.encounter_completed.connect(func(): completed.append(true))
	heli.apply_damage(DAMAGE.new(60,Vector3.ZERO,Vector3.ZERO,&"none",player))
	check(not heli.apply_damage(DAMAGE.new(100)),"Death is idempotent")
	await process_frame; await process_frame
	check(scene.state==BaseEncounter.EncounterState.COMPLETED and completed.size()==1,"One completion reward")
	check(player.stats.experience==1000,"Exactly 1000 XP total; no duplicate enemy bonus")
	var wrecks:=get_nodes_in_group(&"helicopter_wreck")
	check(wrecks.size()==1,"Exactly one falling wreck")
	if not wrecks.is_empty():
		var wreck: RigidBody3D=wrecks[0]
		check(wreck.lifetime==30 and not wreck.freeze,"Wreck lives thirty seconds and uses gravity")
		check(wreck.model.get_node("Body").material_override.albedo_color.r<.05,"Husk is black")
		var y:=wreck.position.y
		for i in range(12): await physics_frame
		check(wreck.position.y<y,"Wreck falls from explosion location")
		wreck.age=29.99; wreck._physics_process(.02)
		await process_frame; await process_frame
		check(not is_instance_valid(wreck),"Wreck removed at thirty seconds")
	scene.free()
	# Losing a living helicopter must fail, not grant kill credit.
	var lost: BaseEncounter=CHASE.instantiate(); world.add_child(lost); check(lost.start_encounter(player),"Second encounter starts")
	lost.helicopter.queue_free(); await process_frame; await process_frame
	check(lost.state==BaseEncounter.EncounterState.FAILED,"Unexpected despawn fails without reward")
	check(player.stats.experience==1000,"No XP for despawning a living helicopter")
	world.free()
	print("HELICOPTER_CHASE_PASS failures=",failures)
	quit(1 if failures else 0)

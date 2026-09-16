extends SceneTree
const STEP:=1.0/60.0
const DAMAGE=preload("res://scripts/combat-scripts/damage_info.gd")
var failures:=0
var world: Node3D
var hero: PlayerCharacter
var input: TestInput
class TestInput extends Node:
	var snapshot:=PlayerInputSnapshot.new()
	func capture() -> PlayerInputSnapshot: return snapshot
	func is_power_aim_requested() -> bool: return false
	func is_sprint_requested() -> bool: return snapshot.sprint_pressed
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): push_error("Grab test timed out"); quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func tick(snapshot: PlayerInputSnapshot=null) -> void:
	input.snapshot=snapshot if snapshot!=null else PlayerInputSnapshot.new()
	hero._profiled_physics_process(STEP)
	await physics_frame
func frames(count: int) -> void:
	for i in count: await tick()
func spawn_at(at: Vector3,kind:="melee_thug") -> HostileBase:
	var enemy: HostileBase=load("res://scenes/npcs/"+kind+".tscn").instantiate()
	enemy.position=at; world.add_child(enemy); enemy.set_physics_process(false)
	return enemy
func reset() -> void:
	hero.hostile_grab.drop(); hero.target_lock.release(); hero.combat_controller.cancel_punch()
	hero.position=Vector3(0,1,0); hero.velocity=Vector3.ZERO; hero.rotation=Vector3.ZERO
	hero.ground_facing_yaw=0; hero.superhero_character.rotation=hero.superhero_character_default_rotation
	await frames(5)
func press_e() -> void:
	var s:=PlayerInputSnapshot.new(); s.vehicle_interact_just_pressed=true; s.vehicle_interact_pressed=true
	await tick(s)
func attack() -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true
	hero._profiled_input(e)
func run() -> void:
	world=Node3D.new(); root.add_child(world); current_scene=world
	var floor_body:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new()
	box.size=Vector3(200,1,200); shape.shape=box; floor_body.add_child(shape); floor_body.position.y=-.5; world.add_child(floor_body)
	hero=load("res://scenes/player.tscn").instantiate(); hero.position.y=1; world.add_child(hero)
	hero.set_physics_process(false); hero.input_controller.set_process(false)
	input=TestInput.new(); hero.add_child(input); hero.input_controller=input
	await frames(10)
	var grab:=hero.hostile_grab
	var enemy:=spawn_at(Vector3(0,0,-1.6),"super_thug"); await tick()
	check(not enemy.can_grab and not grab.try_grab(),"Supers cannot be grabbed")
	enemy.free()
	enemy=spawn_at(Vector3(0,0,-1.6)); enemy.can_grab=false; await tick()
	check(not grab.try_grab(),"Inspector grab eligibility is respected"); enemy.free()
	enemy=spawn_at(Vector3(0,0,1.6)); await tick(); check(not grab.try_grab(),"Cannot grab someone behind you"); enemy.free()
	enemy=spawn_at(Vector3(0,0,-1.6)); await tick()
	var other:=spawn_at(Vector3(3,0,-9)); await tick()
	hero.target_lock._select(enemy)
	await press_e()
	check(grab.held==enemy and hero.is_carrying() and enemy.is_grabbed,"E grabs nearby hostile")
	check(enemy.collision_layer==0 and not enemy.is_physics_processing(),"Held hostile stops collision and AI")
	check(hero.target_lock.target==other,"Holding locked hostile selects a throw target")
	await frames(40)
	check(grab.mode==grab.Mode.HOLD and enemy.get_current_health()==100,"Grab/lift itself does no damage")
	var hero_rig: Skeleton3D=hero.superhero_character.find_child("GeneralSkeleton",true,false)
	var victim_rig: Skeleton3D=enemy.get_node("Superhero_Male_FullBody").find_child("GeneralSkeleton",true,false)
	hero_rig.force_update_all_bone_transforms(); victim_rig.force_update_all_bone_transforms()
	var hand:=hero_rig.to_global(hero_rig.get_bone_global_pose(hero_rig.find_bone("RightHand")).origin)
	var neck:=victim_rig.to_global(victim_rig.get_bone_global_pose(victim_rig.find_bone("Neck")).origin)
	check(hand.distance_to(neck)<.18,"Runtime paired animation keeps hand at victim throat")
	attack(); await frames(23)
	check(enemy.get_current_health()==80 and grab.has_hostile(),"First slam deals 20 and retains grip")
	attack(); attack(); await frames(60)
	check(enemy.get_current_health()==60 and grab.slam_count==2,"Repeated input queues only one second slam for 20")
	attack(); await frames(120)
	check(enemy.get_current_health()==0 and not grab.has_hostile(),"Third slam deals 60 and releases")
	check(not grab.owns_animation() and not enemy.is_grabbed,"Final recovery returns controls")
	enemy.free(); other.free(); await reset()
	# Charged throwing: no damage on release, damage once on capsule collision.
	enemy=spawn_at(Vector3(0,0,-1.6)); other=spawn_at(Vector3(0,0,-18)); await tick()
	await press_e(); await frames(40); hero.target_lock._select(other)
	await press_e()
	var charging:=PlayerInputSnapshot.new(); charging.vehicle_interact_pressed=true
	for i in 72: await tick(charging)
	var released:=PlayerInputSnapshot.new(); released.vehicle_interact_just_released=true
	await tick(released); await frames(18)
	check(enemy.get_current_health()==100 and other.get_current_health()==100,"Throw does not apply damage at release")
	for i in 90:
		await tick()
		if enemy.get_current_health()<100: break
	print("THROW_HEALTH victim=",enemy.get_current_health()," target=",other.get_current_health())
	check(enemy.get_current_health()==20 and other.get_current_health()==60,"Full-charge impact deals 80 to projectile and 40 to target")
	check(enemy.is_waiting_for_knockback_stun and other.is_waiting_for_knockback_stun,"Impact knocks down both hostiles")
	await frames(15); check(enemy.get_current_health()==20 and other.get_current_health()==60,"Resting contacts do not repeat throw damage")
	enemy.free(); other.free(); await reset()
	# Carrying preserves full-speed flight and cannot start grounded slams in air.
	enemy=spawn_at(Vector3(0,0,-1.6)); await tick(); await press_e(); await frames(40)
	await press_e(); var tap_release:=PlayerInputSnapshot.new(); tap_release.vehicle_interact_just_released=true
	await tick(tap_release)
	check(not grab.has_hostile() and enemy.get_current_health()==100 and enemy.collision_layer!=0,"Tap E drops without throw damage")
	enemy.free(); await reset()
	# A half-charge aimed at an enemy behind a wall must hit the wall first.
	enemy=spawn_at(Vector3(0,0,-1.6)); other=spawn_at(Vector3(0,0,-18)); await tick()
	await press_e(); await frames(40); hero.target_lock._select(other)
	var wall:=StaticBody3D.new(); var wall_shape:=CollisionShape3D.new(); var wall_box:=BoxShape3D.new()
	wall_box.size=Vector3(8,8,1); wall_shape.shape=wall_box; wall.add_child(wall_shape)
	wall.position=Vector3(0,3,-6); world.add_child(wall)
	await press_e()
	for i in 36: await tick(charging)
	await tick(released)
	for i in 100:
		await tick()
		if enemy.get_current_health()<100: break
	check(absf(enemy.get_current_health()-60)<.1 and other.get_current_health()==100,"Half charge deals 40 only to thrown body on wall collision")
	enemy.free(); other.free(); wall.free(); await reset()
	# Existing rescue pickup has priority over hostile pickup on the same E press.
	var rescue: RescueEncounter=load("res://scenes/encounters/rescue.tscn").instantiate()
	world.add_child(rescue); rescue.set_physics_process(false); rescue.state=BaseEncounter.EncounterState.ACTIVE
	var patient: RescuePatient=load("res://scenes/npcs/rescue_patient.tscn").instantiate()
	patient.encounter=rescue; patient.position=Vector3(1.5,0,-1); rescue.add_child(patient); patient.set_physics_process(false)
	enemy=spawn_at(Vector3(0,0,-1.6)); await tick(); await press_e()
	check(hero.rescue_carrier.has_patient() and not grab.has_hostile(),"E preserves rescue pickup priority")
	check(not grab.try_grab(),"Occupied rescue hands cannot grab a hostile")
	hero.drop_everything()
	check(not hero.is_carrying() and patient.carrier==null,"Shared drop restores rescue patient")
	rescue.free(); enemy.free(); await reset()
	# Carrying preserves full-speed flight and cannot start grounded slams in air.
	enemy=spawn_at(Vector3(0,0,-1.6)); await tick(); await press_e(); await frames(40)
	preload("res://tests/player_test_support.gd").unlock_current_powers(hero)
	check(hero.state_machine.transition_to(&"FlyingState"),"Can enter flight with hostile")
	var flight:=PlayerInputSnapshot.new(Vector2(0,-1),0,true,true)
	for i in 15: await tick(flight)
	check(grab.has_hostile() and grab.pair=="CarryFlightFast" and hero.flying_state.is_boosting,"Fast flight uses carry pose and keeps boosting")
	attack(); check(grab.mode==grab.Mode.HOLD and grab.slam_count==0,"Airborne attacks cannot slam held hostile")
	hero.state_machine.transition_to(&"KnockedDownState",{"cause":&"damage"})
	check(not hero.is_carrying() and not enemy.is_grabbed and enemy.collision_layer!=0,"Knockdown drops hostile and restores collision")
	# A new hero verifies death cleanup without modifying the state machine's terminal rule.
	hero.free(); enemy.free()
	hero=load("res://scenes/player.tscn").instantiate(); hero.position.y=1; world.add_child(hero)
	hero.set_physics_process(false); hero.input_controller.set_process(false)
	input=TestInput.new(); hero.add_child(input); hero.input_controller=input
	await frames(10); enemy=spawn_at(Vector3(0,0,-1.6)); await tick(); await press_e(); await frames(40)
	hero.apply_damage(DAMAGE.new(100000))
	check(hero.is_dead and not hero.is_carrying() and not enemy.is_grabbed,"Death drops hostile")
	world.free(); print("HOSTILE_GRAB_PASS failures=",failures); quit(1 if failures else 0)

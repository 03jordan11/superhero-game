extends SceneTree
const ENCOUNTER=preload("res://scenes/encounters/ship_docking.tscn")
var failures:=0
var main: Node3D
var hero: PlayerCharacter
var schedule: Node
class TestInput extends Node:
	var snapshot:=PlayerInputSnapshot.new()
	func capture() -> PlayerInputSnapshot: return snapshot
	func is_power_aim_requested() -> bool: return false
	func is_sprint_requested() -> bool: return false
func _initialize() -> void:
	create_timer(110).timeout.connect(func(): push_error("Docking test timed out"); quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func spawn(seed_value: int) -> Node:
	var e:=ENCOUNTER.instantiate()
	main.add_child(e); e._rng.seed=seed_value; e.cleanup_delay=0
	check(e.start_encounter(hero),"Encounter starts: "+e.spawn_error)
	e.set_physics_process(false)
	return e
func finish_with(e: Node, method: StringName) -> float:
	for tick in range(18000):
		if tick%200==0:
			e.attach(0 if e.end_error(0)>e.end_error(1) else 1,method); e.effort=true
		e.advance_ship(.05)
		if e.end_error(0)<=e.docking_tolerance and e.end_error(1)<=e.docking_tolerance:
			return (tick+1)*.05
	return 900.0
func run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	schedule=main.get_node("SuperCity/Sidewalks/CargoShip/HarborSchedule")
	root.add_child(main); current_scene=main
	hero=main.get_node("Player"); hero.set_physics_process(false)
	var input:=TestInput.new(); hero.add_child(input); hero.input_controller=input
	var clock:=get_first_node_in_group(&"day_night_cycle"); clock.cycle_running=false; clock.set_time(10)
	await physics_frame; await physics_frame
	var e:=spawn(42)
	check(e.state==BaseEncounter.EncounterState.ACTIVE,"Active state")
	if e.state!=BaseEncounter.EncounterState.ACTIVE: main.free(); quit(1); return
	check(not schedule.enabled,"Normal schedule paused")
	check(e.end_error(0)>50 and e.end_error(1)>50,"Both ends start offshore")
	check(e._pose_is_clear(e.ship.global_transform),"Starting hull clears geometry")
	var duplicate:=ENCOUNTER.instantiate(); main.add_child(duplicate)
	check(not duplicate.start_encounter(hero),"Second encounter cannot claim ship"); duplicate.free()
	# Offer contacts based on physical flight state, never the purchased ability.
	hero.abilities.set_unlocked(PlayerAbilities.FLIGHT,false); hero.is_flying=true
	hero.global_position=e.push_position(0)
	input.snapshot.vehicle_interact_just_pressed=true; hero._profiled_physics_process(.016)
	check(hero.ship_interaction.is_attached() and e.active_method==&"push","E attaches at flying contact without ability gating")
	input.snapshot.vehicle_interact_just_pressed=false; input.snapshot.movement=Vector2(0,-1)
	hero._profiled_physics_process(.016); e.advance_ship(.1)
	check(e.effort and e.linear_velocity.length()>.01,"W applies push")
	e._update_visuals(); check(not e._push_rings[0].visible,"Push markers hidden while moving")
	input.snapshot.vehicle_interact_just_pressed=true; hero._profiled_physics_process(.016)
	check(not hero.ship_interaction.is_attached() and e.active_end==-1,"E releases without picking up another object")
	input.snapshot=PlayerInputSnapshot.new()
	for tick in range(300): e.advance_ship(.05)
	e._update_visuals(); check(e.is_ship_stopped() and e._push_rings[0].visible,"Ship settles and flight contacts return")
	hero.is_flying=false; hero.global_position=e.dock_points[0]+Vector3.UP
	input.snapshot.vehicle_interact_just_pressed=true; hero._profiled_physics_process(.016)
	check(e.active_method==&"rope","Ground contact grabs rope")
	input.snapshot.vehicle_interact_just_pressed=false; input.snapshot.activate_power_pressed=true
	var old_length: float=e.rope_lengths[0]
	hero._profiled_physics_process(.016); e.advance_ship(.1)
	check(not e.effort and is_equal_approx(e.rope_lengths[0],old_length),"LMB no longer reels")
	input.snapshot.activate_power_pressed=false; input.snapshot.movement.y=-1
	hero._profiled_physics_process(.016); e.advance_ship(.1)
	check(not e.effort and is_equal_approx(e.rope_lengths[0],old_length),"Forward does not reel")
	input.snapshot.movement.y=1
	hero._profiled_physics_process(.016); e.advance_ship(.1)
	check(e.rope_lengths[0]<old_length and not hero.combat_controller.is_action_locked(),"S reels without walking or starting combat")
	e._update_visuals(); check(e._hud.text.contains("Hold S:"),"HUD advertises S")
	input.snapshot.movement=Vector2.ZERO
	hero._profiled_physics_process(.016)
	check(not e.effort,"Releasing S stops shortening the line")
	hero.ship_interaction.release(); e.free()
	check(schedule.enabled,"Freeing an active encounter restores schedule")
	paused=true
	var commands=main.get_node("DeveloperMenu").commands
	check(commands.COMPLETIONS.has("spawn ship_docking") and commands.execute("help spawn").contains("ship_docking"),"Console advertises new encounter")
	check(commands.execute("spawn ship_docking").begins_with("Spawned Ship Docking"),"Console starts encounter while paused")
	var console_encounter:=get_first_node_in_group(&"ship_docking")
	check(console_encounter.debug_waypoint,"Console exposes harbor waypoint")
	console_encounter.free(); paused=false
	# Exercise both methods with multiple random starting angles in real harbor geometry.
	var times: Dictionary={}
	for strength in [1,10,41]:
		hero.stats.strength=strength
		for method in [&"push",&"rope"]:
			for seed_value in [1,7,42,96]:
				e=spawn(seed_value)
				var seconds:=finish_with(e,method)
				times[[strength,method,seed_value]]=seconds
				check(e.end_error(0)<=5 and e.end_error(1)<=5,"Both ends dock using %s strength %d seed %d: %.2f, %.2f"%[method,strength,seed_value,e.end_error(0),e.end_error(1)])
				print("DOCK_SOLVER ",method," strength=",strength," seed=",seed_value," simulated_seconds=",seconds)
				check(e._pose_is_clear(e.ship.global_transform),"Completed hull clears harbor")
				e.free()
	for seed_value in [1,7,42,96]:
		for strength in [1,10,41]:
			check(times[[strength,&"push",seed_value]]<times[[strength,&"rope",seed_value]],"Flying push beats rope pull at each strength")
		for method in [&"push",&"rope"]:
			check(times[[41,method,seed_value]]<times[[10,method,seed_value]] and times[[10,method,seed_value]]<times[[1,method,seed_value]],"More strength reduces actual docking time for both methods")
	# Compare the new base rope movement to the previous solver, including its force limit.
	hero.stats.strength=1; e=spawn(42); e.reel_speed=3.0; e.maximum_rope_tension=8.0
	var old_seconds:=finish_with(e,&"rope")
	check(times[[1,&"rope",42]]<old_seconds*.95,"New base pull moves the actual hull faster")
	print("OLD_BASE_PULL_SECONDS ",old_seconds); e.free()
	e=spawn(42); hero.stats.set_power_bonuses(9,0)
	check(is_equal_approx(e.get_strength_speed_multiplier(),1.45),"Purchased strength bonuses count")
	hero.stats.set_power_bonuses(0,0); hero.stats.strength=PlayerStats.MAX_PROGRESSION_VALUE
	check(is_equal_approx(e.get_strength_speed_multiplier(),3.0),"Extreme strength remains bounded")
	e.free(); hero.stats.strength=10
	# Proximity must include both ends and rewards must only be paid once.
	e=spawn(4); hero.is_flying=true; hero.global_position=e.push_position(0)
	input.snapshot=PlayerInputSnapshot.new(); input.snapshot.vehicle_interact_just_pressed=true
	hero._profiled_physics_process(.016)
	check(hero.ship_interaction.is_attached(),"Contact attached before failure")
	e.fail_encounter()
	check(not hero.ship_interaction.is_attached() and schedule.enabled,"Failure immediately restores input and schedule")
	check(not e._push_rings[0].visible and not e._dock_rings[0].visible,"Failure removes markers")
	e.free(); hero.is_flying=false
	e=spawn(12); e.ship.global_transform=e.berth
	e.ship.global_basis=Basis(Vector3.UP,.2)*e.berth.basis
	e.ship.global_position+=e.target_position(0)-e.end_position(0)
	e._physics_process(0)
	check(e.state==BaseEncounter.EncounterState.ACTIVE,"One aligned end cannot complete")
	hero.stats.level=10; hero.stats.experience=0; hero.stats.money=0
	e.ship.global_transform=e.berth; e.linear_velocity=Vector3.ZERO; e.angular_velocity=0
	e._physics_process(0); e.complete_encounter()
	check(e.state==BaseEncounter.EncounterState.COMPLETED and hero.stats.experience==200 and hero.stats.money==200,"Completion awards exactly 200 XP and $200 once")
	check(schedule.enabled and schedule._berth_hold_remaining>0,"Schedule resumes with berth hold")
	clock.set_time(11); schedule._physics_process(.016)
	check(schedule.get_parent().global_transform.is_equal_approx(schedule.berth_transform),"Ship stays docked instead of teleporting onto schedule")
	clock.set_time(15.001); schedule._physics_process(.016)
	check(schedule.phase==schedule.Phase.DEPARTING and schedule.get_parent().global_position.distance_to(schedule.berth_transform.origin)<.01,"Next scheduled departure starts continuously")
	e.free(); main.free()
	print("SHIP_DOCKING_PASS failures=",failures)
	quit(1 if failures else 0)

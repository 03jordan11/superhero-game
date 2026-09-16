extends SceneTree
var failures:=0
var world: Node3D
var hero: PlayerCharacter
var lock: Node
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): push_error("Target test timed out"); quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func enemy(point: Vector3) -> HostileBase:
	var person: HostileBase=load("res://scenes/npcs/pistol_thug.tscn").instantiate()
	world.add_child(person); person.position=point; person.set_physics_process(false)
	return person
func box(point: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var mesh:=BoxShape3D.new()
	mesh.size=size; shape.shape=mesh; body.add_child(shape); world.add_child(body); body.position=point
	return body
func tick(time: float,held:=false,pressed:=false,released:=false) -> void:
	var input:=PlayerInputSnapshot.new(); input.lock_target_pressed=held
	input.lock_target_just_pressed=pressed; input.lock_target_just_released=released
	lock.update_lock(time,input)
func tap() -> void:
	tick(.08,true,true); tick(.016,false,false,true)
func run() -> void:
	world=Node3D.new(); root.add_child(world); current_scene=world
	box(Vector3(0,-.5,0),Vector3(250,1,250))
	hero=load("res://scenes/player.tscn").instantiate(); world.add_child(hero); hero.position=Vector3(0,1,0)
	hero.set_physics_process(false); hero.input_controller.set_process(false); lock=hero.target_lock
	var near:=enemy(Vector3(0,0,-12)); var second:=enemy(Vector3(4,0,-20)); var third:=enemy(Vector3(-8,0,-25))
	var behind:=enemy(Vector3(0,0,20)); var neutral:=enemy(Vector3(2,0,-5)); neutral.aggressive_to_player=false
	var dead:=enemy(Vector3(-3,0,-8)); dead.is_dead=true
	var civilian: Node3D=load("res://scenes/npcs/civilian.tscn").instantiate()
	world.add_child(civilian); civilian.position=Vector3(3,0,-4); civilian.set_physics_process(false)
	await physics_frame; await physics_frame
	check(InputMap.action_get_events("lock_target")[0].physical_keycode==KEY_TAB,"Tab lock-on default registered")
	Input.action_press("lock_target"); check(PlayerInputSnapshot.capture().lock_target_pressed,"Binding reaches input snapshot"); Input.action_release("lock_target")
	tick(.1,true,true); check(not lock.has_target(),"Press waits for tap release")
	tick(.016,false,false,true); check(lock.target==near,"Closest visible living enemy selected")
	tap(); check(lock.target==second,"Tap cycles to next enemy")
	tap(); check(lock.target==third,"Cycle reaches all eligible enemies")
	tap(); check(lock.target==near,"Cycle wraps, excluding civilian, dead, neutral and behind-camera NPCs")
	tick(.25,true,true); tick(.24,true); check(lock.target==near,"Holding does not cycle and keeps lock before threshold")
	tick(.011,true); check(not lock.has_target(),"Half-second hold releases while still held")
	tick(.016,false,false,true); check(not lock.has_target(),"Release after hold does not reacquire")
	tick(.51,true,true); tick(.016,false,false,true)
	check(not lock.has_target(),"Holding with no target never acquires one")
	tap(); check(lock.has_target(),"Tap works after held release")
	tick(.1,true,true); hero.input_controller.reset(); tick(.016,false,false,true)
	check(lock.target==near,"Focus/reset cancels pending cycle")
	tick(.1,true,true)
	root.get_node("DebugManager").developer_menu_open=true; tick(.1,true)
	root.get_node("DebugManager").developer_menu_open=false; tick(.016,false,false,true)
	check(lock.target==near,"Console interruption cancels the pending tap")
	lock._select(second); tick(.5)
	var yaw:=hero.rotation.y; hero.input_controller.apply_look(Vector2(1,1))
	check(is_equal_approx(hero.rotation.y,yaw),"Manual look cannot fight locked camera")
	var to_target: Vector3=second.global_position-hero.global_position; to_target.y=0; to_target=to_target.normalized()
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2(0,-1),Vector2(0,1)]:
		var input:=PlayerInputSnapshot.new(direction); hero.velocity=Vector3.ZERO
		hero._update_movement_facing(1,input); hero.grounded_state._apply_horizontal_movement(1,input)
		check(hero.superhero_character.global_basis.z.normalized().dot(to_target)>.99,"Hero faces target while strafing/retreating")
		if direction.y==0: check(absf(hero.velocity.normalized().dot(to_target))<.04,"A/D moves sideways")
		else: check(hero.velocity.normalized().dot(to_target)*-direction.y>.99,"W approaches and S retreats")
	lock.release(); var before:=hero.rotation.y; hero.input_controller.apply_look(Vector2(.2,0))
	check(not is_equal_approx(before,hero.rotation.y),"Free camera immediately responds after unlock")
	# Aiming immediately frees the camera and requires a fresh lock tap afterward.
	lock._select(second); tick(.1,true,true)
	var aim_click:=InputEventMouseButton.new(); aim_click.button_index=MOUSE_BUTTON_RIGHT; aim_click.pressed=true
	hero._profiled_input(aim_click)
	check(not lock.has_target(),"RMB releases before the next physics frame")
	var free_yaw:=hero.rotation.y; hero.input_controller.apply_look(Vector2(.1,0))
	check(not is_equal_approx(hero.rotation.y,free_yaw),"Mouse look works immediately after RMB")
	var aiming:=PlayerInputSnapshot.new(); aiming.aim_power_pressed=true
	aiming.lock_target_pressed=true; aiming.lock_target_just_pressed=true
	lock.update_lock(.1,aiming)
	tick(.016,false,false,true)
	check(not lock.has_target(),"Held aim cancels pending Tab and release does not reacquire")
	tick(.2); check(not lock.has_target(),"Ending aim stays unlocked")
	hero.rotation.y=0; hero.spring_arm.rotation.x=0; tap()
	check(lock.has_target(),"Fresh Tab reenables lock after aiming")
	lock._select(near); near.is_dead=true
	lock.update_lock(.016,aiming); near.is_dead=false
	tick(.016); check(not lock.has_target(),"Aim wins over simultaneous death retargeting")
	# Range, visibility, disappearance, and death-only target hopping.
	hero.rotation.y=0; hero.spring_arm.rotation.x=0
	lock._select(near); near.position.z=-70; tick(.016)
	check(lock.target==near,"Retention range exceeds acquisition range")
	near.position.z=-81; tick(.016); check(not lock.has_target(),"Distance breaks lock")
	near.position.z=-12; hero.rotation.y=0; hero.spring_arm.rotation.x=0
	var wall:=box(Vector3(0,2,-6),Vector3(4,4,1))
	await physics_frame; await physics_frame
	check(not lock._candidates().has(near),"Cannot acquire through wall")
	lock._select(near); tick(.2); check(lock.has_target(),"Brief obstruction tolerated")
	tick(.31); check(not lock.has_target(),"Persistent obstruction releases")
	wall.free(); await physics_frame; await physics_frame
	lock._select(near); near.is_dead=true; tick(.016)
	check(lock.target==second,"Target death selects nearest visible living enemy")
	near.is_dead=false; lock._select(near); near.free(); tick(.016)
	check(not lock.has_target(),"Freed target releases safely")
	var killed:=enemy(Vector3(0,0,-12)); lock._select(killed)
	killed.apply_damage(load("res://scripts/combat-scripts/damage_info.gd").new(1000))
	killed.free(); await physics_frame; tick(.016)
	check(lock.target==second,"Death followed by immediate cleanup still retargets")
	second.is_dead=true; third.aggressive_to_player=false
	tick(.016); check(not lock.has_target(),"No retarget to neutral, offscreen or dead enemies")
	second.is_dead=false; third.aggressive_to_player=true
	tick(.016); check(not lock.has_target(),"No delayed reacquisition after running out of enemies")
	lock._select(second); hero.is_knocked_out=true; tick(.016)
	check(not lock.has_target(),"Player knockdown releases"); hero.is_knocked_out=false
	preload("res://tests/player_test_support.gd").unlock_current_powers(hero)
	check(hero.state_machine.transition_to(&"FlyingState"),"Flight can coexist with lock-on")
	lock._select(second); hero.velocity=Vector3.ZERO; tick(.1)
	hero.flying_state.physics_update(.1,PlayerInputSnapshot.new())
	check(lock.has_target() and hero.velocity.is_zero_approx(),"Locked hovering does not automatically fly toward target")
	hero.state_machine.transition_to(&"GroundedState")
	# Existing melee hit test still reaches the selected enemy from a side-facing approach.
	hero.rotation.y=0; hero.spring_arm.rotation.x=0; second.position=Vector3(1.6,0,-1.3)
	lock._select(second); tick(1); hero._update_movement_facing(.016,PlayerInputSnapshot.new())
	await physics_frame; await physics_frame
	var health:=second.get_current_health()
	check(hero.combat_controller._try_hit_target(hero,1) and second.get_current_health()<health,"Melee hit direction follows locked facing")
	check(behind.get_current_health()==behind.get_max_health(),"Unselected distant enemy not damaged")
	world.free(); print("TARGET_LOCK_PASS failures=",failures); quit(1 if failures else 0)

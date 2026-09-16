extends SceneTree
const STEP:=1.0/60.0
var failures:=0
var world: Node3D
var hero: PlayerCharacter
var enemy: HostileBase
class EmptyInput extends Node:
	var movement:=Vector2.ZERO
	func capture() -> PlayerInputSnapshot:
		return PlayerInputSnapshot.new(movement, movement.x, movement != Vector2.ZERO)
	func is_sprint_requested() -> bool: return false
	func is_power_aim_requested() -> bool: return false
func _initialize() -> void:
	create_timer(40).timeout.connect(func(): push_error("Dash test timed out"); quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func box(at: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box_shape:=BoxShape3D.new()
	box_shape.size=size; shape.shape=box_shape; body.add_child(shape); world.add_child(body); body.position=at
	return body
func tick() -> void:
	hero.character_animation_player.advance(STEP)
	hero._profiled_physics_process(STEP)
	await physics_frame
func reset(at: Vector3) -> void:
	hero.combat_controller.cancel_punch(); hero.target_lock.release()
	hero.character_animation_player.play("Idle"); hero.position=Vector3(0,1,0); hero.rotation=Vector3.ZERO; hero.velocity=Vector3.ZERO
	if is_instance_valid(enemy): enemy.free()
	enemy=load("res://scenes/npcs/pistol_thug.tscn").instantiate(); enemy.position=at; world.add_child(enemy); enemy.set_physics_process(false)
	await physics_frame
	for i in range(20): await tick()
	hero.target_lock._select(enemy)
func run() -> void:
	world=Node3D.new(); root.add_child(world); current_scene=world
	var floor_body:=box(Vector3(0,-.5,0),Vector3(200,1,200))
	hero=load("res://scenes/player.tscn").instantiate(); world.add_child(hero)
	hero.set_physics_process(false); hero.input_controller.set_process(false); hero.stats.strength=1
	hero.character_animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var input:=EmptyInput.new(); hero.add_child(input); hero.input_controller=input
	await reset(Vector3(0,0,-20))
	var combat:=hero.combat_controller; combat.request_punch()
	print("DASH_INITIAL floor=",hero.is_on_floor()," position=",hero.position," locked=",hero.target_lock.has_target()," clear=",combat._clear_to_body(hero,enemy)," active=",combat.is_punch_active)
	check(combat.is_opening_dash,"First locked punch starts dash")
	var max_step:=0.0; var arrived:=false
	for i in range(120):
		var before:=hero.position
		await tick(); max_step=maxf(max_step,hero.position.distance_to(before))
		if combat.is_opening_dash: check(enemy.get_current_health()==100,"No damage during travel")
		else: arrived=true
		if enemy.get_current_health()<100: break
	check(arrived and enemy.get_current_health()==98,"Arrival delivers one normal-strength hit")
	print("DASH_RESULT health=",enemy.get_current_health()," hero=",hero.position," strength=",hero.stats.get_effective_strength()," enemy=",enemy.position," active=",combat.is_punch_active," hit=",combat.has_punch_hit)
	check(max_step<=combat.opening_dash_speed*STEP+.02,"Dash uses continuous swept movement")
	check(Vector2(hero.position.x-enemy.position.x,hero.position.z-enemy.position.z).length()<=2.1,"Dash ends inside striking range")
	combat._start_punch(1); check(not combat.is_opening_dash,"Second hit never dashes")
	combat._start_punch(0); check(not combat.is_opening_dash,"Looped combo opener never dashes")
	await reset(Vector3(0,0,-20)); hero.target_lock.release(); combat.request_punch()
	check(not combat.is_opening_dash,"Unlocked punch has no dash")
	await reset(Vector3(0,0,-20)); combat.request_punch(); await tick(); hero.target_lock.release(); await tick()
	check(not combat.is_opening_dash and absf(hero.velocity.z)<.01,"Unlock cancels travel and momentum")
	await reset(Vector3(0,0,-20)); combat.request_punch(); await tick(); enemy.is_dead=true; await tick()
	check(not combat.is_opening_dash,"Target death cancels dash")
	await reset(Vector3(0,0,-20)); combat.request_punch()
	var wall:=box(Vector3(0,2,-5),Vector3(5,4,.3)); await physics_frame
	for i in range(25): await tick()
	check(hero.position.z>-4.4 and enemy.get_current_health()==100 and not combat.is_opening_dash,"New obstacle interrupts dash without crossing or remote damage")
	wall.free()
	await reset(Vector3(0,0,-2.9)); combat.request_punch()
	check(combat.is_opening_dash,"Enemy beyond contact distance gets a short dash")
	combat.cancel_punch()
	# Extended reach and point-blank coverage work even with dash disabled.
	combat.opening_dash_enabled=false
	print("REACH hero=",hero.position," enemy=",enemy.position," yaw=",hero.rotation.y)
	check(combat._try_hit_target(hero,1),"Reach now includes an enemy 2.9 m away")
	await reset(Vector3(0,0,-1.3)); check(combat._try_hit_target(hero,1),"Close-range hits remain valid")
	await reset(Vector3(0,0,-2.4)); wall=box(Vector3(0,1.5,-1.4),Vector3(4,3,.15)); await physics_frame
	check(not combat._try_hit_target(hero,1) and enemy.get_current_health()==100,"Expanded punch cannot hit through thin wall")
	wall.free(); combat.opening_dash_enabled=true
	await reset(Vector3(0,4,-15)); combat.request_punch(); check(not combat.is_opening_dash,"No ground dash to another roof height")
	await reset(Vector3(0,0,-65)); combat.request_punch(); check(not combat.is_opening_dash,"Dash range is bounded")
	# A full-range approach must survive sustained gunfire and movement input.
	await reset(Vector3(0,0,-58)); input.movement=Vector2(1,1)
	combat.request_punch()
	combat.request_punch()
	check(combat.is_next_punch_queued,"Click during travel buffers the next punch")
	var bullet=load("res://scripts/combat-scripts/damage_info.gd").new(.01)
	bullet.damage_type=&"bullet"
	var health_before:=hero.get_current_health()
	hero.status_effects.apply_hit_slowdown() # Slowdown already active before committing.
	hero.apply_damage(bullet)
	for i in range(100):
		if i%5==0: hero.apply_damage(bullet)
		await tick()
		if enemy.get_current_health()<100: break
	check(enemy.get_current_health()<100,"Gunfire and movement input do not prevent dash impact")
	check(hero.get_current_health()<health_before,"Bullet armor does not prevent health damage")
	input.movement=Vector2.ZERO
	# A grounded attack wins over a stale jump flag from the landing frame.
	await reset(Vector3(0,0,-10)); hero.is_jump_active=true
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	hero._profiled_input(click)
	check(combat.is_punch_active,"Grounded click starts attack even with stale jump flag")
	hero.is_jump_active=false
	# Movement cannot turn an ongoing attack into a wall run.
	hero.abilities.set_unlocked(PlayerAbilities.WALL_RUN,true)
	var sprint_input:=PlayerInputSnapshot.new(Vector2(1,0),1,true)
	check(not hero.get_node("PlayerStateMachine/WallRunState").can_enter(null,{"input_snapshot":sprint_input,"collision_normal":Vector3.RIGHT}),"Sprint movement cannot enter wall run during combat")
	combat.cancel_punch()
	check(hero.get_node("PlayerStateMachine/WallRunState").can_enter(null,{"input_snapshot":sprint_input,"collision_normal":Vector3.RIGHT}),"Wall run remains available outside combat")
	# Repeated opening clicks after an interrupted windup restart the whole clip.
	combat.cancel_punch(); combat.opening_dash_enabled=false
	combat.request_punch(); hero.character_animation_player.advance(.3)
	combat.cancel_punch(); combat.request_punch()
	check(hero.character_animation_player.current_animation_position<.01,"Repeated opening punch restarts its animation")
	combat.request_punch()
	check(combat.is_next_punch_queued and combat.combo_punch_index==0,"Early click buffers one follow-up without skipping the current punch")
	combat.opening_dash_enabled=true
	# Track a laterally moving enemy, rather than its position at click time.
	await reset(Vector3(0,0,-25)); combat.request_punch()
	for i in range(75):
		enemy.position.x+=4.0*STEP
		await tick()
		if enemy.get_current_health()<100: break
	check(enemy.get_current_health()<100,"Moving target is hit after approach")
	# Step down onto a shallow lower floor without treating it as a rooftop edge.
	await reset(Vector3(0,0,-20))
	var pavement:=box(Vector3(0,.075,0),Vector3(8,.15,8))
	hero.position.y=1.15
	for i in range(5): await tick()
	combat.request_punch()
	for i in range(100):
		await tick()
		if enemy.get_current_health()<100: break
	check(enemy.get_current_health()<100,"Small pavement drop does not cancel the dash")
	pavement.free()
	# Use the engine's normal animation scheduling for an actual input-driven hit.
	await reset(Vector3(0,0,-20))
	hero.character_animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	hero.set_physics_process(true)
	hero._profiled_input(click)
	await create_timer(1.4).timeout
	check(enemy.get_current_health()<100,"Normal animation playback delivers an input-driven dash attack")
	hero.set_physics_process(false)
	hero.character_animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# The uppercut keeps a small hop instead of lifting the hero onto a head.
	await reset(Vector3(0,0,-1.8))
	combat._start_punch(2)
	var uppercut_peak:=hero.position.y
	var stood_on_enemy:=false
	for i in range(90):
		await tick()
		uppercut_peak=maxf(uppercut_peak,hero.position.y)
		for contact in hero.get_slide_collision_count():
			var collision:=hero.get_slide_collision(contact)
			if collision.get_collider()==enemy and collision.get_normal().y>.7:
				stood_on_enemy=true
	check(uppercut_peak>1.1 and uppercut_peak<2.0,"Uppercut retains a hop below one meter")
	check(not stood_on_enemy and hero.is_on_floor(),"Uppercut returns to ground without standing on the enemy")
	# A rooftop edge stops the approach even though the enemy remains visible.
	await reset(Vector3(0,0,-20)); floor_body.free(); box(Vector3(0,-.5,0),Vector3(10,1,6))
	await physics_frame; combat.request_punch()
	for i in range(30): await tick()
	check(hero.position.z>-3 and not combat.is_opening_dash,"Dash does not run off a ledge")
	world.free(); print("OPENING_DASH_PASS failures=",failures); quit(1 if failures else 0)

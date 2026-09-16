extends SceneTree

var failures:=0
var hero: PlayerCharacter
var world: Node3D
var enemies: Array[HostileBase]=[]

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): push_error("Melee dash test timed out"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	world=Node3D.new(); root.add_child(world); current_scene=world
	var floor_body:=StaticBody3D.new()
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new()
	box.size=Vector3(200,1,200); shape.shape=box; floor_body.add_child(shape)
	floor_body.position.y=-.5; world.add_child(floor_body)
	hero=load("res://scenes/player.tscn").instantiate(); hero.position.y=1
	world.add_child(hero); hero.stats.strength=1; hero.damage_receiver.set_max_health(10000)
	hero.damage_receiver.health_component.current_health=10000
	for scene_name in ["melee_thug","pistol_thug","super_thug"]:
		for distance in [3.0,10.0,25.0]:
			for enemy in enemies: enemy.free()
			enemies.clear(); hero.combat_controller.cancel_punch(); hero.target_lock.release()
			hero.position=Vector3(0,1,0); hero.velocity=Vector3.ZERO
			await frames(10)
			for index in (3 if scene_name=="melee_thug" else 1):
				var enemy: HostileBase=load("res://scenes/npcs/"+scene_name+".tscn").instantiate()
				enemy.position=Vector3(index*2,0,-distance); world.add_child(enemy)
				enemy.receive_alert(hero); enemy.combat_action_delay_remaining=0
				enemies.append(enemy)
			await frames(4)
			hero.target_lock._select(enemies[0])
			hero.combat_controller.request_punch()
			await frames(3); hero.combat_controller.request_punch()
			var paused_near_target:=0.0
			var longest_pause:=0.0
			for tick in 180:
				await frames(1)
				var offset:=enemies[0].position-hero.position; offset.y=0
				if hero.combat_controller.is_opening_dash and offset.length()<2.3:
					paused_near_target+=1.0/Engine.physics_ticks_per_second
					longest_pause=maxf(longest_pause,paused_near_target)
				else: paused_near_target=0
			print("MELEE_RECOVERY ",scene_name," distance=",distance," active=",hero.combat_controller.is_punch_active," dash=",hero.combat_controller.is_opening_dash," animation=",hero.character_animation_player.assigned_animation," playing=",hero.character_animation_player.is_playing()," position=",hero.position," enemy_health=",enemies[0].get_current_health())
			check(not hero.combat_controller.is_action_locked(),scene_name+": attack releases movement after combo")
			check(hero.character_animation_player.is_playing(),scene_name+": animation is not left paused")
			check(longest_pause<.2,scene_name+": dash commits instead of staying frozen beside retreating enemy")
			check(enemies[0].get_current_health()<enemies[0].max_health,scene_name+": approach delivers damage")
	world.free()
	print("MELEE_DASH_RECOVERY failures=",failures)
	quit(1 if failures else 0)

extends SceneTree

var failures := 0
var world: Node3D
var hero: PlayerCharacter
var combat: PlayerCombatController
var impact_count := 0
var sound_count := 0

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): push_error("Charged punch test timed out"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var mesh := BoxShape3D.new()
	mesh.size = size
	shape.shape = mesh
	body.add_child(shape)
	body.position = at
	world.add_child(body)
	return body

func attack(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	hero._profiled_input(event)

func advance(seconds: float) -> void:
	combat.update_punch_momentum(hero, seconds, 10)

func enemy(at: Vector3, kind := "melee_thug") -> HostileBase:
	var npc: HostileBase = load("res://scenes/npcs/" + kind + ".tscn").instantiate()
	npc.max_health = 1000.0
	npc.position = at
	world.add_child(npc)
	npc.set_physics_process(false)
	return npc

func charge_and_release() -> void:
	attack(true)
	advance(0.25)
	advance(0.75)
	attack(false)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(0,-0.5,0), Vector3(100,1,100))
	hero = load("res://scenes/player.tscn").instantiate()
	hero.position.y = 1
	world.add_child(hero)
	hero.set_physics_process(false)
	hero.input_controller.set_process(false)
	for i in 8:
		hero._profiled_physics_process(1.0 / 60.0)
		await physics_frame
	combat = hero.combat_controller
	combat.charge_punch_impact.connect(func(): impact_count += 1)
	combat.charge_punch_sound_started.connect(func(): sound_count += 1)
	check(hero.is_on_floor(), "Fixture is grounded")
	check(not hero.abilities.is_unlocked(PlayerAbilities.CHARGED_PUNCH), "Fresh game keeps charge locked")
	attack(true)
	check(combat.is_punch_active and not combat.attack_pending, "Locked ability preserves immediate regular punch")
	attack(false)
	combat.cancel_punch()
	# Exercise the actual existing Strength upgrade path without persisting a save.
	var powers := hero.get_node("PlayerPowerController")
	powers.progression.upgrades["strength"] = 1
	powers.sync_abilities()
	check(hero.abilities.is_unlocked(PlayerAbilities.CHARGED_PUNCH), "Strength upgrade one unlocks charge")
	attack(true)
	advance(0.1)
	check(not combat.is_punch_active and not combat.is_action_locked(), "Pending tap never punches prematurely")
	attack(false)
	check(combat.is_punch_active and combat.charge_phase == combat.ChargePhase.NONE, "Quick release gives a regular punch")
	attack(true)
	hero.character_animation_player.seek(hero.character_animation_player.current_animation_length,true)
	hero.character_animation_player.advance(0.1)
	advance(0.05)
	check(combat.attack_pending, "Combo finishing doesn't discard a new attack press")
	advance(0.2)
	check(combat.charge_phase == combat.ChargePhase.WINDUP, "Can charge across a regular combo's recovery")
	combat.cancel_punch()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X; pad.pressed = true
	hero._profiled_input(pad); advance(0.25)
	pad.pressed = false; hero._profiled_input(pad)
	advance(0.4)
	check(combat.charge_phase == combat.ChargePhase.RELEASE, "Bound Xbox attack supports hold and release")
	combat.cancel_punch()
	attack(true)
	advance(0.24)
	check(combat.charge_phase == combat.ChargePhase.NONE, "No charge before threshold")
	advance(0.01)
	check(combat.charge_phase == combat.ChargePhase.WINDUP and combat.is_action_locked(), "Charge begins at 0.25 seconds")
	check(not combat.is_punch_active, "Charging never also fires a normal punch")
	attack(false)
	check(combat.charge_phase == combat.ChargePhase.WINDUP, "Early release finishes the rear-back motion")
	advance(0.4)
	check(combat.charge_phase == combat.ChargePhase.RELEASE, "Early release proceeds to punch")
	advance(0.7)
	check(not combat.is_action_locked() and impact_count == 1, "Early release hits once and recovers")
	check(is_equal_approx(combat.charge_damage_at_distance(1.0, 1.0), 100.0), "Full close hit is 100 damage")
	check(is_equal_approx(combat.charge_damage_at_distance(6.0, 1.0), 65.0), "Full midpoint hit falls to 65")
	check(is_equal_approx(combat.charge_damage_at_distance(10.0, 1.0), 30.0), "Far edge is 30")
	check(is_equal_approx(combat.charge_damage_at_distance(1.0, 0.5), 65.0), "Longer holds increase damage")
	var near := enemy(Vector3(0,0,-1.7))
	var middle := enemy(Vector3(1.8,0,-6))
	var far := enemy(Vector3(-3.8,0,-9))
	var outside := enemy(Vector3(4,0,-3))
	var behind := enemy(Vector3(0,0,3))
	var too_far := enemy(Vector3(0,0,-11))
	var super_enemy := enemy(Vector3(-2,0,-5), "super_thug")
	var hidden := enemy(Vector3(2,0,-9))
	var wall := box(Vector3(2,1.5,-8), Vector3(1.0,3,0.3))
	await physics_frame
	var sounds_before := sound_count
	var winds_before := get_nodes_in_group(&"charge_punch_wind").size()
	charge_and_release()
	check(sound_count == sounds_before + 1, "Charged punch audio starts at release, before damage")
	var punch_audio: AudioStreamPlayer = hero.get_node("PlayerSoundManager/ComboPunch")
	check(punch_audio.playing and punch_audio.stream.resource_path.ends_with("charge_punch.mp3"), "Release plays the charged-punch clip")
	check(is_equal_approx(combat.released_charge,1.0), "One second total hold reaches full power")
	check(near.get_current_health() == 1000.0, "Release itself does no damage before contact pose")
	advance(0.2)
	check(sound_count == sounds_before + 1, "Impact does not repeat the early sound")
	check(get_nodes_in_group(&"charge_punch_wind").size() == winds_before + 1, "One wind burst appears at impact")
	var gust: MeshInstance3D = get_nodes_in_group(&"charge_punch_wind").back()
	check(gust.mesh.get_surface_count() == 1 and gust.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Wind uses one unshadowed surface")
	check(gust.global_position.distance_to(hero.global_position + Vector3.UP * 0.5) < 0.01, "Wind originates at punch height")
	check(is_equal_approx(near.get_current_health(),900.0), "Near enemy takes full damage")
	check(middle.get_current_health() > near.get_current_health() and middle.get_current_health() < far.get_current_health(), "Live cone damage falls off with distance")
	check(far.get_current_health() < 970.0, "Far in-cone target is hit")
	check(near.is_waiting_for_knockback_stun and middle.is_waiting_for_knockback_stun, "Ordinary hostiles are knocked down")
	check(super_enemy.get_current_health() < 1000.0 and not super_enemy.is_waiting_for_knockback_stun, "Super takes damage but resists knockdown")
	for excluded in [outside,behind,too_far,hidden]:
		check(excluded.get_current_health() == 1000.0, "Cone excludes outside, behind, distant, and wall-covered enemies")
	var health_after_hit := near.get_current_health()
	advance(0.6)
	check(get_nodes_in_group(&"charge_punch_wind").size() == winds_before + 1, "Recovery does not duplicate the wind")
	gust._process(combat.charge_wind_duration)
	check(gust.is_queued_for_deletion(), "Wind removes itself after its short lifetime")
	check(near.get_current_health() == health_after_hit and impact_count == 2, "One hit per enemy per release")
	check(not combat.is_action_locked(), "Release recovery restores movement")
	for npc in [near,middle,far,outside,behind,too_far,super_enemy,hidden]: npc.free()
	wall.free()
	attack(true); advance(0.25); advance(4.0)
	check(combat.charge_phase == combat.ChargePhase.HOLD, "Charge can hold indefinitely without firing")
	var bullet = preload("res://scripts/combat-scripts/damage_info.gd").new(1.0,Vector3(0,1,-5),Vector3.BACK,&"chest",null)
	bullet.damage_type = &"bullet"
	hero.apply_damage(bullet)
	check(combat.charge_phase == combat.ChargePhase.HOLD, "Bullet hits don't interrupt the loaded punch")
	hero.input_controller.reset(); attack(false)
	check(not combat.is_action_locked() and not combat.is_punch_active, "Menu/focus input reset cancels without a release attack")
	attack(true); advance(0.25)
	var aim := InputEventMouseButton.new(); aim.button_index = MOUSE_BUTTON_RIGHT; aim.pressed = true
	hero._profiled_input(aim); attack(false)
	check(not combat.is_action_locked(), "RMB cancels charge for aimed abilities")
	attack(true); advance(0.25)
	hero.is_knocked_out = true; advance(0.1); attack(false)
	check(not combat.is_action_locked(), "Knockdown cancels charge")
	hero.is_knocked_out = false
	attack(true); advance(0.25)
	hero.is_dead = true; combat.cancel_punch(); attack(false)
	check(not combat.is_action_locked(), "Death cancellation cannot leave a charge locked")
	hero.is_dead = false
	attack(true); advance(0.25)
	hero.abilities.set_unlocked(PlayerAbilities.CHARGED_PUNCH, false); advance(0.1); attack(false)
	check(not combat.is_action_locked(), "Revoking unlock cancels charge")
	validate_animations()
	if "--render" in OS.get_cmdline_user_args(): await render_poses()
	print("CHARGE_PUNCH_PASS failures=", failures)
	world.free()
	quit(1 if failures else 0)

func validate_animations() -> void:
	var player := hero.character_animation_player
	var skeleton := hero.superhero_character.find_child("GeneralSkeleton",true,false) as Skeleton3D
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/authored-combo/charge_punch_manifest.json"))
	for clip in manifest.clips:
		var name: String = "AuthoredCombo/" + clip.name
		check(player.has_animation(name), "Imported charge clip exists: " + name)
		if not player.has_animation(name): continue
		var animation := player.get_animation(name)
		check(absf(animation.length - float(clip.duration)) < 0.02, "Charge duration matches Blender")
		check(animation.loop_mode == (Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE), "Only hold clip loops")
		for index in animation.get_track_count():
			var path := animation.track_get_path(index)
			check(player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton, "Charge tracks resolve on actual player")
			check(skeleton.find_bone(path.get_subname(0)) >= 0, "Charge mapped bone exists")
		player.play(name,0.0)
		for fraction in [0.0,0.25,0.5,0.75,1.0]:
			player.seek(animation.length * fraction,true)
			skeleton.force_update_all_bone_transforms()
			for bone in skeleton.get_bone_count(): check(skeleton.get_bone_global_pose(bone).is_finite(), "Finite imported charge pose")
			check(skeleton.get_bone_pose_position(skeleton.find_bone("Root")).length() < 0.001, "Charge has no actor root motion")

func render_poses() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.5
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.14,0.17,0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30,30)
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.fov = 35
	world.add_child(camera)
	camera.position = Vector3(3,2,-4)
	camera.look_at(Vector3(0,1.1,0))
	camera.make_current()
	hero.character_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for sample in [["Windup",0.4],["Hold",0.75],["Release",0.2]]:
		hero.character_animation_player.play("AuthoredCombo/Hero_ChargePunch" + sample[0],0.0)
		hero.character_animation_player.seek(sample[1],true)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/charge_punch/Godot_" + sample[0] + ".png")
	# View the real shader from behind and above the player, like gameplay.
	camera.fov = 65
	camera.position = Vector3(3,4,5)
	camera.look_at(Vector3(0,1,-4))
	combat.released_charge = 1.0
	combat._spawn_charge_wind(hero)
	var wind: MeshInstance3D = get_nodes_in_group(&"charge_punch_wind").back()
	wind.set_process(false)
	for sample in [0.2, 0.4, 0.65]:
		wind.wind_material.set_shader_parameter("progress", sample)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/charge_punch/Godot_Wind_%d.png" % roundi(sample * 100.0))

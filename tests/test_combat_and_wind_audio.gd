extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.001, message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	var audio = player.get_node("PlayerSoundManager")
	audio.set_process(false)
	var punch: AudioStreamPlayer = audio.get_node("ComboPunch")
	var flight: AudioStreamPlayer = audio.get_node("SpeedWind")
	var combat: PlayerCombatController = player.combat_controller
	var animations: AnimationPlayer = player.animation_controller.animation_player
	check(not punch.playing and not flight.playing, "Combat and flight audio are silent at spawn")
	combat.request_punch()
	for index in range(3):
		check(combat.combo_punch_index == index, "Combo advances in order")
		combat.punch_time = audio.punch_sound_delays[index] - 0.01
		audio.update_combo_audio()
		check(not punch.playing, "Punch waits until its configured delay")
		combat.punch_time += 0.02
		audio.update_combo_audio()
		check(punch.playing and punch.stream.resource_path.ends_with("punch_%d.mp3" % (index + 1)), "Correct sound for combo punch %d" % (index + 1))
		punch.stop()
		audio.update_combo_audio()
		check(not punch.playing, "Combo sound fires only once per attack")
		if index < 2:
			animations.seek(animations.current_animation_length - 0.01, true)
			combat.request_punch()
			check(combat.is_next_punch_queued, "Actual combo input queues the next attack")
			animations.advance(0.1)
			combat.update_punch_momentum(player, 0.01, 1)
	combat.cancel_punch()
	combat.request_punch()
	combat.cancel_punch()
	audio.update_combo_audio()
	check(not punch.playing, "Cancelled attack cannot play a delayed punch")

	# Movement thresholds, sound swapping and fades are covered by
	# test_player_power_feedback.gd. Keep the existing bus mix regression here.
	var wind_bus := AudioServer.get_bus_index(&"PlayerSpeedWind")
	check(wind_bus > 0 and flight.bus == &"PlayerSpeedWind", "Player wind has its own effects bus")
	if wind_bus > 0:
		check(AudioServer.get_bus_effect(wind_bus, 0) is AudioEffectEQ6, "Wind retains its dedicated EQ")
		check(AudioServer.get_bus_effect(wind_bus, 1) is AudioEffectLimiter, "Wind has peak control")

	var hostile = load("res://scenes/npcs/hostile.tscn").instantiate()
	world.add_child(hostile)
	hostile.set_physics_process(false)
	hostile.position = Vector3(1000, 0, 0) # Force a miss: a shot still needs sound.
	hostile.combat_target = player
	var gun: AudioStreamPlayer3D = hostile.get_node("PistolShot")
	var ammo_before: int = hostile.ammo_count
	hostile._handle_pistol_combat(0.01)
	check(gun.playing and hostile.ammo_count == ammo_before - 1, "Fired pistol round plays even on a miss")
	check(gun.stream.resource_path.ends_with("pistol_shot_single.wav"), "Uses the supplied pistol clip")
	gun.stop()
	hostile._handle_pistol_combat(0.01)
	check(not gun.playing and hostile.ammo_count == ammo_before - 1, "Shot animation continuation does not duplicate sound")
	hostile.shot_in_progress = false
	hostile.ammo_count = 0
	hostile._handle_pistol_combat(0.01)
	check(hostile.is_reloading and not gun.playing, "Reload does not play a pistol shot")
	hostile.free()

	var packed_city: Node = load("res://scenes/super_city.tscn").instantiate()
	var sound: Node = packed_city.get_node("Sound")
	packed_city.remove_child(sound)
	packed_city.free()
	var city := Node3D.new()
	world.add_child(city)
	city.position = Vector3(100, 15, -80)
	city.rotation.y = 0.6
	city.add_child(sound)
	var ambience = sound.get_node("CityAmbiances")
	var sky = sound.get_node("SkyWind")
	ambience.set_process(false)
	sky.set_process(false)
	player.global_position = city.to_global(Vector3.ZERO)
	ambience._process(3.0)
	sky._process(3.0)
	check(not sky.playing and sky.calculate_target_gain() == 0.0, "Street level has no sky wind decoding")
	player.global_position = city.to_global(Vector3(0, 110, 0))
	ambience._process(3.0)
	sky._process(3.0)
	near(sky.calculate_target_gain(), 0.5, "Sky wind reaches midpoint at 110 metres")
	near(ambience.get_fade_gain(), 0.5, "City noise fades as sky wind grows")
	check(sky.playing and sky.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Sky wind loops at altitude")
	player.global_position = city.to_global(Vector3(-292, 220, 0))
	ambience._process(3.0)
	sky._process(3.0)
	near(sky.calculate_target_gain(), 1.0, "Sky wind remains present over the park at altitude")
	near(ambience.get_fade_gain(), 0.0, "Street ambience is gone high above the park")
	player.global_position = city.to_global(Vector3(1600, 220, 0))
	near(sky.calculate_target_gain(), 0.5, "Sky wind shares the city boundary fade")
	player.global_position = city.to_global(Vector3(1800, 220, 0))
	sky._process(3.0)
	check(not sky.playing, "Sky wind stops outside the city sound range")
	player.global_position = city.to_global(Vector3(0, 220, 0))
	ambience.ambience_enabled = false
	near(sky.calculate_target_gain(), 0.0, "City ambience toggle also disables sky wind")
	await process_frame
	world.free()
	print("Combat and wind audio: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

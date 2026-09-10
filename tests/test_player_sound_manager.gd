extends SceneTree

var failures := 0
var impact_count := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	player.set_physics_process(false)
	var controller = player.get_node("PlayerLandingImpactController")
	var manager = player.get_node("PlayerSoundManager")
	var audio: AudioStreamPlayer = manager.get_node("HeavyLanding")
	var impact_bus := AudioServer.get_bus_index(&"PlayerImpacts")
	check(impact_bus > 0 and audio.bus == &"PlayerImpacts", "Landing audio routes through its dedicated effects bus")
	if impact_bus > 0:
		check(AudioServer.get_bus_effect_count(impact_bus) == 3, "Impact bus has EQ, reverb, and peak control")
		var eq = AudioServer.get_bus_effect(impact_bus, 0)
		var reverb = AudioServer.get_bus_effect(impact_bus, 1)
		check(eq is AudioEffectEQ6 and eq.get("band_db/100_hz") == 5.0, "Impact bass boost is loaded")
		check(reverb is AudioEffectReverb and is_equal_approx(reverb.wet, 0.22), "Impact reverb mix is loaded")
		check(AudioServer.get_bus_effect(impact_bus, 2) is AudioEffectLimiter, "Boosted impacts have peak control")
		for effect_index in range(3):
			check(AudioServer.is_bus_effect_enabled(impact_bus, effect_index), "Impact effect is enabled")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Master")) == 0, "Master audio is unaffected by landing effects")
	controller.hard_landing_effect_spawned.connect(func(): impact_count += 1)
	check(not audio.playing, "No landing sound at spawn")
	controller.was_on_floor = false
	controller.observe_before_move(false, -5.0)
	controller.update_after_move(true, false, 0.0, 1.0)
	check(impact_count == 0 and not audio.playing, "Soft landing without a decal is silent")
	controller.was_on_floor = false
	controller.observe_before_move(false, -25.0)
	controller.update_after_move(true, false, 0.0, 1.0)
	check(impact_count == 1 and audio.playing, "Heavy landing decal plays audio")
	check(is_equal_approx(audio.pitch_scale, 0.9) and audio.volume_db == -3.0, "Impact plays slightly slower with mixing headroom")
	check(audio.stream.resource_path == "res://assets/audio/player/heavy_landing.wav", "Uses the supplied recording")
	check(audio.stream is AudioStreamWAV and audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Landing recording is a one-shot")
	check(get_nodes_in_group(&"debug_landing_effects").size() == impact_count, "Audio event matches an actual impact effect")
	audio.stop()
	controller.update_after_move(true, false, 0.0, 1.0)
	controller.resolve_normal_landing()
	check(impact_count == 1 and not audio.playing, "Standing grounded and classification do not replay audio")
	controller.was_on_floor = false
	controller.update_after_move(true, true, 40.0, 1.0)
	check(impact_count == 2 and audio.playing, "Ground slam decal also plays audio")
	audio.stop()
	manager.heavy_landing_volume_db = -9.0
	manager.heavy_landing_pitch = 0.9
	controller.spawn_hard_landing_effect(40.0, Vector3.ZERO, Vector3.UP)
	check(impact_count == 3 and audio.playing, "Direct impact path also plays audio")
	check(audio.volume_db == -9.0 and is_equal_approx(audio.pitch_scale, 0.9), "Inspector tuning applies on the next impact")
	audio.stop()
	manager.sounds_enabled = false
	controller.spawn_hard_landing_effect(40.0, Vector3.ZERO, Vector3.UP)
	check(impact_count == 4 and not audio.playing, "Mute preserves the visual effect")
	check(get_nodes_in_group(&"debug_landing_effects").size() == impact_count, "Exactly one event per decal effect")
	manager.sounds_enabled = true
	manager.set_process(false)
	var footstep: AudioStreamPlayer = manager.get_node("Footstep")
	check(footstep.bus == &"PlayerFootsteps", "Footsteps use their own level protection bus")
	var footstep_bus := AudioServer.get_bus_index(&"PlayerFootsteps")
	check(footstep_bus > 0 and AudioServer.get_bus_effect_count(footstep_bus) == 1, "Footsteps do not inherit impact bass and reverb")
	if footstep_bus > 0:
		check(AudioServer.get_bus_effect(footstep_bus, 0) is AudioEffectLimiter, "Louder footsteps have peak protection")
	manager.walk_left_contact = 20.0
	manager.walk_right_contact = 70.0
	manager.sprint_left_contact = 10.0
	manager.sprint_right_contact = 60.0
	manager.update_footsteps(&"Run", 0.0, 1.0, true, 0.0)
	check(not footstep.playing, "Idle is silent")
	manager.update_footsteps(&"Run", 0.0, 1.0, true, 6.0)
	manager.update_footsteps(&"Run", 0.19, 1.0, true, 6.0)
	check(not footstep.playing, "Walking waits for its animation contact")
	manager.update_footsteps(&"Run", 0.21, 1.0, true, 6.0)
	check(footstep.playing, "Walking left contact plays at 20 percent")
	check(footstep.volume_db == 24.0, "Quiet recording receives the intended gain instead of the old -8 dB override")
	check(footstep.stream.resource_path == "res://assets/audio/player/generic_footstep.mp3" and not footstep.stream.loop, "Uses the supplied single footstep without looping")
	check(footstep.pitch_scale >= 0.96 and footstep.pitch_scale <= 1.04, "Step variation stays subtle")
	footstep.stop()
	manager.update_footsteps(&"Run", 0.21, 1.0, true, 100.0)
	check(not footstep.playing, "An unchanged pose does not replay a step even at high movement speed")
	manager.update_footsteps(&"Run", 0.71, 1.0, true, 100.0)
	check(footstep.playing, "Walking right contact follows animation rather than distance")
	footstep.stop()
	manager.update_footsteps(&"Run", 0.95, 1.0, true, 6.0)
	manager.update_footsteps(&"Run", 0.05, 1.0, true, 6.0)
	check(not footstep.playing, "Loop boundary does not invent a foot contact")
	manager.update_footsteps(&"Run", 0.22, 1.0, true, 6.0)
	check(footstep.playing, "Next loop repeats the configured contact")
	footstep.stop()
	manager.walk_right_contact = 80.0
	manager.update_footsteps(&"Run", 0.72, 1.0, true, 6.0)
	check(not footstep.playing, "Live timing edit removes the old contact")
	manager.footstep_volume_db = 30.0
	manager.update_footsteps(&"Run", 0.82, 1.0, true, 6.0)
	check(footstep.playing, "Live timing edit applies the new contact")
	check(footstep.volume_db == 30.0, "Volume tuning above the previous maximum applies to the next step")
	footstep.stop()
	manager.update_footsteps(&"Sprint", 0.0, 0.5, true, 20.0)
	manager.update_footsteps(&"Sprint", 0.051, 0.5, true, 20.0)
	check(footstep.playing, "Sprint uses its own contact percentage and actual clip length")
	footstep.stop()
	manager.update_footsteps(&"Sprint", 0.31, 0.5, true, 20.0)
	check(footstep.playing, "Sprint right contact plays independently")
	footstep.stop()
	manager.update_footsteps(&"Landing", 0.2, 1.0, true, 6.0)
	check(not footstep.playing, "Landing animation does not produce walking sounds")
	manager.update_footsteps(&"Run", 0.0, 1.0, true, 6.0)
	manager.update_footsteps(&"Run", 0.21, 1.0, false, 6.0)
	check(not footstep.playing and manager._step_animation == &"", "Airborne movement resets timing")
	manager.footsteps_enabled = false
	manager.update_footsteps(&"Run", 0.21, 1.0, true, 6.0)
	check(not footstep.playing, "Footstep toggle prevents playback")
	manager.footsteps_enabled = true
	manager.sounds_enabled = false
	manager.update_footsteps(&"Run", 0.21, 1.0, true, 6.0)
	check(not footstep.playing, "Player sound mute includes footsteps")
	await process_frame # Let deferred particle/decal setup complete before cleanup.
	world.free()
	print("Player landing sound: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

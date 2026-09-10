extends SceneTree

var failures := 0
var pickups := 0
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")

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
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	player.set_physics_process(false)
	var feedback: PlayerSpeedFeedback = player.get_node("PlayerSpeedFeedback")
	feedback.set_process(false)
	var audio = player.get_node("PlayerSoundManager")
	audio.set_process(false)
	var wind: AudioStreamPlayer = audio.get_node("SpeedWind")
	var charge: AudioStreamPlayer = audio.get_node("JumpCharge")
	var death: AudioStreamPlayer = audio.get_node("Death")
	var lift: AudioStreamPlayer = audio.get_node("HeavyLift")
	check(not wind.playing and not charge.playing and not death.playing and not lift.playing, "Silent at spawn")
	check(not feedback._trails.visible and not feedback._overlay.visible, "Idle visuals skip rendering")
	check(feedback.calculate_target(Vector3(14.9, 0, 0), true, false) == 0.0, "Running below threshold stays silent")
	check(feedback.calculate_target(Vector3(15, 0, 0), true, false) > 0.0, "Actual running speed triggers wind without flight or sprint input")
	check(feedback.calculate_target(Vector3(0, 15, 0), false, true) > 0.0, "Vertical flight uses full velocity")
	check(feedback.calculate_target(Vector3(90, 24, 0), false, false) == 0.0, "Upward unpowered jumps do not count as fast falls")
	check(feedback.calculate_target(Vector3(0, -24.9, 0), false, false) == 0.0, "Slow falls stay silent")
	check(feedback.calculate_target(Vector3(0, -25, 0), false, false) > 0.0, "Fast fall triggers at its own threshold")
	check(feedback.calculate_target(Vector3(100, 0, 0), true, false, false) == 0.0, "Disabled/dead state has no target")
	feedback.movement_start_speed = 30.0
	check(feedback.calculate_target(Vector3(20, 0, 0), true, false) == 0.0, "Threshold is tunable")
	feedback.movement_start_speed = 15.0
	feedback.update_feedback(0.05, Vector3(100, 0, 0), true, false)
	audio.update_power_audio(0.05)
	check(wind.playing and feedback.intensity > 0.0 and feedback.intensity < 1.0, "Wind fades in")
	check(feedback._overlay.visible and feedback._trails.visible, "Shared envelope activates both visuals")
	feedback.update_feedback(1.0, Vector3(100, 0, 0), true, false)
	audio.update_power_audio(1.0)
	check(is_equal_approx(feedback.intensity, 1.0), "Full intensity caps at one")
	check(wind.stream is AudioStreamWAV and wind.stream.loop_end == 288000, "Six-second wind uses full loop")
	check(audio.speed_wind_sound.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Loop setup leaves source resource unchanged")
	var original: AudioStream = audio.speed_wind_sound
	var replacement: AudioStreamMP3 = load("res://assets/audio/player/generic_footstep.mp3")
	audio.speed_wind_sound = replacement
	audio.update_power_audio(0.0)
	check(wind.playing and wind.stream is AudioStreamMP3 and wind.stream.loop, "Live replacement accepts MP3 and loops it")
	check(not replacement.loop, "Replacement source remains unchanged")
	audio.speed_wind_sound = null
	audio.update_power_audio(0.0)
	check(not wind.playing, "Clearing stream stops decoding immediately")
	audio.speed_wind_sound = original
	audio.update_power_audio(0.0)
	feedback.visual_strength = 0.0
	feedback.update_feedback(1.0, Vector3(100, 0, 0), true, false)
	check(not feedback._overlay.visible and not feedback._trails.visible and wind.playing, "Visuals can be disabled independently")
	feedback.visual_strength = 0.6
	feedback.update_feedback(0.05, Vector3.ZERO, true, false)
	audio.update_power_audio(0.05)
	check(wind.playing and feedback.intensity < 1.0, "Slowing down fades wind")
	feedback.update_feedback(1.0, Vector3.ZERO, true, false)
	audio.update_power_audio(1.0)
	check(not wind.playing and not feedback._overlay.visible, "Stopping shuts down decoding and screen effect")
	# Sample actual collision-resolved velocity, not the requested controller velocity.
	player.global_position = Vector3(0, 50, 0)
	player.is_flying = true
	player.velocity = Vector3(100, 0, 0)
	feedback._process(1.0)
	check(feedback.intensity == 0.0, "Requested speed alone cannot start wind")
	await physics_frame
	player.move_and_slide()
	feedback._process(1.0)
	check(feedback.intensity > 0.0, "Actual movement drives runtime envelope")
	player.is_flying = false
	player.velocity = Vector3.ZERO
	player.global_position = Vector3.ZERO
	check(player.state_machine.transition_to(&"JumpChargingState", {"initial_charge_delta": 0.2}), "Can enter charge fixture")
	check(charge.playing, "Charge entry event immediately starts sound")
	var initial_pitch := charge.pitch_scale
	player.jump_charge = player.max_jump_charge_time
	player.jump_charge_changed.emit(player.jump_charge, player.max_jump_charge_time)
	check(charge.playing and charge.pitch_scale > initial_pitch, "Pitch rises to full charge")
	check(charge.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Full charge can be held indefinitely")
	player.state_machine.transition_to(&"AirborneState")
	check(not charge.playing, "Charge exit stops sound immediately")
	player.state_machine.transition_to(&"GroundedState")
	player.state_machine.transition_to(&"JumpChargingState")
	audio.sounds_enabled = false
	audio.update_power_audio(0.0)
	check(not charge.playing and not wind.playing, "Mute stops loops")
	audio.sounds_enabled = true
	player.state_machine.transition_to(&"GroundedState")
	# Use a real camera ray and Vehicle collision to exercise pickup success/failure.
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1, 0)
	player.vehicle_interactor.camera = camera
	check(not player.vehicle_interactor.try_pick_up_vehicle() and not lift.playing, "Missed pickup has no grunt")
	var vehicle := Vehicle.new()
	vehicle.freeze = true
	vehicle.position = Vector3(0, 1, -4)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	vehicle.add_child(shape)
	world.add_child(vehicle)
	player.vehicle_interactor.vehicle_picked_up.connect(func(_car): pickups += 1)
	await physics_frame
	await physics_frame
	check(player.vehicle_interactor.try_pick_up_vehicle(), "Vehicle ray pickup succeeds")
	check(lift.playing and pickups == 1, "Successful heavy pickup plays one grunt")
	lift.stop()
	check(not player.vehicle_interactor.try_pick_up_vehicle() and not lift.playing, "Already carrying cannot replay lift")
	player.vehicle_interactor.drop_held_vehicle()
	check(not lift.playing and pickups == 1, "Dropping does not play pickup sound")
	player.apply_damage(DAMAGE.new(1.0))
	check(not death.playing, "Nonfatal damage has no death sound")
	player.state_machine.transition_to(&"JumpChargingState")
	player.apply_damage(DAMAGE.new(10000.0))
	check(player.is_dead and death.playing, "Actual lethal damage enters death and plays sound")
	check(not charge.playing and not wind.playing and not lift.playing, "Death cancels power and lift sounds")
	death.stop()
	player.apply_damage(DAMAGE.new(10000.0))
	audio.update_power_audio(1.0)
	check(not death.playing, "Dead body cannot retrigger death sound")
	world.free()
	# Allow the audio mixer to release stopped playbacks before process teardown.
	await create_timer(0.15).timeout
	print("Player power feedback: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

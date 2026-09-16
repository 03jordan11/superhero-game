extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

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
	var controller := ExplosionController.new()
	world.add_child(controller)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(12, 3, 16)
	camera.make_current()
	var car: Vehicle = load("res://scenes/vehicles/normal_car_2.tscn").instantiate()
	world.add_child(car)
	car.position = Vector3(12, 1, 8)
	var explosion_position := car.global_position
	car.apply_damage(DAMAGE.new(10.0))
	check(get_nodes_in_group(&"debug_explosion_effects").is_empty(), "Nonfatal damage does not play an explosion")
	car.apply_damage(DAMAGE.new(100.0))
	await process_frame
	await process_frame
	check(not is_instance_valid(car), "Exploded vehicle is removed")
	var effects := get_nodes_in_group(&"debug_explosion_effects")
	check(effects.size() == 1, "Vehicle destruction creates exactly one explosion effect")
	if effects.is_empty():
		quit(1)
		return
	var effect = effects[0]
	var audio: AudioStreamPlayer3D = effect.get_node("ExplosionSound")
	check(audio.playing and not audio.stream.loop, "Destroyed vehicle starts its explosion one-shot")
	check(audio.global_position.is_equal_approx(explosion_position), "Explosion sound stays at the blast location")
	check(audio.stream.data == load("res://assets/audio/Vehicles/explosion.mp3").data, "Uses the supplied explosion clip")
	check(audio.volume_db == -15.0, "Explosion gain is halved again with another 6 dB reduction")
	check(audio.pitch_scale >= 0.92 and audio.pitch_scale <= 1.08, "Pitch varies within a subtle range")
	check(audio.bus == &"VehicleExplosions", "Explosion uses its own peak control bus")
	var bus := AudioServer.get_bus_index(&"VehicleExplosions")
	check(bus > 0 and AudioServer.get_bus_effect(bus, 0) is AudioEffectLimiter, "Boosted and overlapping blasts have peak control")
	var pitches := {audio.pitch_scale: true}
	for index in range(3):
		controller._spawn_effect(explosion_position + Vector3(index * 3, 0, 0), 30.0)
	await process_frame
	await process_frame
	for other in get_nodes_in_group(&"debug_explosion_effects"):
		var sound: AudioStreamPlayer3D = other.get_node("ExplosionSound")
		check(sound.playing and sound.pitch_scale >= 0.92 and sound.pitch_scale <= 1.08, "Each explosion gets its own bounded playback variation")
		pitches[sound.pitch_scale] = true
	check(pitches.size() > 1, "Explosions do not all have identical pitch and duration")
	await create_timer(1.6).timeout
	check(is_instance_valid(effect) and audio.playing, "Long sound survives the visual effect lifetime")
	if is_instance_valid(effect):
		check(not effect.explosion_pulse.visible and not effect.explosion_light.visible and not effect.fire_particles.visible, "Visuals still end on their original schedule")
	var deadline := Time.get_ticks_msec() + 5000
	while not get_nodes_in_group(&"debug_explosion_effects").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(get_nodes_in_group(&"debug_explosion_effects").is_empty(), "Explosion audio and effects clean themselves up after playback")
	world.free()
	print("Vehicle explosion audio: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func check_vehicle(scene: PackedScene) -> void:
	var car := scene.instantiate() as Vehicle
	root.add_child(car)
	var sounds := car.find_children("*", "AudioStreamPlayer3D", true, false)
	check(sounds.size() == 1, scene.resource_path + ": exactly one engine player")
	var engine := car.get_node_or_null("EngineSound") as AudioStreamPlayer3D
	check(engine != null, scene.resource_path + ": engine node exists")
	if engine != null:
		engine.set_process(false) # Step audio tuning explicitly for deterministic checks.
		check(engine.playing, scene.resource_path + ": starts automatically")
		check(engine.pitch_scale >= engine.base_pitch * 0.96 and engine.pitch_scale <= engine.base_pitch * 1.04, "Per-car pitch variation stays within four percent")
		var idle_pitch: float = engine.pitch_scale
		car.traffic_controlled = true
		car.traffic_speed = engine.pitch_reference_speed
		engine._process(0.1)
		check(engine.pitch_scale > idle_pitch and engine.pitch_scale < idle_pitch * 1.18, "Driving smoothly raises pitch and playback speed")
		engine._process(10.0)
		check(is_equal_approx(engine.pitch_scale, idle_pitch * 1.18), "Reference speed reaches the configured pitch increase")
		car.traffic_speed = 200.0
		engine._process(10.0)
		check(is_equal_approx(engine.pitch_scale, idle_pitch * 1.18), "Speed pitch increase is capped")
		car.traffic_speed = 0.0
		engine._process(10.0)
		check(is_equal_approx(engine.pitch_scale, idle_pitch), "Stopped traffic returns to its own idle pitch")
		car.traffic_speed = 12.0
		car.traffic_controlled = false
		car.linear_velocity = Vector3(100, 100, 0)
		engine._process(10.0)
		check(is_equal_approx(engine.pitch_scale, idle_pitch), "Thrown or carried motion does not rev the engine")
		check(engine.stream is AudioStreamMP3 and engine.stream.loop, "Engine recording loops")
		check(engine.max_distance == 80.0 and engine.unit_size == 12.0, "Pass-by distance settings inherited")
		check(engine.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED, "Engine remains positional with distance attenuation")
		car.position = Vector3(20, 0, 5)
		check(engine.global_position.is_equal_approx(car.to_global(engine.position)), "Engine follows the vehicle")
		var holder := Node3D.new()
		root.add_child(holder)
		car.reparent(holder)
		check(engine.playing, "Pickup-style reparenting preserves playback")
		car.apply_damage(DAMAGE.new(car.get_max_health()))
		check(car.is_destroyed and not engine.playing, "Destruction stops engine audio")
		car.free()
		holder.free()
	else:
		car.free()

func run() -> void:
	var model_pitches := {}
	for model in ["normal_car_1", "normal_car_2", "sports_car", "sports_car_2", "cop", "suv", "taxi"]:
		var scene: PackedScene = load("res://scenes/vehicles/%s.tscn" % model)
		var car = scene.instantiate()
		model_pitches[car.get_node("EngineSound").base_pitch] = true
		car.free()
		check_vehicle(scene)
	check(model_pitches.size() == 7, "All seven vehicle models have distinct base pitches")
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	for entry in manager.vehicle_entries:
		check_vehicle(entry.scene)
	manager.free()
	var stream = load("res://assets/audio/Vehicles/care_engine.mp3")
	check(not stream.loop, "Shared import is unchanged")
	var disabled = load("res://scenes/vehicles/engine_sound.tscn").instantiate()
	disabled.engine_enabled = false
	root.add_child(disabled)
	check(not disabled.playing, "Inspector engine toggle prevents playback")
	disabled.free()
	print("Vehicle engine audio: %s (7 base models and all traffic entries)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

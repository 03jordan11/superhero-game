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
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager", "CivilianCrowd", "Sound", "PreviewCamera"]:
		city.get_node(label).free()
	root.add_child(city)
	var camera := Camera3D.new()
	city.add_child(camera)
	camera.position = Vector3(-550, 3, 400)
	camera.make_current()
	var cycle = city.get_node("DayNightCycle")
	cycle.cycle_running = false
	var lights = city.get_node("NightLights")
	await process_frame
	check(lights.fixtures.size() > 300, "Lamp posts cover multiple city districts")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	for fixture in lights.fixtures:
		var point := Vector2(fixture.transform.origin.x, fixture.transform.origin.z)
		var supported := false
		for row in layout.sidewalks:
			if Rect2(row[0], row[1], row[2], row[3]).has_point(point):
				supported = true
				break
		check(supported, "Every lamp base is on a sidewalk")
		for road in layout.roads:
			var r: Array = road.rect
			check(not Rect2(r[0], r[1], r[2], r[3]).has_point(point), "Lamp base does not block a road")
	cycle.set_time(0.0)
	check(is_equal_approx(cycle.night_lighting, 1.0), "Midnight powers the city's night lights")
	lights._select_lights()
	var active := 0
	for light in lights._lights:
		if light.visible: active += 1
	check(active > 0 and active <= lights.max_active_lights, "Pavement lights use a bounded active pool")
	var first_position: Vector3 = lights._lights[0].global_position
	camera.position.x = 1100.0
	lights._select_lights()
	check(lights._lights[0].global_position.distance_to(first_position) > 500.0, "Lamp pool follows the camera across districts")
	cycle.set_time(12.0)
	for light in lights._lights: check(not light.visible, "No pavement lights at noon")
	for material in lights._lens_materials: check(is_zero_approx(material.emission_energy_multiplier), "Lamp lenses switch off in daylight")
	for model in ["cop", "normal_car_1", "normal_car_2", "sports_car", "sports_car_2", "suv", "taxi", "variants/suv_black"]:
		cycle.set_time(0.0)
		var car: Node3D = load("res://scenes/vehicles/%s.tscn" % model).instantiate()
		city.add_child(car)
		await process_frame
		var rig = car.get_node("Headlights")
		check(rig.beams.size() == 2, model + ": two forward headlights")
		for beam in rig.beams:
			check(beam.visible and beam.light_energy > 0.0, model + ": late-spawned car starts lit at night")
			var forward: Vector3 = -beam.basis.z
			check(forward.z > 0.9 and forward.y < 0.0, "Headlight beam faces the +Z nose and pavement")
		cycle.set_time(12.0)
		for beam in rig.beams: check(not beam.visible, model + ": headlights off in daylight")
		cycle.set_time(18.0)
		check(rig.beams[0].light_energy > 0.0 and rig.beams[0].light_energy < rig.beam_energy, "Dusk fades lights instead of snapping")
		cycle.set_time(0.0)
		var holder := Node3D.new()
		city.add_child(holder)
		car.reparent(holder)
		holder.rotation.y = 1.0
		check(rig.beams[0].global_position.is_equal_approx(car.to_global(rig.beams[0].position)), "Reparented car keeps aligned headlights")
		car.apply_damage(DAMAGE.new(100.0))
		for beam in rig.beams: check(not beam.visible, "Destroyed vehicle lamps go dark")
		cycle.set_time(12.0)
		cycle.set_time(0.0)
		for beam in rig.beams: check(not beam.visible, "Time change cannot relight a destroyed vehicle")
		holder.free()
	print("City night lights: %d fixtures; %d failures" % [lights.fixtures.size(), failures])
	city.free()
	# Exercise the real distant traffic material in the Main scene too.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var main_cycle = main.get_node("SuperCity/DayNightCycle")
	main_cycle.cycle_running = false
	var lod = main.get_node("SuperCity/TrafficManager/DistantTraffic")
	main_cycle.set_time(0.0)
	check(lod._mesh.surface_get_material(0).next_pass == lod._night_material, "Distant traffic gets its night lens pass")
	check(is_equal_approx(lod._night_material.get_shader_parameter("night_amount"), 1.0), "Distant lenses follow the clock")
	main_cycle.set_time(12.0)
	check(lod._mesh.surface_get_material(0).next_pass == null, "Distant extra pass is removed during daylight")
	main.free()
	print("City night-light integration: %d failures" % failures)
	quit(0 if failures == 0 else 1)

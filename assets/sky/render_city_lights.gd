extends SceneTree
## Actual Forward+ city captures, with parked cars for reproducible beam inspection.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/night_lights")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager", "CivilianCrowd", "Sound", "PreviewCamera"]:
		city.get_node(label).free()
	viewport.add_child(city)
	var cycle = city.get_node("DayNightCycle")
	cycle.cycle_running = false
	cycle.set_time(0.0)
	var camera := Camera3D.new()
	camera.far = 5000.0
	camera.fov = 70.0
	viewport.add_child(camera)
	camera.make_current()
	var cars: Array[Node3D] = []
	for entry in [["normal_car_1", Vector3(-556, 0.12, 393), 0.0], ["taxi", Vector3(-564, 0.12, 419), PI], ["suv", Vector3(-564, 0.12, 384), PI]]:
		var car: Node3D = load("res://scenes/vehicles/%s.tscn" % entry[0]).instantiate()
		city.add_child(car)
		car.position = entry[1]
		car.rotation.y = entry[2]
		car.health_label.hide()
		car.get_node("EngineSound").stop()
		cars.append(car)
	# Compile and inspect the same lightweight lens pass used by distant traffic.
	var proxy_mesh: ArrayMesh = load("res://scripts/traffic/traffic_proxy_mesh.gd").build(0.55, 0.8, 0.5, -0.08, 0.12)
	var proxy_material: StandardMaterial3D = proxy_mesh.surface_get_material(0)
	var lens_pass := ShaderMaterial.new()
	lens_pass.shader = load("res://scripts/traffic/traffic_night_lenses.gdshader")
	_set_proxy_lights(cycle.night_lighting, lens_pass, proxy_material)
	cycle.night_lighting_changed.connect(_set_proxy_lights.bind(lens_pass, proxy_material))
	for i in 2:
		var proxy := MeshInstance3D.new()
		if i == 0:
			proxy.mesh = proxy_mesh
		else:
			var flat := PlaneMesh.new()
			flat.size = Vector2.ONE
			flat.material = proxy_material
			proxy.mesh = flat
		proxy.scale = Vector3(2.4, 1.6, 5.8)
		proxy.position = Vector3(-556 - i * 8, 0.9, 449)
		city.add_child(proxy)
	for frame in 40: await process_frame
	camera.position = Vector3(-550, 3.2, 364)
	camera.look_at(Vector3(-560, 5, 433))
	await capture(viewport, city, "night_street")
	camera.position = Vector3(-546, 12, 376)
	camera.look_at(Vector3(-560, 0, 410))
	await capture(viewport, city, "headlight_beams")
	cycle.set_time(12.0)
	await capture(viewport, city, "day_lights_off")
	cycle.set_time(0.0)
	camera.position = Vector3(-560, 110, 500)
	camera.look_at(Vector3(-560, 0, 310))
	await capture(viewport, city, "district_night")
	camera.position = Vector3(-550, 6, 438)
	camera.look_at(Vector3(-560, 0.9, 449))
	await capture(viewport, city, "distant_lenses")
	viewport.free()
	quit()

func _set_proxy_lights(amount: float, lenses: ShaderMaterial, material: StandardMaterial3D) -> void:
	lenses.set_shader_parameter("night_amount", amount)
	material.next_pass = lenses if amount > 0.001 else null

func capture(viewport: SubViewport, city: Node3D, label: String) -> void:
	city.get_node("NightLights")._select_lights()
	for frame in 15: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png("res://artifacts/night_lights/%s.png" % label) == OK)
	print("Captured " + label)

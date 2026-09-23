extends SceneTree
## Exercise the actual day/night clock, including loading the building after dark.
const HALL := "res://assets/buildings/city_hall/city_hall.tscn"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var preview: Node3D = load("res://assets/buildings/city_hall/city_hall_preview.tscn").instantiate()
	root.add_child(preview)
	var hall: Node3D = preview.get_node("CityHall")
	var clock: Node = preview.get_node("DayNightCycle")
	var independent: Node3D = load(HALL).instantiate()
	independent.follow_day_night_cycle = false
	independent.position.x = 500
	root.add_child(independent)
	await process_frame
	await process_frame
	assert(hall._night_materials.size() == 1, "Window emission was not imported")
	assert(independent._night_materials.size() == 1)
	var lit: ShaderMaterial = hall._night_materials[0]
	var unlit: ShaderMaterial = independent._night_materials[0]
	assert(lit != unlit, "Lighting material leaked across instances")
	assert(lit.get_shader_parameter("window_mask") != null)
	clock.set_time(13)
	assert(is_zero_approx(_energy(lit)), "Windows glow during the day")
	clock.set_time(0)
	assert(is_equal_approx(_energy(lit), hall.window_emission_energy))
	assert(is_zero_approx(_energy(unlit)), "Independent building changed with clock")
	var late: Node3D = load(HALL).instantiate()
	late.position.x = 1000
	root.add_child(late)
	await process_frame
	await process_frame
	assert(_energy(late._night_materials[0]) > 0, "Night spawn did not synchronize")
	clock.set_time(13)
	assert(is_zero_approx(_energy(lit)))
	assert(is_zero_approx(_energy(late._night_materials[0])), "Windows stayed lit after daylight")
	hall.apply_night(.5)
	assert(is_equal_approx(_energy(lit), hall.window_emission_energy * .5))
	# Inspect every cell: frames and mullions stay black, with both lit and dark rooms.
	var mask := Image.load_from_file("res://assets/buildings/city_hall/city_hall_windows_emission.png")
	assert(mask.get_size() == Vector2i(1024, 1024))
	var lit_cells := 0
	for row in 8:
		for col in 8:
			var x := col * 128
			var y := row * 128
			assert(mask.get_pixel(x, y).r == 0)
			assert(mask.get_pixel(x + 64, y + 32).r == 0, "Mullion emits")
			# PNG rows run top-down; Blender's image buffer uses bottom-up rows.
			assert(mask.get_pixel(x + 32, y + 79).r == 0, "Transom emits")
			if mask.get_pixel(x + 32, y + 32).r > .1:
				lit_cells += 1
	assert(lit_cells > 16 and lit_cells < 48, "Expected an occupied/dark room mix")
	# The bare imported material remains unchanged by per-instance runtime overrides.
	for mesh: MeshInstance3D in hall.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				assert(mesh.get_active_material(surface) == load("res://assets/super-city/modular-sidewalks/sidewalk.tres"), "Unexpected non-window shader material")
				continue
			if source.emission_enabled:
				assert(source != lit and source != unlit)
			else:
				assert(not (mesh.get_active_material(surface) as StandardMaterial3D).emission_enabled, "Stone/roof/furniture unexpectedly emits")
	late.free()
	independent.free()
	preview.free()
	print("CITY_HALL_LIGHTING_PASS: clock night/day transitions, night spawn, isolated materials, glass-only emission, lit/dark atlas cells")
	quit()

func _energy(material: Material) -> float:
	return material.get_shader_parameter("emission_energy") if material is ShaderMaterial else material.emission_energy_multiplier

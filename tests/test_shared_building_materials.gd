extends SceneTree

const BUILDING = preload("res://assets/generated-buildings/residential/residential_building_01.tscn")
var failures := 0

class TestClock extends Node:
	signal night_lighting_changed(amount: float)
	var night_lighting := 1.0
	func _enter_tree() -> void: add_to_group(&"day_night_cycle")
	func set_night(amount: float) -> void:
		night_lighting = amount
		night_lighting_changed.emit(amount)

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var library := root.get_node("CityWindows")
	library.restore_data({"seed": 12345})
	var world := Node3D.new()
	root.add_child(world)
	var clock := TestClock.new()
	world.add_child(clock)
	var first := BUILDING.instantiate()
	var second := BUILDING.instantiate()
	var different := BUILDING.instantiate()
	var preview := BUILDING.instantiate()
	preview.follow_day_night_cycle = false
	for body in [first, second, different, preview]: world.add_child(body)
	for x in range(1, 100):
		different.position.x = x * 10.0
		if library.variant_for(first._original_mesh.resource_path, different.position) != first._window_variant: break
	await process_frame
	await process_frame
	var first_mat: ShaderMaterial = first._night_materials[0]
	check(first_mat == second._night_materials[0], "Matching placements must share the material resource")
	check(first_mat != different._night_materials[0], "Different window patterns must remain separate")
	check(first_mat != preview._night_materials[0], "Standalone preview must remain independent")
	check(first_mat.get_shader_parameter("room_data") == library.texture_for(first._original_mesh, first._window_sources.keys()[0], first._window_variant), "Shared material retains the correct window pattern")
	clock.set_night(0)
	check(first_mat.get_shader_parameter("emission_energy") == 0, "Daytime updates shared resources")
	clock.set_night(0.5)
	check(first_mat.get_shader_parameter("emission_energy") == 1, "Sunset updates shared resources")
	second.window_emission_energy = 4
	check(first_mat != second._night_materials[0], "Per-building intensity override detaches from the shared group")
	check(first_mat.get_shader_parameter("emission_energy") == 1 and second._night_materials[0].get_shader_parameter("emission_energy") == 2, "Intensity override must not bleed to peers")
	second.window_emission_energy = 2
	check(first_mat == second._night_materials[0], "Matching intensity rejoins existing shared material")
	paused = true
	library.residential_percent = 23
	library.brightness = 1.25
	check(is_equal_approx(first_mat.get_shader_parameter("occupancy"), 0.23) and first_mat.get_shader_parameter("brightness") == 1.25, "Paused developer controls update shared materials")
	var amber: Color = library.PALETTE.warm_amber
	library.PALETTE.warm_amber = Color("cc9955")
	check(first_mat.get_shader_parameter("warm_amber") == Color("cc9955"), "Palette changes reach shared resources")
	library.PALETTE.warm_amber = amber
	paused = false
	var saved: Dictionary = library.save_data()
	var pixels: PackedByteArray = first_mat.get_shader_parameter("room_data").get_image().get_data()
	library.set_city_seed(54321)
	check(first._night_materials[0] == second._night_materials[0], "Seed rebuild preserves equivalent sharing")
	check(first._night_materials[0].get_shader_parameter("room_data").get_image().get_data() != pixels, "New seed changes actual window data")
	library.restore_data(saved)
	check(first._night_materials[0].get_shader_parameter("room_data").get_image().get_data() == pixels, "Save restoration reproduces exact window pattern")
	check(first._night_materials[0] == second._night_materials[0], "Save restoration preserves sharing")
	first.apply_night(0)
	check(first._night_materials[0] != second._night_materials[0], "Explicit per-building night override gets a private material")
	check(second._night_materials[0].get_shader_parameter("emission_energy") == 1, "Explicit override leaves peers unchanged")
	clock.set_night(1)
	check(first._night_materials[0].get_shader_parameter("emission_energy") == 2 and second._night_materials[0].get_shader_parameter("emission_energy") == 2, "Clock continues to update both private and shared placements")
	preview.apply_night(0)
	check(second._night_materials[0].get_shader_parameter("emission_energy") == 2, "Preview does not change live city lighting")
	var other_clock := TestClock.new()
	world.add_child(other_clock)
	var surface: int = second._window_sources.keys()[0]
	var other_material: ShaderMaterial = library.shared_material(second._original_mesh, surface, second._window_sources[surface], second._window_variant, 2, other_clock)
	check(other_material != second._night_materials[0], "Different scene clocks must not share mutable lighting")
	other_clock.set_night(0)
	check(other_material.get_shader_parameter("emission_energy") == 0 and second._night_materials[0].get_shader_parameter("emission_energy") == 2, "Separate clock cannot affect city materials")
	world.remove_child(other_clock)
	world.add_child(other_clock)
	other_material = library.shared_material(second._original_mesh, surface, second._window_sources[surface], second._window_variant, 2, other_clock)
	other_clock.set_night(1)
	check(other_material.get_shader_parameter("emission_energy") == 2, "Clock can leave and re-enter without stale signal connections")
	world.free()
	check(library._shared_materials.is_empty() and library._shared_clocks.is_empty(), "Scene teardown releases shared material and clock caches")
	print("SHARED_BUILDING_MATERIALS failures=", failures)
	quit(1 if failures else 0)

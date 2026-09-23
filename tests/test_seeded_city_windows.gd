extends SceneTree
const ROOT := "res://assets/generated-buildings/"
var failures := 0
var room_count := 0
var texture_bytes := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var library := root.get_node("CityWindows")
	library.restore_data({"seed": 12345})
	check(library.use_district_percentages and library.commercial_percent == 10 and library.residential_percent == 7 and library.industrial_percent == 5, "District defaults incorrect")
	check(library.warm_window_percent == 60 and library.brightness == 2, "Color defaults incorrect")
	var started := Time.get_ticks_msec()
	var world := Node3D.new()
	root.add_child(world)
	var representatives: Array[Node] = []
	for district in ["commercial", "residential", "industrial"]:
		var prefix: String = "commercial_skyscraper" if district == "commercial" else district + "_building"
		for i in range(1, 11 if district == "industrial" else 21):
			var building: Node3D = load(ROOT + district + "/" + prefix + "_%02d.tscn" % i).instantiate()
			building.follow_day_night_cycle = false
			world.add_child(building)
			if i == 1: representatives.append(building)
			var mesh: Mesh = building._original_mesh
			check(mesh.get_faces() == building.get_node("MeshInstance3D").mesh.get_faces(), "Geometry changed")
			check(library.mesh_with_emission_uvs(mesh) == building.get_node("MeshInstance3D").mesh, "Mesh sharing failed")
			for surface in mesh.get_surface_count():
				var source := mesh.surface_get_material(surface) as StandardMaterial3D
				if not source.emission_enabled or source.emission_texture == null: continue
				check(source.emission_texture.get_size() == Vector2(64, 64), "Unsupported source tile")
				var mask: Image = library.mask_for(source.emission_texture).get_image()
				var source_image := source.emission_texture.get_image()
				for y in 64:
					for x in 64:
						if source_image.get_pixel(x, y).r > .1:
							check(mask.get_pixel(x, y).r > .9, "Authored lit pixel lost")
						var mullion: bool = x % 16 == 8 and not (district == "commercial" and i == 2)
						if x % 16 == 0 or y % 16 == 0 or mullion:
							check(mask.get_pixel(x, y).r == 0, "Emission leaked into a frame")
						if "foundry_windows" in source.emission_texture.resource_path and y >= 16:
							check(mask.get_pixel(x, y).r == 0, "Foundry solid wall lit")
				for variant in 6:
					var texture: Texture2D = library.texture_for(mesh, surface, variant)
					check(texture == library.texture_for(mesh, surface, variant), "Texture cache miss")
					var image := texture.get_image()
					texture_bytes += image.get_data().size()
					var eligible := 0
					var counts := [0, 0, 0, 0, 0]
					var ranks: Dictionary = {}
					for y in image.get_height():
						for x in image.get_width():
							var data := image.get_pixel(x, y)
							if data.r == 1: continue
							eligible += 1
							ranks[data.r] = true
							check(data.r > 0 and data.r < 1 and data.b >= .879 and data.b <= 1, "Invalid room data")
							for p in 5:
								if data.r < p * .25: counts[p] += 1
					check(eligible > 0 and ranks.size() == eligible, "Rooms need unique stable ranks")
					for p in 5:
						check(absf(counts[p] - eligible * p * .25) <= .51, "Percentage target missed")
					check(counts[0] == 0 and counts[4] == eligible, "0/100 must be exact")
					room_count += eligible
			building.apply_night(1)
			for mat in building._night_materials:
				check(mat is ShaderMaterial and mat.get_shader_parameter("emission_energy") == 2, "Night emission missing")
			building.apply_night(0)
			for mat in building._night_materials: check(mat.get_shader_parameter("emission_energy") == 0, "Day emission remained")

	var sample: ShaderMaterial = representatives[0]._night_materials[0]
	var stable: Texture2D = sample.get_shader_parameter("room_data")
	var pixels := stable.get_image().get_data()
	library.use_district_percentages = false
	for percentage in [0, 25, 50, 75, 100]:
		library.lit_window_percent = percentage
		for body in representatives:
			check(body._night_materials[0].get_shader_parameter("occupancy") == percentage / 100.0, "Live district update failed")
		check(sample.get_shader_parameter("room_data") == stable, "Tuning must not regenerate/reshuffle")
	library.use_district_percentages = true
	library.commercial_percent = 25
	library.residential_percent = 75
	library.industrial_percent = 0
	for i in 3:
		check(representatives[i]._night_materials[0].get_shader_parameter("occupancy") == [0.25, 0.75, 0.0][i], "District override failed")
	library.warm_window_percent = 60
	library.brightness = 1.25
	var saved: Dictionary = library.save_data()
	library.restore_data({"seed": 54321})
	check(sample.get_shader_parameter("room_data").get_image().get_data() != pixels, "Seed should change pattern")
	library.restore_data(saved)
	check(sample.get_shader_parameter("room_data").get_image().get_data() == pixels, "Save must reproduce pattern")
	check(library.save_data() == saved, "Settings save round trip failed")
	check(sample.get_shader_parameter("warm_fraction") == .6 and sample.get_shader_parameter("brightness") == 1.25, "Palette tuning not restored")
	library.restore_data({"seed": "bad", "brightness": INF, "lit_window_percent": -99, "residential_percent": 500})
	check(library.city_seed == 8421 and library.brightness == 2 and library.lit_window_percent == 0 and library.residential_percent == 100, "Bad save validation failed")

	# The same controls used in the debug menu must work while the game is paused.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var controls: Control = load("res://scripts/ui-scripts/window_lighting_controls.gd").new()
	layer.add_child(controls)
	paused = true
	controls._district_toggle.button_pressed = false
	controls._sliders.lit_window_percent.value = 37
	check(library.lit_window_percent == 37 and controls._numbers.lit_window_percent.value == 37, "Debug slider failed while paused")
	controls._district_toggle.button_pressed = true
	controls._numbers.industrial_percent.value = 12
	check(library.use_district_percentages and library.industrial_percent == 12, "Debug district controls failed")
	library.restore_data(saved)
	check(controls._sliders.commercial_percent.value == 25, "HUD failed to follow loaded settings")
	paused = false
	layer.free()
	world.free()
	await process_frame
	print("COLORED_WINDOWS_PASS: assets=50 rooms=", room_count, " rank MiB=", texture_bytes / 1048576.0, " audit ms=", Time.get_ticks_msec() - started, " failures=", failures)
	quit(1 if failures else 0)

extends SceneTree
const BASE := "res://assets/generated-buildings/commercial/"
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var library: Node = root.get_node("CityWindows")
	library.set_city_seed(12345)
	var started := Time.get_ticks_msec()
	var lit_total := 0; var off_total := 0; var bytes := 0
	for i in range(1, 21):
		var original: Mesh = load(BASE + "meshes/commercial_skyscraper_%02d.res" % i)
		var mesh: Mesh = library.mesh_with_emission_uvs(original)
		check(mesh.get_faces() == original.get_faces(), "Geometry changed on %d" % i)
		check(mesh == library.mesh_with_emission_uvs(original), "Mesh must be shared")
		for surface in original.get_surface_count():
			var mat := original.surface_get_material(surface) as StandardMaterial3D
			if not mat.emission_enabled: continue
			var source := mat.emission_texture.get_image()
			for variant in 6:
				var texture: Texture2D = library.texture_for(original, surface, variant)
				check(texture == library.texture_for(original, surface, variant), "Texture cache miss")
				var image := texture.get_image()
				bytes += image.get_data().size()
				var lit := 0; var off := 0
				var edits: Dictionary = {}
				for y in image.get_height() / 16:
					for x in image.get_width() / 16:
						if source.get_pixel((x*16+5)%64, (y*16+5)%64).r <= .1: continue
						lit += 1
						if image.get_pixel(x*16+5, y*16+5).r < .1:
							off += 1; edits[Vector2i(x,y)] = true
				check(absf(off - roundi(lit * library.reduction_for(variant))) <= 1, "Occupancy target missed: asset %d surface %d variant %d: %d/%d" % [i,surface,variant,off,lit])
				for cell in edits:
					check(not (edits.has(cell+Vector2i.UP) and edits.has(cell+Vector2i.DOWN)), "New vertical strip")
					check(not (edits.has(cell+Vector2i.RIGHT) and edits.has(cell+Vector2i.UP) and edits.has(cell+Vector2i(1,-1))), "New rectangular patch")
				# Sample each source pixel position throughout the facade, including frames.
				for y in image.get_height():
					for x in image.get_width():
						var a := source.get_pixel(x%64,y%64); var b := image.get_pixel(x,y)
						if b.r > a.r+.001 or b.g > a.g+.001 or b.b > a.b+.001:
							check(false,"New/brightened pixel"); break
						if b.r > .01:
							if absf(b.g/b.r-a.g/a.r) > .012 or absf(b.b/b.r-a.b/a.r) > .012:
								check(false,"Changed warm hue"); break
				lit_total += lit; off_total += off
	var build_ms := Time.get_ticks_msec() - started
	var stock: Mesh = load(BASE+"meshes/commercial_skyscraper_02.res")
	var first: PackedByteArray = library.texture_for(stock,1,2).get_image().get_data()
	library.set_city_seed(67890)
	check(first != library.texture_for(stock,1,2).get_image().get_data(), "Different seeds must differ")
	library.set_city_seed(12345)
	check(first == library.texture_for(stock,1,2).get_image().get_data(), "Seed must reproduce exact pixels")
	var scene: PackedScene = load(BASE+"commercial_skyscraper_02.tscn")
	var a: Node3D = scene.instantiate(); a.position=Vector3(10,0,20); root.add_child(a)
	var b: Node3D = scene.instantiate(); b.position=a.position; root.add_child(b)
	check(a._night_materials[0].emission_texture == b._night_materials[0].emission_texture,"Same placement must reuse variant")
	var variants: Dictionary = {}
	for x in 30: variants[library.variant_for(stock.resource_path,Vector3(x*47,0,20))] = true
	check(variants.size()==6,"Placements need varied occupancy")
	var stable: Texture2D = a._night_materials[0].emission_texture
	a.apply_night(0); a.apply_night(1)
	await process_frame
	check(stable == a._night_materials[0].emission_texture, "Time/frame must not regenerate maps")
	check(a._night_materials[0].emission_energy_multiplier==2,"Preserve emission energy")
	library.additional_windows_off = 0.30
	check(stable != a._night_materials[0].emission_texture, "Inspector occupancy changes must refresh live materials")
	library.additional_windows_off = 0.40
	check(stable.get_image().get_data() == a._night_materials[0].emission_texture.get_image().get_data(), "Restoring tuning must restore the same pixels")
	library.restore_data({})
	check(library.city_seed==8421,"Legacy seed must be deterministic")
	a.free(); b.free()
	print("SEEDED_WINDOWS: off=",float(off_total)/lit_total," native texture MiB=",bytes/1048576.0," generation+pixel checks ms=",build_ms," failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
const BASE:="res://assets/generated-buildings/commercial/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var original: Image=load(BASE+"textures/commercial_skyscraper_02_emission.res").get_image()
	var edited: Image=load(BASE+"window_trial/emission_trial.res").get_image()
	var off:=0; var lit_before:=0
	for floor_id in 26:
		for bay in 11:
			var base:=original.get_pixel((bay*16+5)%64,(floor_id*16+5)%64)
			if base.r<=.1: continue
			lit_before+=1
			if edited.get_pixel(bay*16+5,floor_id*16+5).r<.1: off+=1
	assert(lit_before==175 and off==21)
	for y in 512:
		for x in 512:
			var a:=original.get_pixel(x%64,y%64); var b:=edited.get_pixel(x,y)
			assert(b.r<=a.r+.001 and b.g<=a.g+.001 and b.b<=a.b+.001,"No brightening or newly lit pixels")
			if b.r>.01:
				assert(b.r/a.r>=.87 and b.r/a.r<=1.001)
				assert(absf(b.g/b.r-a.g/a.r)<.012 and absf(b.b/b.r-a.b/a.r)<.012,"Original warm hue must survive")
	var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/window_trial/audit.json"))
	for pair in audit.dark_cells:
		for other in audit.dark_cells:
			assert(pair[0]!=other[0] or absf(pair[1]-other[1])!=1,"No new vertical runs")
	var review: Node3D=load("res://scenes/tests/window_emission_trial.tscn").instantiate(); root.add_child(review)
	await process_frame
	await process_frame
	var mesh: Mesh=review.get_node("Building/MeshInstance3D").mesh
	var stock: Mesh=load(BASE+"meshes/commercial_skyscraper_02.res")
	assert(mesh.get_faces()==stock.get_faces(),"Trial must not change building geometry")
	assert(mesh.resource_path==BASE+"window_trial/mesh_trial.res","Review scene must retain its mesh override")
	for surface in mesh.get_surface_count():
		var mat: StandardMaterial3D=mesh.surface_get_material(surface)
		if not mat.emission_on_uv2: continue
		var arrays:=mesh.surface_get_arrays(surface)
		assert(arrays[Mesh.ARRAY_TEX_UV2]!=null)
		for vertex in arrays[Mesh.ARRAY_TEX_UV].size():
			assert(arrays[Mesh.ARRAY_TEX_UV2][vertex].is_equal_approx(arrays[Mesh.ARRAY_TEX_UV][vertex]/8.0))
	assert(review._facade.emission_on_uv2 and review._facade.emission_energy_multiplier==2)
	var env: Environment=review.get_node("Daylight").environment
	var density:=env.fog_density; var bloom:=env.glow_intensity
	review.set_trial(false)
	assert(not review._facade.emission_on_uv2)
	assert(review._facade.emission_texture.resource_path==BASE+"textures/commercial_skyscraper_02_emission.res")
	review.set_trial(true)
	assert(review._facade.emission_on_uv2 and env.fog_density==density and env.glow_intensity==bloom)
	# The original-emission opt-out remains available for asset comparisons.
	for i in range(1,21):
		var scene: StaticBody3D=load(BASE+"commercial_skyscraper_%02d.tscn"%i).instantiate()
		scene.seeded_window_patterns=false
		scene.follow_day_night_cycle=false; root.add_child(scene); scene.apply_night(1)
		for material in scene._night_materials:
			assert(material is StandardMaterial3D and not material.emission_on_uv2)
			assert(material.emission_texture.resource_path.begins_with(BASE+"textures/commercial_skyscraper_"))
			assert(material.emission_energy_multiplier==2)
		scene.free()
	review.free(); print("WINDOW_TRIAL_PASS: historical 12% comparison isolated, original pixels/hue/geometry preserved, all 20 assets support original-emission opt-out, environment unchanged"); quit()

extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var library := root.get_node("CityWindows")
	library.restore_data({"seed":12345})
	var expected := {"bank1":2.0,"bank2":2.0,"police_station":20.0,"city_hall":10.0,"hospital":30.0,"firehouse":10.0}
	for slug: String in expected:
		var body: Node3D = load("res://assets/buildings/%s/%s.tscn" % [slug,slug]).instantiate()
		body.follow_day_night_cycle = false
		var originals: Dictionary = {}
		for mesh: MeshInstance3D in body.get_node("Model").find_children("*","MeshInstance3D",true,false): originals[mesh] = mesh.mesh.get_faces()
		root.add_child(body)
		check(body._room_count > 0, slug+" has no rooms")
		var data: Image = body._room_texture.get_image()
		var lit := 0
		for x in data.get_width():
			if data.get_pixel(x,0).r < expected[slug]/100: lit += 1
		check(absf(lit-body._room_count*expected[slug]/100) <= .51, slug+" missed percentage")
		for mesh in originals: check(mesh.mesh.get_faces()==originals[mesh], slug+" geometry changed")
		body.apply_night(1)
		var stable: Texture2D = body._room_texture
		var pixels := stable.get_image().get_data()
		var original_amber: Color = library.PALETTE.warm_amber
		library.PALETTE.warm_amber = Color("cc9955")
		for mat in body._night_materials:
			if mat is ShaderMaterial: check(mat.get_shader_parameter("warm_amber")==Color("cc9955"),"Palette edit did not propagate")
		library.PALETTE.warm_amber = original_amber
		for mat in body._night_materials:
			if mat is ShaderMaterial:
				check(is_equal_approx(mat.get_shader_parameter("occupancy"),expected[slug]/100),slug+" wrong uniform")
				check(mat.get_shader_parameter("warm_amber")==library.PALETTE.warm_amber,slug+" not using shared palette")
				check(mat.get_shader_parameter("brightness")==2.0,slug+" wrong brightness")
				check(is_equal_approx(mat.get_shader_parameter("warm_fraction"),.6),slug+" wrong warm mix")
			else:
				check(mat.emission_energy_multiplier>0,slug+" fixture/sign disabled")
		library.brightness = 0
		check(body._room_texture==stable,"Brightness regenerated pattern")
		for mat in body._night_materials:
			if mat is StandardMaterial3D: check(mat.emission_energy_multiplier>0,"Window brightness disabled a sign/lamp")
		library.brightness = 2
		library.set_city_seed(9876)
		check(body._room_texture.get_image().get_data()!=pixels,"Seed did not refresh POI")
		library.set_city_seed(12345)
		check(body._room_texture.get_image().get_data()==pixels,"Seed did not restore POI")
		body.apply_night(0)
		for mat in body._night_materials:
			check((mat.get_shader_parameter("emission_energy") if mat is ShaderMaterial else mat.emission_energy_multiplier)==0,"Daylight emission remained")
		print("POI_WINDOWS ",slug," rooms=",body._room_count," lit=",lit," percent=",expected[slug])
		body.free()
	var saved: Dictionary = library.save_data()
	library.bank_percent = 99
	library.restore_data(saved)
	check(library.bank_percent==2,"POI setting not saved/restored")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var controls := preload("res://scripts/ui-scripts/window_lighting_controls.gd").new()
	layer.add_child(controls)
	paused = true
	controls._sliders.hospital_percent.value = 45
	check(library.hospital_percent==45,"Paused POI HUD control failed")
	library.restore_data(saved)
	check(controls._sliders.hospital_percent.value==30,"POI HUD did not follow load")
	paused = false
	layer.free()
	print("POI_PALETTE_TEST failures=",failures)
	quit(1 if failures else 0)

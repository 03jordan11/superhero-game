extends SceneTree
const OUT := "res://assets/generated-buildings/commercial/window_trial/"
const BASE := "res://assets/generated-buildings/commercial/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var original:=Image.load_from_file(BASE+"textures/commercial_skyscraper_02_emission.png")
	var image:=Image.create(512,512,false,Image.FORMAT_RGB8)
	for y in 8:
		for x in 8: image.blit_rect(original,Rect2i(0,0,64,64),Vector2i(x*64,y*64))
	var candidates: Array[Vector2i]=[]
	for floor_id in 26:
		for bay in 11:
			if image.get_pixel(bay*16+5,floor_id*16+5).r>.1: candidates.append(Vector2i(bay,floor_id))
	var lit_before:=candidates.size()
	var rng:=RandomNumberGenerator.new(); rng.seed=20713
	for i in range(candidates.size()-1,0,-1):
		var j:=rng.randi_range(0,i); var temp:=candidates[i]; candidates[i]=candidates[j]; candidates[j]=temp
	var off: Array[Vector2i]=[]
	var target:=roundi(lit_before*.12)
	for cell in candidates:
		if off.size()>=target: break
		if cell in off or cell+Vector2i.UP in off or cell+Vector2i.DOWN in off: continue
		off.append(cell)
		# A few same-floor pairs; never vertical runs or multi-floor rectangles.
		var neighbor:=cell+Vector2i.RIGHT
		if off.size()%5==0 and off.size()<target and neighbor in candidates and neighbor not in off and neighbor+Vector2i.UP not in off and neighbor+Vector2i.DOWN not in off:
			off.append(neighbor)
	var dimmed:=0
	for cell in candidates:
		if cell in off:
			image.fill_rect(Rect2i(cell*16,Vector2i(16,16)),Color.BLACK)
		elif rng.randf()<.35:
			dimmed+=1
			var strength:=rng.randf_range(.88,.97)
			for y in 16:
				for x in 16:
					var point:=cell*16+Vector2i(x,y)
					image.set_pixelv(point,image.get_pixelv(point)*strength)
	assert(image.save_png(OUT+"commercial_skyscraper_02_emission_trial.png")==OK)
	image.generate_mipmaps(); var texture:=ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,OUT+"emission_trial.res")==OK)
	texture=ResourceLoader.load(OUT+"emission_trial.res", "", ResourceLoader.CACHE_MODE_REPLACE)
	var body: StaticBody3D=load(BASE+"commercial_skyscraper_02.tscn").instantiate(); body.name="Building"
	body.seeded_window_patterns=false
	var original_mesh: Mesh=body.get_node("MeshInstance3D").mesh
	var mesh:=ArrayMesh.new()
	for surface in original_mesh.get_surface_count():
		var arrays:=original_mesh.surface_get_arrays(surface)
		var source: StandardMaterial3D=original_mesh.surface_get_material(surface)
		if source.albedo_texture!=null and source.albedo_texture.resource_path.ends_with("dark_glass.res"):
			var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV].duplicate()
			for i in uvs.size(): uvs[i]/=8.0
			arrays[Mesh.ARRAY_TEX_UV2]=uvs
			source=source.duplicate(); source.emission_texture=texture; source.emission_on_uv2=true
			assert(ResourceSaver.save(source,OUT+"facade_trial.tres")==OK)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,source)
	assert(ResourceSaver.save(mesh,OUT+"mesh_trial.res")==OK)
	body.get_node("MeshInstance3D").mesh=mesh
	var root_node:=Node3D.new(); root_node.name="WindowEmissionTrial"
	root_node.set_script(load(BASE+"window_trial/review.gd"))
	root_node.add_child(body); body.owner=root_node
	var env:=WorldEnvironment.new(); env.name="Daylight"; root_node.add_child(env); env.owner=root_node
	for label in ["Sun","Moon"]:
		var light:=DirectionalLight3D.new(); light.name=label; root_node.add_child(light); light.owner=root_node
	var clock: Node=load("res://scripts/day_night_cycle.gd").new(); clock.name="DayNightCycle"
	clock.time_of_day=0; clock.cycle_running=false; root_node.add_child(clock); clock.owner=root_node
	var camera:=Camera3D.new(); camera.name="Camera3D"; camera.current=true; camera.far=4000
	root_node.add_child(camera); camera.owner=root_node
	var ui:=CanvasLayer.new(); ui.name="UI"; root_node.add_child(ui); ui.owner=root_node
	var label:=Label.new(); label.name="Instructions"; label.position=Vector2(24,20)
	label.add_theme_font_size_override("font_size",22); ui.add_child(label); label.owner=root_node
	var packed:=PackedScene.new(); assert(packed.pack(root_node)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/tests/window_emission_trial.tscn")==OK)
	# PackedScene does not retain edits to an instanced child's mesh automatically.
	var scene_path:="res://scenes/tests/window_emission_trial.tscn"
	var scene_text:=FileAccess.get_file_as_string(scene_path)
	var first_node:=scene_text.find("[node ")
	scene_text=scene_text.insert(first_node,"[ext_resource type=\"ArrayMesh\" path=\""+OUT+"mesh_trial.res\" id=\"trial_mesh\"]\n\n")
	scene_text+="\n[node name=\"MeshInstance3D\" parent=\"Building\" index=\"0\"]\nmesh = ExtResource(\"trial_mesh\")\n\n[editable path=\"Building\"]\n"
	FileAccess.open(scene_path,FileAccess.WRITE).store_string(scene_text)
	var positions:=[]
	for cell in off: positions.append([cell.x,cell.y])
	var audit:={"representative":"commercial_skyscraper_02", "original_lit_cells":lit_before,"additional_windows_off":off.size(),"dimmed_windows":dimmed,"removed_fraction":float(off.size())/lit_before,"dark_cells":positions,"scope":"One review-scene instance; no city materials or meshes modified"}
	FileAccess.open("res://artifacts/window_trial/audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	print("WINDOW_TRIAL_BUILT: ",audit)
	root_node.free(); quit()

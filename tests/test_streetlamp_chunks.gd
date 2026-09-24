extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures<=10: push_error(message)
func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Streetlamp test timeout"); quit(1))
	var world := Node3D.new()
	var saved: Node = load("res://scenes/main.tscn").instantiate()
	for label in ["Roads", "Sidewalks"]:
		var branch: Node = saved.get_node("SuperCity/" + label)
		branch.get_parent().remove_child(branch)
		branch.owner = null
		world.add_child(branch)
	saved.free()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var lights: Node3D = load("res://scripts/city_night_lights.gd").new()
	world.add_child(lights)
	var chunks = lights.get_node("StreetlampChunks")
	chunks.set_process(false)
	check(chunks.prepared and chunks.prepared_chunks==chunks.total_chunks,"All chunks prepared for the loading screen")
	check(chunks.entries.size()>4,"City-wide batches are now spatially divided")
	check(not lights.get_node("OriginalFixtures").visible,"Legacy batches don't render beneath replacements")
	var triangles := []
	for mesh: Mesh in chunks.meshes:
		check(mesh.get_surface_count()==1,"One material surface at every LOD")
		triangles.append(mesh.get_faces().size()/3)
	check(triangles==[228,48,12],"Full/simple/head geometry has actual triangle reductions")
	var covered := {}
	var readback := DisplayServer.get_name()!="headless"
	if not readback: print("Headless dummy renderer has no MultiMesh transform/custom-data readback; those assertions require the graphical test run.")
	for entry in chunks.entries:
		check(entry.bounds.size.x<255 and entry.bounds.size.z<255,"Each batch is spatially bounded to one250m cell")
		for j in entry.indices.size():
			var index: int = entry.indices[j]
			check(not covered.has(index),"Each fixture occurs in one chunk only")
			covered[index] = true
			var original: Transform3D = lights.fixtures[index].transform
			for batch: MultiMeshInstance3D in entry.batches:
				if readback:
					check((entry.node.transform*batch.multimesh.get_instance_transform(j)).is_equal_approx(original),"Fixture placement and orientation unchanged")
					check(is_equal_approx(batch.multimesh.get_instance_custom_data(j).r,float(lights.fixtures[index].style)),"District lamp color retained")
				check(batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"No new lamp shadow cost")
	check(covered.size()==lights.fixtures.size(),"All authored fixtures covered")
	for mode in [1,2,3,4]:
		lights._set_night(1.0)
		chunks.force_lod = mode
		chunks.update_visibility()
		for entry in chunks.entries:
			for level in 3: check(entry.batches[level].visible==(level==mode-1),"Exactly one LOD visible, or none when hidden")
	chunks.force_lod=0
	var entry: Dictionary = chunks.entries[0]
	var box: AABB = entry.node.global_transform*entry.bounds
	for sample in [[0,0],[151,1],[140,1],[124,0],[376,2],[365,2],[349,1],[776,3],[765,3],[749,2]]:
		camera.position=Vector3(box.end.x+sample[0],box.get_center().y,box.get_center().z)
		chunks.update_visibility()
		check(entry.state==sample[1],"3D nearest-bound thresholds and25m hysteresis: "+str(sample))
	chunks.force_lod=3
	lights._set_night(0.0)
	for item in chunks.entries:
		for batch in item.batches: check(not batch.visible,"Tiny heads omitted during daylight")
	check(is_zero_approx(chunks.material.get_shader_parameter("night_amount")),"Baked emission off at noon")
	lights._set_night(0.5)
	check(is_equal_approx(chunks.material.get_shader_parameter("night_amount"),0.5),"Dusk preserves gradual emission")
	for item in chunks.entries: check(item.batches[2].visible,"Distant heads return at night")
	chunks.enabled=false
	check(lights.get_node("OriginalFixtures").visible,"Disable restores original city-wide batches")
	for item in chunks.entries:
		for batch in item.batches: check(not batch.visible,"Disable hides replacement batches")
	chunks.enabled=true
	chunks.force_lod=1
	chunks.update_visibility()
	chunks.visible=false
	for item in chunks.entries: check(not item.batches[0].is_visible_in_tree(),"Controller visibility hides fixtures")
	chunks.visible=true
	camera.position=lights.fixtures[0].transform.origin+Vector3(0,3,0)
	lights._set_night(1.0)
	var active: int = lights._lights.filter(func(n): return n.visible).size()
	check(active>0 and active<=96 and lights._lights.size()==96 and lights._frontage_lights.size()==24,"Nearby lighting pool and frontage budgets preserved")
	camera.position.y=1000
	lights._select_lights()
	for light in lights._lights: check(not light.visible,"No pavement light allocations far below high flight")
	for light in lights._frontage_lights: check(not light.visible,"No frontage light allocations far below high flight")
	# Default automatic state cost at two fixed viewpoints: geometry only, not FPS.
	chunks.force_lod=0
	for position in [Vector3(0,3,0),Vector3(0,1000,0)]:
		camera.position=position
		chunks.update_visibility()
		var totals := [0,0,0,0]
		var submitted := 0
		for item in chunks.entries:
			totals[item.state]+=1
			if item.state<3: submitted+=triangles[item.state]*item.indices.size()
		print("Streetlamp configured geometry at ",position,": cells full/simple/heads/hidden ",totals,"; ",submitted," triangles before camera culling")
	print("Streetlamps: ",lights.fixtures.size()," fixtures, ",chunks.entries.size()," cells, ",triangles," triangles per fixture; ",failures," failures")
	world.free()
	quit(1 if failures else 0)

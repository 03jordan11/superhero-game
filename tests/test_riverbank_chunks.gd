extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Riverbank test timeout"); quit(1))
	paused = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled=false
	var region := world.get_node("SuperCity/Waterfront/Riverbanks")
	var controller = region.get_node("RiverbankChunks")
	var collision := {}
	for shape in region.find_children("*","CollisionShape3D",true,false):
		collision[shape] = [shape.disabled,shape.transform,shape.shape]
	var authored := {}
	for mesh: MeshInstance3D in region.find_children("*","MeshInstance3D",true,false):
		if controller.is_ancestor_of(mesh): continue
		authored[mesh] = mesh.visible
	var harbor := world.get_node("SuperCity/Waterfront/Harbor")
	# Isolate riverbank switching from the harbor's separately tested batching.
	harbor.get_node("HarborChunks").enabled = false
	var harbor_state := {}
	for node in harbor.find_children("*","Node3D",true,false): harbor_state[node] = [node.transform,node.visible]
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	for frame in 6: await process_frame
	controller.set_process(false)
	check(controller.prepared and controller.valid_bake,"Main's authored layout matches bake")
	check(controller.entries.size()==11 and controller.sources.size()==105,"11 chunks replace all 105 visible meshes")
	for source in controller.sources: check(not source.visible,"Original visual disabled in both LODs")
	for wall_name in ["QuayWall171","QuayWall172","QuayWall173"]:
		var wall: MeshInstance3D = region.get_node(wall_name)
		var expected := wall.global_transform*wall.get_aabb()
		for detail: MeshInstance3D in wall.find_children("*","MeshInstance3D",true,false):
			expected = expected.merge(detail.global_transform*detail.get_aabb())
		var spans: Array[AABB] = []
		for entry in controller.entries:
			if str(entry.node.name).begins_with("Seawall_"+wall_name+"_"):
				spans.append(entry.near.global_transform*entry.near.get_aabb())
		spans.sort_custom(func(a: AABB,b: AABB): return a.position.x<b.position.x)
		var merged := spans[0]
		for i in range(1,spans.size()):
			check(absf(merged.end.x-spans[i].position.x)<0.01,"No gap at seawall chunk seams")
			merged=merged.merge(spans[i])
		check(merged.position.distance_to(expected.position)<0.01 and merged.end.distance_to(expected.end)<0.01,"Complete authored seawall footprint preserved")
	for entry in controller.entries:
		check(entry.near.mesh.get_surface_count()==1 and entry.far.mesh.get_surface_count()==1,"One surface per near/far mesh")
		check(entry.near.get_aabb().grow(0.01).encloses(entry.far.get_aabb()),"Proxy stays within original chunk bounds")
		var box: AABB = controller.global_transform*entry.bounds
		check(maxf(box.size.x,box.size.z)<501,"Chunks no longer than 500 metres")
		controller.force_lod=0
		camera.position=box.get_center()
		controller.update_visibility()
		check(entry.near.visible and not entry.far.visible,"Near camera shows only full detail")
		camera.position=Vector3(box.end.x+351,box.get_center().y,box.get_center().z)
		controller.update_visibility()
		check(entry.far.visible and not entry.near.visible,"Far camera shows only proxy at edge+350m")
		camera.position.x=box.end.x+325
		controller.update_visibility()
		check(entry.far.visible,"Hysteresis retains proxy at325m")
		camera.position.x=box.end.x+299
		controller.update_visibility()
		check(entry.near.visible and not entry.far.visible,"Full detail returns at300m")
	for mode in [1,2]:
		controller.force_lod=mode
		controller.update_visibility()
		for entry in controller.entries:
			check(entry.near.visible==(mode==1) and entry.far.visible==(mode==2),"Forced LOD shows exactly one representation")
		var waterfront = region.get_parent()
		waterfront.apply_night(1.0)
		controller.update_visibility()
		check(is_equal_approx(controller._material.get_shader_parameter("night_amount"),waterfront.night_light_brightness),"Baked lamp emission follows night")
		for light: Light3D in region.find_children("*","Light3D",true,false): check(light.is_visible_in_tree(),"Original night lighting stays active")
		waterfront.apply_night(0.0)
		controller.update_visibility()
		check(is_zero_approx(controller._material.get_shader_parameter("night_amount")),"Daytime emission turns off")
	for shape in collision:
		check([shape.disabled,shape.transform,shape.shape]==collision[shape],"Collision flags, transforms and resources unchanged")
	for node in harbor_state:
		if node is Light3D: continue # Clock owns light visibility.
		check([node.transform,node.visible]==harbor_state[node],"Harbor untouched")
	controller.enabled=false
	for mesh in authored: check(mesh.visible==authored[mesh],"Disable restores every authored visibility flag")
	for entry in controller.entries: check(not entry.node.visible,"Disabled controller hides baked meshes")
	controller.enabled=true
	controller.visible=false
	for entry in controller.entries: check(not entry.near.is_visible_in_tree() and not entry.far.is_visible_in_tree(),"Controller visibility hides chunk geometry")
	controller.visible=true
	check(not region.get_node("QuayWall").visible and not region.get_node("RiverbankRailings").visible,"Old hidden river walls/railings never resurrected")
	world.free()
	# Edited authoring data must fall back, without hiding the edited originals.
	var changed: Node3D = load("res://scenes/super_city.tscn").instantiate()
	var edited := changed.get_node("Waterfront/Riverbanks/HarborLamp") as Node3D
	edited.position.x += 3
	root.add_child(changed)
	for frame in 3: await process_frame
	var stale = changed.get_node("Waterfront/Riverbanks/RiverbankChunks")
	check(stale.prepared and not stale.valid_bake,"Edited source rejected as stale")
	check(edited.get_node("Post").visible,"Edited source remains visible")
	for entry in stale.entries: check(not entry.node.visible,"Stale replacement remains hidden")
	changed.free()
	camera.free()
	print("Riverbank chunks: ",failures," failures")
	quit(1 if failures else 0)

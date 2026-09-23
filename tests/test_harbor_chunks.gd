extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Harbor test timeout"); quit(1))
	paused = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled=false
	var harbor: Node3D = world.get_node("SuperCity/Waterfront/Harbor")
	var controller = harbor.get_node("HarborChunks")
	var authored := {}
	var collisions := {}
	var lights := {}
	var cargo_bounds := AABB()
	var first_cargo := true
	for node: Node3D in harbor.find_children("*","Node3D",true,false):
		if controller.is_ancestor_of(node): continue
		if node is MeshInstance3D or node is Label3D: authored[node] = node.visible
		if node is CollisionShape3D: collisions[node] = [node.transform,node.shape,node.disabled]
		if node is Light3D: lights[node] = [node.transform,node.distance_fade_enabled,node.distance_fade_begin,node.distance_fade_length]
		var path := str(harbor.get_path_to(node))
		if node is MeshInstance3D and (path.begins_with("Container") or path.begins_with("CargoCrate")):
			var box: AABB = controller.pose_in(node,harbor)*node.get_aabb()
			cargo_bounds = box if first_cargo else cargo_bounds.merge(box)
			first_cargo = false
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	for frame in 6: await process_frame
	controller.set_process(false)
	check(controller.prepared and controller.valid_bake,"Harbor bake validates against Main")
	check(controller.entries.size()==1 and controller.sources.size()==494,"All 494 source visuals replaced by one harbor chunk")
	var entry: Dictionary = controller.entries[0]
	var cargo: MeshInstance3D = entry.near.get_node("CargoCombined")
	var structures: MeshInstance3D = entry.near.get_node("StructuresCombined")
	check(cargo.mesh.get_surface_count()==1 and structures.mesh.get_surface_count()==1 and entry.far.mesh.get_surface_count()==1,"Cargo, structures and proxy each have one surface")
	check(cargo.get_aabb().position.distance_to(cargo_bounds.position)<0.01 and cargo.get_aabb().end.distance_to(cargo_bounds.end)<0.01,"Combined cargo retains exact footprint")
	check(cargo.mesh.get_faces().size()/3==4464,"All 36 cargo items retain original nearby detail")
	check((cargo.mesh.get_faces().size()+structures.mesh.get_faces().size())/3==7704,"Full-detail geometry preserved")
	check(entry.far.mesh.get_faces().size()/3==1296,"Distant geometry genuinely simplified")
	check(entry.bounds.grow(0.01).encloses(entry.far.get_aabb()),"Proxy bounds stay within authored harbor")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(controller.HARBOR_INVENTORY))
	check(info.near_triangles+info.label_triangle_upper_bound<=10000,"Complete high-detail harbor including text stays below 10k")
	for mode in [1,2]:
		controller.force_lod=mode
		controller.update_visibility()
		check(entry.near.visible==(mode==1) and entry.far.visible==(mode==2),"Exactly one detail representation active")
		for source in controller.sources: check(not source.visible,"No original mesh renders underneath chunks")
		for label in entry.labels: check(label.visible==(mode==1),"Text retained nearby and hidden at distance")
		var waterfront=harbor.get_parent()
		for amount in [0.0,1.0]:
			waterfront.apply_night(amount)
			controller.update_visibility()
			check(is_equal_approx(controller._material.get_shader_parameter("night_amount"),amount*waterfront.night_light_brightness),"Clock drives baked emission")
			for light in lights: check(light.visible==(amount>0.0),"Harbor lights retain day/night behavior")
	controller.force_lod=0
	var bounds: AABB = controller.global_transform*entry.bounds
	for sample in [[0.0,0],[351.0,1],[325.0,1],[299.0,0]]:
		camera.position=Vector3(bounds.end.x+sample[0],bounds.get_center().y,bounds.get_center().z)
		controller.update_visibility()
		check(entry.state==sample[1],"Nearest-bound switching and hysteresis")
	for shape in collisions: check([shape.transform,shape.shape,shape.disabled]==collisions[shape],"Original collision shape, transform and enabled state preserved")
	for light in lights: check([light.transform,light.distance_fade_enabled,light.distance_fade_begin,light.distance_fade_length]==lights[light],"Light placement and fades preserved")
	controller.visible=false
	controller.update_visibility()
	check(not cargo.is_visible_in_tree() and not entry.far.is_visible_in_tree(),"Controller visibility hides all replacement geometry")
	for label in entry.labels: check(not label.is_visible_in_tree(),"Controller visibility also hides labels")
	controller.visible=true
	controller.enabled=false
	for node in authored: check(node.visible==authored[node],"Disable restores authored visual flags")
	check(not entry.node.visible,"Disable removes replacements")
	# Upward/downward physics rays hit the original cargo despite its hidden mesh.
	await physics_frame
	var box_source: MeshInstance3D = harbor.get_node("CargoCrate")
	var center := box_source.global_position
	var query := PhysicsRayQueryParameters3D.create(center+Vector3.UP*10,center-Vector3.UP)
	var hit := box_source.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and box_source.is_ancestor_of(hit.collider),"Cargo collision remains reachable")
	controller.enabled=true
	controller.force_lod=2
	controller.update_visibility()
	await physics_frame
	var proxy_hit := box_source.get_world_3d().direct_space_state.intersect_ray(query)
	check(not proxy_hit.is_empty() and proxy_hit.collider==hit.get("collider"),"Distant replacement preserves the same physical cargo")
	world.free()
	var changed: Node3D = load("res://scenes/super_city.tscn").instantiate()
	changed.get_node("Waterfront/Harbor/Container").position.x+=2
	root.add_child(changed)
	for frame in 3: await process_frame
	var stale=changed.get_node("Waterfront/Harbor/HarborChunks")
	check(stale.prepared and not stale.valid_bake,"Edited cargo triggers fallback")
	check(changed.get_node("Waterfront/Harbor/Container").visible,"Edited cargo remains visible when stale")
	check(not stale.entries[0].node.visible,"Stale proxies remain hidden")
	changed.free()
	camera.free()
	print("Harbor chunks: ",failures," failures")
	quit(1 if failures else 0)

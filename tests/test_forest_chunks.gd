extends SceneTree
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Forest chunks test timed out"); quit(1))
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for name in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(name).free()
	root.add_child(city)
	await process_frame
	await process_frame
	var total_sources := 0
	var total_chunks := 0
	for path in ["CityLife/Highway/ForestChunks","CoastalRegion/ForestChunks"]:
		var controller = city.get_node(path)
		check(controller.prepared and controller.valid_bake,"Current authored trees match their bake: "+path)
		check(controller.entries.size()==controller.total_chunks,"Every chunk prepared")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(controller.inventory_path))
		check(manifest.near_triangles==manifest.source_triangles,"Full-detail chunk geometry retains triangle count")
		check(manifest.proxy_triangles<manifest.source_triangles*0.3,"Distant proxies substantially simplify geometry")
		var seen := {}
		controller.force_lod = 1
		controller.update_visibility()
		for entry: Dictionary in controller.entries:
			check(entry.near.mesh.get_surface_count()==1 and entry.far.mesh.get_surface_count()==1,"One surface per LOD mesh")
			check(entry.near.is_visible_in_tree() and not entry.far.is_visible_in_tree(),"Only full-detail chunk draws when forced near")
			check(entry.node.find_children("*","CollisionObject3D",true,false).is_empty(),"Batching adds no tree collisions")
			for source in entry.sources:
				check(not source.visible,"Individual source renderer is replaced")
				check(not seen.has(source.get_instance_id()),"Tree assigned exactly once")
				seen[source.get_instance_id()] = true
			var near_bounds: AABB = entry.near.mesh.get_aabb()
			var far_bounds: AABB = entry.far.mesh.get_aabb()
			var chunk_bounds: AABB = entry.bounds
			chunk_bounds.position -= entry.node.position
			check(chunk_bounds.grow(0.01).encloses(near_bounds) and chunk_bounds.grow(0.01).encloses(far_bounds),"Both LODs fit the authored chunk bounds used for switching")
		check(seen.size()==int(manifest.tree_count),"All regional trees assigned")
		total_sources += seen.size()
		total_chunks += controller.entries.size()
		controller.force_lod = 2
		controller.update_visibility()
		for entry: Dictionary in controller.entries:
			check(entry.far.is_visible_in_tree() and not entry.near.is_visible_in_tree(),"Only simplified chunk draws when forced distant")
		controller.hide()
		for entry: Dictionary in controller.entries:
			check(not entry.far.is_visible_in_tree(),"Hiding ForestChunks hides the regional forest")
		controller.show()
		controller.enabled = false
		for entry: Dictionary in controller.entries:
			check(not entry.node.visible,"Disabling batching hides both replacement meshes")
			for i in entry.sources.size(): check(entry.sources[i].visible==entry.flags[i],"Disabling restores authored visibility")
		controller.enabled = true
		controller.force_lod = 0
		var entry: Dictionary = controller.entries[0]
		var box: AABB = controller.get_parent().global_transform * entry.bounds
		camera.position = box.get_center()
		controller.update_visibility()
		check(entry.state==0,"Inside chunk always uses full detail")
		camera.position = Vector3(box.end.x+349,box.get_center().y,box.get_center().z)
		controller.update_visibility()
		check(entry.state==0,"Full detail stays until 350 m from nearest edge")
		camera.position.x = box.end.x+351
		controller.update_visibility()
		check(entry.state==1,"Distant proxy activates past nearest-edge threshold")
		camera.position.x = box.end.x+325
		controller.update_visibility()
		check(entry.state==1,"Hysteresis prevents boundary flicker")
		camera.position.x = box.end.x+299
		controller.update_visibility()
		check(entry.state==0,"Full detail returns within 300 m")
		controller.max_distance_m = 500
		camera.position.x = box.end.x+501
		controller.update_visibility()
		check(entry.state==2 and not entry.node.visible,"Optional maximum range culls the chunk")
		controller.max_distance_m = 0
		controller.enabled = false
		camera.position = Vector3.ZERO
	city.free()
	# A changed placement must not render a stale baked copy at the old position.
	var region: Node3D = load("res://scenes/coastal_region.tscn").instantiate()
	var changed: Node3D = TREES.trees(region)[0]
	changed.position.x += 10
	root.add_child(region)
	await process_frame
	var controller = region.get_node("ForestChunks")
	check(controller.prepared and not controller.valid_bake,"Changed tree triggers safe original-tree fallback")
	check(changed.visible,"Changed tree remains visible in fallback")
	for entry: Dictionary in controller.entries: check(not entry.node.visible,"Stale chunk is not rendered")
	region.free()
	camera.free()
	print("Forest chunks: %d trees, %d chunks, %d failures"%[total_sources,total_chunks,failures])
	quit(1 if failures else 0)

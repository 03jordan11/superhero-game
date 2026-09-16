extends SceneTree
const BASE := "res://assets/buildings/gas_station_hideout/"
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run() -> void:
	var world := Node3D.new(); root.add_child(world); current_scene = world
	var station := (load(BASE + "gas_station_hideout.tscn") as PackedScene).instantiate()
	world.add_child(station)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	var triangles := 0
	var surfaces := 0
	var by_part := {}
	for part: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false):
		var count := 0
		for surface in part.mesh.get_surface_count():
			var indices: int = part.mesh.surface_get_array_index_len(surface)
			count += int((indices if indices > 0 else part.mesh.surface_get_array_len(surface)) / 3)
			surfaces += 1
			var material := part.get_active_material(surface) as StandardMaterial3D
			check(material != null and material.albedo_texture != null, "Textured material imports: " + part.name)
			if material != null:
				check(material.roughness_texture != null, "Roughness map imports")
			check(part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV].size() > 0, "UVs import")
		by_part[part.name] = count
		triangles += count
	check(triangles < 5000, "Complete placed scene is below 5,000 triangles")
	check(triangles == int(manifest.exported_triangles), "Imported geometry agrees with exported GLB audit")
	check(station.has_node("Entry") and station.has_node("RearEntry"), "Future interior entrance markers are available")
	check(station.find_children("*","Camera3D",true,false).is_empty(), "Placeable asset contains no preview camera")
	check(station.find_children("*","Light3D",true,false).is_empty(), "Placeable asset contains no studio lights")
	await physics_frame; await physics_frame
	var space := world.get_world_3d().direct_space_state
	for entry in [[Vector3(3,20,-4),4.44],[Vector3(-6.6,20,-3.2),4.33],[Vector3(12,20,10),0.12],[Vector3(-3.95,5,7.70),2.365]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(entry[0],entry[0]+Vector3.DOWN*30,1))
		check(not hit.is_empty(), "Roof, forecourt, and pumps have solid collision")
		if not hit.is_empty(): check(absf(hit.position.y - float(entry[1])) < 0.05, "Collision height follows visible geometry")
	var report := {"triangles":triangles,"surfaces":surfaces,"by_part":by_part,"limit_exclusive":5000,"failures":failures}
	var file := FileAccess.open(BASE + "triangle_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	if "--render" in OS.get_cmdline_user_args(): await render_views()
	print("GAS_STATION_PASS ",JSON.stringify(report))
	world.free(); quit(1 if failures else 0)

func render_views() -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(1500,1100); viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := (load(BASE + "gas_station_preview.tscn") as PackedScene).instantiate()
	viewport.add_child(preview)
	var camera: Camera3D = preview.get_node("Camera3D")
	for view in [["front",Vector3(29,19,34),Vector3(0,2,0),35.0],["entrance",Vector3(-17,7,21),Vector3(-5,2,4),17.0],["rear",Vector3(-28,18,-31),Vector3(0,2,0),34.0]]:
		camera.position = view[1]; camera.look_at(view[2]); camera.size = view[3]
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/gas_station_hideout/godot_" + view[0] + ".png")
	viewport.free()

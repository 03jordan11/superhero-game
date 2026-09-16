extends SceneTree
## Checks the actual Godot import. Optional -- --render makes an isolated art preview.
const BASE := "res://assets/props/power_machine/"
var failures := 0

func _initialize() -> void:
	validate.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func validate() -> void:
	var packed := load(BASE + "power_machine.glb") as PackedScene
	if packed == null:
		push_error("Power machine GLB did not import")
		quit(1)
		return
	var instance := packed.instantiate() as Node3D
	root.add_child(instance)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	var triangles := 0
	var surfaces := 0
	var transparent := 0
	var emissive := 0
	for part: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			surfaces += 1
			var indices: int = part.mesh.surface_get_array_index_len(surface)
			triangles += int((indices if indices > 0 else part.mesh.surface_get_array_len(surface)) / 3)
			var mat := part.get_active_material(surface) as StandardMaterial3D
			check(mat != null, "Standard imported material exists")
			check(part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV].size() > 0, "UVs exist")
			if mat == null:
				continue
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				transparent += 1
			else:
				check(mat.albedo_texture != null, "Painted albedo imports")
				check(mat.roughness_texture != null, "Roughness imports")
				check(mat.emission_enabled and mat.emission_texture != null, "Cyan emission imports")
				if mat.emission_enabled and mat.emission_texture != null:
					emissive += 1
	check(triangles == int(manifest.exported_triangles), "Imported triangles equal exported triangles")
	check(triangles + 4486 <= 10000, "One machine fits the documented combined station POI budget")
	check(surfaces == 2 and transparent == 1 and emissive == 1, "Opaque emissive surface plus glass surface")
	check(instance.find_children("*", "Camera3D", true, false).is_empty(), "No studio cameras in mesh")
	check(instance.find_children("*", "Light3D", true, false).is_empty(), "No studio lights in mesh")
	var report := {"imported_triangles":triangles, "surfaces":surfaces, "transparent_surfaces":transparent,
		"emissive_surfaces":emissive, "station_plus_one_machine_triangles":4486 + triangles, "failures":failures}
	var file := FileAccess.open(BASE + "triangle_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	if "--render" in OS.get_cmdline_user_args():
		await render_preview(packed)
	print("POWER_MACHINE_VALIDATION ", JSON.stringify(report))
	instance.free()
	quit(1 if failures else 0)

func render_preview(packed: PackedScene) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1024)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	world.add_child(packed.instantiate())
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.075, 0.09, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.8, 0.9)
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 1.3
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4.2, 3.65, 6.4)
	camera.look_at(Vector3(0, 1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.9
	camera.current = true
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/power_machine/power_machine_godot.png")
	viewport.free()

extends SceneTree
## Render/animation comparison, not a whole-city gameplay benchmark.
## --script benchmarks/civilian_models.gd -- --variant=before (or after)
const OUTPUT := "res://artifacts/civilian_mesh_benchmark/"
const WARMUP_SECONDS := 3.0
const SAMPLE_SECONDS := 8.0
var variant := "after"
var viewport: SubViewport
var stage: Node3D
var actors: Node3D
var results: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
	assert(variant in ["before", "after"])
	assert(DisplayServer.get_name() != "headless", "Benchmark requires a real renderer")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920, 1080)
	root.disable_3d = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.scaling_3d_scale = 1.0
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8b98a5")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	# Override any user preference applied by the GameSettings node-added hook.
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	viewport.positional_shadow_atlas_size = 4096
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 60)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("666b71")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 18, 30)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.fov = 50
	actors = Node3D.new()
	stage.add_child(actors)
	var path := "res://tests/fixtures/civilian_legacy_benchmark.tscn" if variant == "before" else "res://scenes/npcs/civilian.tscn"
	var packed: PackedScene = load(path)
	for count in [40, 100]:
		for child in actors.get_children(): child.free()
		seed(492)
		CharacterHair._random.seed = 492
		CharacterHair._random_initialized = true
		var triangle_total := 0
		var surfaces := 0
		for index in count:
			var npc = packed.instantiate()
			npc.position = Vector3((index % 10 - 4.5) * 2.2, 0, (index / 10 - (count / 10 - 1) * 0.5) * 2.4)
			npc.hair_style_index = index % 3
			npc.hair_color_index = index % 4
			actors.add_child(npc)
			# Fixed placement isolates animation/skinning/rendering and guarantees
			# identical population/visibility. Gameplay AI/physics are excluded.
			npc.set_physics_process(false)
			npc.health_label.hide()
			var animation: AnimationPlayer = npc.animation_controller.animation_player
			animation.play("Walk")
			animation.seek(float(index % 17) / 17.0 * animation.get_animation("Walk").length, true)
			for instance: MeshInstance3D in npc.find_children("*", "MeshInstance3D", true, false):
				for surface in instance.mesh.get_surface_count():
					var arrays := instance.mesh.surface_get_arrays(surface)
					triangle_total += arrays[Mesh.ARRAY_INDEX].size() / 3 if not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size() / 3
					surfaces += 1
		# First population gets additional shader/resource warmup.
		await wait_seconds(5.0)
		for trial in 3:
			await wait_seconds(WARMUP_SECONDS)
			var samples: Array[float] = []
			var gpu: Array[float] = []
			var render_cpu: Array[float] = []
			var draw_calls: Array[float] = []
			var primitives: Array[float] = []
			var begin := Time.get_ticks_usec()
			var previous := begin
			while Time.get_ticks_usec() - begin < SAMPLE_SECONDS * 1000000:
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append((now - previous) / 1000.0)
				previous = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
				render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
				draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var row := {"variant": variant, "civilians": count, "trial": trial + 1,
				"samples": samples.size(), "mean_frame_ms": mean(samples), "p95_frame_ms": percentile(samples, 0.95),
				"fps": 1000.0 / mean(samples), "gpu_ms": mean(gpu), "render_cpu_ms": mean(render_cpu),
				"draw_calls": mean(draw_calls), "rendered_primitives": mean(primitives),
				"highest_detail_triangles": triangle_total, "mesh_surfaces": surfaces,
				"render_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0}
			results.append(row)
			print("CIVILIAN_BENCHMARK: ", JSON.stringify(row))
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUTPUT + variant + "_" + str(count) + ".png")
	var report := {"variant": variant, "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(), "resolution": "1920x1080", "vsync": false,
		"warmup_seconds_per_trial": WARMUP_SECONDS, "sample_seconds_per_trial": SAMPLE_SECONDS,
		"scope": "Fixed fully animated civilian population, real scene/controller, walking loop, shadows, no AI/physics/city/LOD transitions. Default imported mesh LODs retained.",
		"results": results}
	FileAccess.open(OUTPUT + variant + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	quit()

func wait_seconds(seconds: float) -> void:
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < seconds * 1000000: await process_frame

func mean(values: Array[float]) -> float:
	var sum := 0.0
	for value in values: sum += value
	return sum / maxi(values.size(), 1)

func percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * fraction), sorted.size() - 1)]

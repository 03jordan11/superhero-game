extends Node
## Engine-wide metrics provide context, not exclusive attribution to the city.
## Only route-network CPU timings below are scoped to the city subtree.
@export var enabled: bool = true
@export_range(1.0, 30.0, 1.0) var sample_interval: float = 5.0
@export var target_path: NodePath = ^"../../SuperCity"

static var _active: Node
var _samples: Dictionary = {}
var _last_usec: int = 0
var _last_tick: int = 0
var _last_frame: int = 0
var _target: Node
var _frame_usec := 0
var _frame_ms: Array[float] = []
var _gpu_ms: Array[float] = []
var _render_cpu_ms: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _pipeline_ids: Dictionary = {}
var _previous_pipelines: Dictionary = {}
var _city_lights: Array[Node] = []
var _report_path := ""


static func begin(source: Node) -> int:
	if not is_instance_valid(_active) or not _active.enabled:
		return 0
	var target: Node = _active._target
	if not is_instance_valid(target) or (source != target and not target.is_ancestor_of(source)):
		return 0
	return Time.get_ticks_usec()


static func finish(category: StringName, started: int, failed: bool = false) -> void:
	if started == 0 or not is_instance_valid(_active) or not _active.enabled:
		return
	var elapsed := Time.get_ticks_usec() - started
	var samples: Dictionary = _active._samples
	if not samples.has(category):
		samples[category] = {"calls": 0, "usec": 0, "peak_usec": 0, "failures": 0}
	var bucket: Dictionary = samples[category]
	bucket.calls += 1
	bucket.usec += elapsed
	bucket.peak_usec = maxi(bucket.peak_usec, elapsed)
	if failed: bucket.failures += 1


func _ready() -> void:
	set_process(OS.is_debug_build())
	if OS.is_debug_build():
		_active = self
		_target = get_node_or_null(target_path)
		for key in ClassDB.class_get_integer_constant_list("RenderingServer"):
			if key.begins_with("RENDERING_INFO_PIPELINE_COMPILATIONS_"):
				_pipeline_ids[key] = ClassDB.class_get_integer_constant("RenderingServer", key)
		_prepare_capture.call_deferred()
	_reset_window()

func _prepare_capture() -> void:
	if is_instance_valid(_target):
		_city_lights = _target.find_children("*", "Light3D", true, false)
	var directory := "res://artifacts/live_performance"
	if DirAccess.make_dir_recursive_absolute(directory) == OK:
		_report_path = directory.path_join("city_%d.jsonl" % OS.get_process_id())
		print("[CityPerf] Report: ", ProjectSettings.globalize_path(_report_path))
	else:
		push_warning("CityPerf report directory unavailable; samples remain in Godot Output.")


func _exit_tree() -> void:
	if _active == self: _active = null
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), get_node("/root/DebugManager").show_performance_hud)

func _notification(what: int) -> void:
	# Do not count time spent in the console/settings as a gameplay hitch.
	if what == NOTIFICATION_UNPAUSED: _frame_usec = 0


func _reset_window() -> void:
	_samples.clear()
	_last_usec = Time.get_ticks_usec()
	_last_tick = Engine.get_physics_frames()
	_last_frame = Engine.get_process_frames()
	_frame_usec = 0
	_frame_ms.clear()
	_gpu_ms.clear()
	_render_cpu_ms.clear()
	_process_ms.clear()
	_physics_ms.clear()
	_previous_pipelines = _pipeline_counts()

func _pipeline_counts() -> Dictionary:
	var counts := {}
	for key in _pipeline_ids:
		counts[key] = RenderingServer.get_rendering_info(_pipeline_ids[key])
	return counts

func _summary(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"samples": 0, "available": false}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted: total += value
	return {"samples": sorted.size(), "available": true, "mean_ms": total / sorted.size(),
		"p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "worst_ms": sorted[-1]}

func _capture_frame() -> void:
	var rid := get_viewport().get_viewport_rid()
	# The independently toggled HUD also controls this flag; keep it enabled
	# while this debug capture is active, even when the HUD is hidden.
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var now := Time.get_ticks_usec()
	if _frame_usec != 0:
		_frame_ms.append((now - _frame_usec) / 1000.0)
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if gpu > 0.0: _gpu_ms.append(gpu)
		_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
		_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_frame_usec = now


func _take_timings() -> Dictionary:
	var timings: Dictionary = {}
	var ticks := maxi(1, Engine.get_physics_frames() - _last_tick)
	for category in _samples:
		var bucket: Dictionary = _samples[category]
		timings[category] = {
			"calls": bucket.calls, "failures": bucket.failures,
			"avg_call_ms": snappedf(bucket.usec / (1000.0 * bucket.calls), 0.0001),
			"peak_call_ms": bucket.peak_usec / 1000.0,
			"ms_per_tick": snappedf(bucket.usec / (1000.0 * ticks), 0.0001),
		}
	return timings


func _process(_delta: float) -> void:
	if not enabled:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), get_node("/root/DebugManager").show_performance_hud)
		_reset_window()
		return
	_capture_frame()
	if Time.get_ticks_usec() - _last_usec >= maxf(sample_interval, 1.0) * 1000000.0:
		var line := JSON.stringify(collect_sample())
		print("[CityPerf] ", line)
		if not _report_path.is_empty():
			var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_report_path) else FileAccess.WRITE
			var file := FileAccess.open(_report_path, mode)
			if file != null:
				file.seek_end()
				file.store_line(line)
				file.close()
			else:
				push_warning("CityPerf could not write report; use Godot Output instead.")
				_report_path = ""


func collect_sample() -> Dictionary:
	var frames := maxi(1, Engine.get_process_frames() - _last_frame)
	var data := {
		"frame_time": _summary(_frame_ms), "gpu_time": _summary(_gpu_ms),
		"render_cpu_time": _summary(_render_cpu_ms), "process_time": _summary(_process_ms),
		"physics_tick_time": _summary(_physics_ms),
		"uptime_s": snappedf(Time.get_ticks_usec() / 1000000.0, 0.1),
		"window_s": (Time.get_ticks_usec() - _last_usec) / 1000000.0,
		"city_present": is_instance_valid(_target),
		"city_cpu_timings": _take_timings(), "timings_overlap": true,
		"engine": {
			"fps": Engine.get_frames_per_second(),
			"physics_ticks_per_render_frame": float(Engine.get_physics_frames() - _last_tick) / frames,
			"physics_ms_latest": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"static_memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			"render_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			"nodes": get_tree().get_node_count(),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		},
	}
	var pipelines := _pipeline_counts()
	data["pipeline_compilations_in_window"] = {}
	for key in pipelines:
		data.pipeline_compilations_in_window[key] = pipelines[key] - int(_previous_pipelines.get(key, pipelines[key]))
	var settings := get_node("/root/GameSettings")
	data["render_context"] = {"gpu": RenderingServer.get_video_adapter_name(),
		"viewport": str(get_viewport().get_visible_rect().size), "render_scale": get_viewport().scaling_3d_scale,
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"shadow_quality": settings.shadow_quality, "bloom": settings.bloom_enabled,
		"crowd_density": settings.crowd_density, "vehicle_density": settings.vehicle_density}
	var lights := {"visible_local": 0, "visible_shadowed_local": 0, "streetlamps": 0, "frontages": 0}
	for light in _city_lights:
		if not is_instance_valid(light) or light is DirectionalLight3D: continue
		if not light.is_visible_in_tree() or light.light_energy <= 0: continue
		lights.visible_local += 1
		if light.shadow_enabled: lights.visible_shadowed_local += 1
		if str(light.name).begins_with("PavementLight"): lights.streetlamps += 1
		if str(light.name).begins_with("FrontageLight"): lights.frontages += 1
	# Scene visibility is not a GPU-visible light count (frustum/distance culling differs).
	data["city_light_nodes"] = lights
	data["window_brightness"] = get_node("/root/CityWindows").brightness
	var clock := get_tree().get_first_node_in_group(&"game_clock")
	if clock != null: data["time_of_day"] = clock.time_of_day
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		data["camera_position"] = str(camera.global_position)
		data["camera_rotation"] = str(camera.global_rotation)
	if is_instance_valid(_target):
		var network := _target.get_node_or_null("CityPedestrianRoutes")
		if network != null:
			data["routes"] = {
				"valid": network.valid, "points": network.astar.get_point_count(),
				"directed_edges": network.edge_types.size(),
				"walkable_surfaces": network.walkable_surfaces.size(),
			}
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player != null:
			data["player_position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	_reset_window()
	return data

extends CanvasLayer
const PLAYER_PERF = preload("res://scripts/ui-scripts/player_performance_monitor.gd")
const PERFORMANCE_SAMPLE_WINDOW_SECONDS := 1.0
const PERFORMANCE_REFRESH_INTERVAL_SECONDS := 0.25
@onready var performance_label: Label = $Panel/MarginContainer/PerformanceLabel
@onready var _crowd: Node = get_node_or_null("../SuperCity/CivilianCrowd")
var frame_time_samples: Array[float] = []
var sampled_frame_time := 0.0
var performance_refresh_elapsed := 0.0
var render_time_samples: Array[Vector2] = []
var sampled_render_time := Vector2.ZERO
var _last_frame_usec := 0
var _measuring_render_time := false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	DebugManager.performance_hud_visibility_changed.connect(_set_enabled)
	performance_label.tooltip_text = "Frame and render timings cover the last second. Lower milliseconds are better.\nCPU render excludes gameplay scripts; physics is time per physics tick. These overlap: do not add them together.\nGPU -- means timing is unavailable or warming up. Render memory is Godot's reported GPU allocation."
	_set_enabled(DebugManager.show_performance_hud)

func _set_enabled(value: bool) -> void:
	visible = value
	set_process(value)
	_measuring_render_time = value
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), value)
	if value:
		_reset_performance_samples()
		_update_performance_label()

func _process(_delta: float) -> void:
	# Wall time includes stalls and is unaffected by slow motion or delta clamping.
	var now := Time.get_ticks_usec()
	var frame_seconds := (now - _last_frame_usec) / 1000000.0
	_add_frame_time_sample(frame_seconds)
	_last_frame_usec = now
	performance_refresh_elapsed += frame_seconds
	if performance_refresh_elapsed >= PERFORMANCE_REFRESH_INTERVAL_SECONDS:
		performance_refresh_elapsed = 0.0
		_update_performance_label()

func _add_frame_time_sample(delta: float) -> void:
	frame_time_samples.append(delta)
	var viewport_rid := get_viewport().get_viewport_rid()
	var render_times := Vector2(
		RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	)
	render_time_samples.append(render_times)
	sampled_render_time += render_times
	sampled_frame_time += delta
	while (
		sampled_frame_time > PERFORMANCE_SAMPLE_WINDOW_SECONDS
		and frame_time_samples.size() > 1
	):
		sampled_frame_time -= frame_time_samples.pop_front()
		sampled_render_time -= render_time_samples.pop_front()


func _reset_performance_samples() -> void:
	frame_time_samples.clear()
	render_time_samples.clear()
	sampled_render_time = Vector2.ZERO
	sampled_frame_time = 0.0
	performance_refresh_elapsed = 0.0
	_last_frame_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	if _measuring_render_time:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)


func _update_performance_label() -> void:
	var perf_started := PLAYER_PERF.begin(self)
	_profiled_update_performance_label()
	PLAYER_PERF.finish(&"performance_hud", perf_started)


func _profiled_update_performance_label() -> void:
	var average_frame_time_ms: float = 0.0
	var worst_frame_time_ms: float = 0.0
	var p95_frame_time_ms := 0.0
	var render_times := Vector2.ZERO
	if not frame_time_samples.is_empty():
		average_frame_time_ms = (
			sampled_frame_time / float(frame_time_samples.size())
		) * 1000.0
		for frame_time in frame_time_samples:
			worst_frame_time_ms = maxf(worst_frame_time_ms, frame_time * 1000.0)
		var sorted_samples := frame_time_samples.duplicate()
		sorted_samples.sort()
		p95_frame_time_ms = sorted_samples[maxi(0, ceili(sorted_samples.size() * 0.95) - 1)] * 1000.0
		render_times = sampled_render_time / frame_time_samples.size()

	var civilian_count := get_tree().get_nodes_in_group(&"civilian").size()
	var distant_civilians := 0
	if is_instance_valid(_crowd) and _crowd._lod != null:
		distant_civilians = _crowd._lod.capsule_count

	var draw_calls: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	var distant_vehicles := 0
	for manager in get_tree().get_nodes_in_group(&"traffic_managers"):
		if manager._lod != null: distant_vehicles += manager._lod.proxies.size()
	var gpu_text := "%.2f ms" % render_times.y if render_times.y > 0.0 else "--"
	performance_label.text = (
		"Performance  |  60 FPS budget: 16.67 ms\n"
		+ "FPS: %d | Frame: %.2f ms avg\n" % [
			roundi(Engine.get_frames_per_second()),
			average_frame_time_ms
		]
		+ "95%% of frames: %.2f ms or less | Worst: %.2f ms\n" % [p95_frame_time_ms, worst_frame_time_ms]
		+ "CPU render: %.2f ms | GPU: %s\n" % [render_times.x, gpu_text]
		+ "Physics tick: %.2f ms\n" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
		+ "Draw calls: %d | Scene nodes: %d\n" % [
			draw_calls,
			get_tree().get_node_count()
		]
		+ "Render memory: %.0f MiB\n" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
		+ "Civilians: %d full + %d distant\n" % [civilian_count, distant_civilians]
		+ "Vehicles: %d full + %d distant" % [
			get_tree().get_nodes_in_group(&"explodable").size(),
			distant_vehicles
		]
	)

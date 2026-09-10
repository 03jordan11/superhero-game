extends CanvasLayer
const PLAYER_PERF = preload("res://scripts/ui-scripts/player_performance_monitor.gd")
const PERFORMANCE_SAMPLE_WINDOW_SECONDS := 1.0
const PERFORMANCE_REFRESH_INTERVAL_SECONDS := 0.25
@onready var performance_label: Label = $Panel/MarginContainer/PerformanceLabel
var frame_time_samples: Array[float] = []
var sampled_frame_time := 0.0
var performance_refresh_elapsed := 0.0

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	DebugManager.performance_hud_visibility_changed.connect(_set_enabled)
	_set_enabled(DebugManager.show_performance_hud)

func _set_enabled(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		_reset_performance_samples()
		_update_performance_label()

func _process(delta: float) -> void:
	_add_frame_time_sample(delta)
	performance_refresh_elapsed += delta
	if performance_refresh_elapsed >= PERFORMANCE_REFRESH_INTERVAL_SECONDS:
		performance_refresh_elapsed = 0.0
		_update_performance_label()

func _add_frame_time_sample(delta: float) -> void:
	frame_time_samples.append(delta)
	sampled_frame_time += delta
	while (
		sampled_frame_time > PERFORMANCE_SAMPLE_WINDOW_SECONDS
		and frame_time_samples.size() > 1
	):
		sampled_frame_time -= frame_time_samples.pop_front()


func _reset_performance_samples() -> void:
	frame_time_samples.clear()
	sampled_frame_time = 0.0
	performance_refresh_elapsed = 0.0


func _update_performance_label() -> void:
	var perf_started := PLAYER_PERF.begin(self)
	_profiled_update_performance_label()
	PLAYER_PERF.finish(&"performance_hud", perf_started)


func _profiled_update_performance_label() -> void:
	var average_frame_time_ms: float = 0.0
	var worst_frame_time_ms: float = 0.0
	if not frame_time_samples.is_empty():
		average_frame_time_ms = (
			sampled_frame_time / float(frame_time_samples.size())
		) * 1000.0
		for frame_time in frame_time_samples:
			worst_frame_time_ms = maxf(worst_frame_time_ms, frame_time * 1000.0)

	var civilian_count: int = 0
	var moving_civilian_count: int = 0
	for civilian in get_tree().get_nodes_in_group(&"civilian"):
		civilian_count += 1
		if civilian is CharacterBody3D:
			var civilian_body: CharacterBody3D = civilian as CharacterBody3D
			if Vector2(civilian_body.velocity.x, civilian_body.velocity.z).length() > 0.1:
				moving_civilian_count += 1

	var draw_calls: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	performance_label.text = (
		"Performance\n"
		+ "FPS: %d | Frame: %.2f ms avg | %.2f ms worst\n" % [
			roundi(Engine.get_frames_per_second()),
			average_frame_time_ms,
			worst_frame_time_ms
		]
		+ "Draw calls: %d | Scene nodes: %d\n" % [
			draw_calls,
			get_tree().get_node_count()
		]
		+ "Civilians: %d (%d moving) | Vehicles: %d" % [
			civilian_count,
			moving_civilian_count,
			get_tree().get_nodes_in_group(&"explodable").size()
		]
	)

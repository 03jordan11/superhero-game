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
	_reset_window()


func _exit_tree() -> void:
	if _active == self: _active = null


func _reset_window() -> void:
	_samples.clear()
	_last_usec = Time.get_ticks_usec()
	_last_tick = Engine.get_physics_frames()
	_last_frame = Engine.get_process_frames()


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
		_reset_window()
		return
	if Time.get_ticks_usec() - _last_usec >= maxf(sample_interval, 1.0) * 1000000.0:
		print("[CityPerf] ", JSON.stringify(collect_sample()))


func collect_sample() -> Dictionary:
	var frames := maxi(1, Engine.get_process_frames() - _last_frame)
	var data := {
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

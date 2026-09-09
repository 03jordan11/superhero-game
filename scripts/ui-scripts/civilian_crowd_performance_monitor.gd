extends Node
## Bounded debug samples. Nested CPU timings overlap; do not sum them.
@export var enabled: bool = true
@export_range(1.0, 30.0, 1.0) var sample_interval: float = 5.0
@export var target_path: NodePath = ^"../../SuperCity/CivilianCrowd"

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
		print("[CrowdPerf] ", JSON.stringify(collect_sample()))


func collect_sample() -> Dictionary:
	var data := {
		"uptime_s": snappedf(Time.get_ticks_usec() / 1000000.0, 0.1),
		"window_s": (Time.get_ticks_usec() - _last_usec) / 1000000.0,
		"fps": Engine.get_frames_per_second(),
		"present": is_instance_valid(_target),
		"timings_overlap": true, "cpu_timings": _take_timings(),
	}
	if is_instance_valid(_target) and _target.is_node_ready():
		var statuses: Dictionary = {}
		var full := 0
		var capsules := 0
		var dead := 0
		var following := 0
		var pending_damage := 0
		var recoveries := 0
		for walker in _target._active.get_children():
			if walker.spacing_speed_limit < walker.walk_speed: following += 1
			if walker.is_lightweight:
				capsules += 1
				pending_damage += walker.pending_damage.size()
			else:
				full += 1
				if walker.is_dead: dead += 1
				recoveries += walker.stuck_recoveries
				var status: String = walker.route_status
				statuses[status] = int(statuses.get(status, 0)) + 1
		data.merge({
			"crowd_enabled": _target.crowd_enabled,
			"target": _target.current_target, "full": full, "capsules": capsules,
			"dead": dead, "following": following, "pending_damage": pending_damage,
			"live_walker_recoveries": recoveries, "route_statuses": statuses,
			"retiring": _target._retiring.size(),
			"rejected_spawns_total": _target.rejected_spawns,
			"promotions_total": _target._lod.promotions,
			"demotions_total": _target._lod.demotions,
			"blocked_promotions_total": _target._lod.blocked_promotions,
		})
	_reset_window()
	return data

extends Node
## Vehicle callbacks and state only; GPU and physics-server costs are not per-car timings.
@export var enabled: bool = true
@export_range(1.0, 30.0, 1.0) var sample_interval: float = 5.0
static var _active: Node
var _samples: Dictionary = {}
var _last_usec: int = 0
var _last_tick: int = 0
var _last_frame: int = 0


static func begin(source: Node) -> int:
	if not is_instance_valid(_active) or not _active.enabled:
		return 0
	if not is_instance_valid(source):
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
		print("[VehiclePerf] ", JSON.stringify(collect_sample()))


func collect_sample() -> Dictionary:
	var frozen := 0
	var sleeping := 0
	var active := 0
	var carried := 0
	var armed := 0
	var contact_monitors := 0
	var visible_labels := 0
	var moving := 0
	var total := 0
	# Vehicle scripts identify themselves through their existing thrown-impact API.
	# Group lookup includes cars reparented under the player while carried.
	for vehicle in get_tree().get_nodes_in_group(&"explodable"):
		if not vehicle is RigidBody3D or not vehicle.has_method("arm_thrown_impact"): continue
		total += 1
		if vehicle.freeze: frozen += 1
		elif vehicle.sleeping: sleeping += 1
		else: active += 1
		if vehicle.get_parent().is_in_group(&"player"): carried += 1
		if vehicle.is_thrown_impact_armed: armed += 1
		if vehicle.contact_monitor: contact_monitors += 1
		if vehicle.linear_velocity.length_squared() > 0.01 or vehicle.traffic_speed > 0.1: moving += 1
		if is_instance_valid(vehicle.health_label) and vehicle.health_label.is_visible_in_tree(): visible_labels += 1
	var data := {
		"uptime_s": snappedf(Time.get_ticks_usec() / 1000000.0, 0.1),
		"window_s": (Time.get_ticks_usec() - _last_usec) / 1000000.0,
		"fps": Engine.get_frames_per_second(),
		"vehicles": total, "frozen": frozen, "sleeping_unfrozen": sleeping,
		"awake_unfrozen": active, "carried": carried, "moving": moving,
		"armed_for_impact": armed, "contact_monitors": contact_monitors,
		"visible_health_labels": visible_labels,
		"explosion_effects": get_tree().get_nodes_in_group(&"debug_explosion_effects").size(),
		"cpu_timings": _take_timings(), "timings_overlap": true,
	}
	var traffic: Array = []
	for manager in get_tree().get_nodes_in_group(&"traffic_managers"):
		traffic.append({"active":manager.active_count,"retained":manager.retained_count,
			"stopped":manager.stopped_count,"at_junction":manager.at_junction_count,"lanes":manager.lanes.size(),
			"crossings_completed":manager.crossings_completed,"occupied_junctions":manager._junction_owners.size(),
			"abandoned_cleaned":manager.abandoned_cleaned_count})
		if manager._lod != null:
			traffic[-1].merge({"boxes":manager._lod.proxies.size(),"box_regions":manager._lod._batches.size(),
				"box_promotions":manager._lod.promotions,"box_demotions":manager._lod.demotions,
				"blocked_box_promotions":manager._lod.blocked_promotions,"hidden_nearby_boxes":manager._lod.hidden_count})
			traffic[-1].merge({"silhouettes":manager._lod.silhouette_count,"rectangles":manager._lod.rectangle_count,
				"rectangle_to_silhouette":manager._lod.flat_promotions,"silhouette_to_rectangle":manager._lod.flat_demotions})
	data["traffic"] = traffic
	_reset_window()
	return data

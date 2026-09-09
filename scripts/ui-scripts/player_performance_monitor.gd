extends Node
## Debug CPU timings. Nested categories overlap: do not add them together.
## HUD timings measure script/property updates, not layout, draw calls or GPU work.

@export var enabled: bool = true
@export_range(1.0, 30.0, 1.0) var sample_interval: float = 5.0
@export var player_path: NodePath = ^"../../Player"
@export var hud_paths: Array[NodePath] = [
	^"../../Player/ChargeUI", ^"../../PerformanceHUD",
	^"../../DeveloperMenu", ^"../../PauseMenu",
]

static var _active: Node
var _samples: Dictionary = {}
var _last_sample_usec: int = 0
var _last_physics_frame: int = 0
var _last_render_frame: int = 0
var _tracked_roots: Array[Node] = []


static func begin(source: Node = null) -> int:
	if not is_instance_valid(_active) or not _active.enabled:
		return 0
	if source == null:
		return 0
	for tracked_root in _active._tracked_roots:
		if is_instance_valid(tracked_root) and (source == tracked_root or tracked_root.is_ancestor_of(source)):
			return Time.get_ticks_usec()
	return 0


static func finish(category: StringName, started: int) -> void:
	if started == 0 or not is_instance_valid(_active) or not _active.enabled:
		return
	var elapsed := Time.get_ticks_usec() - started
	var samples: Dictionary = _active._samples
	if not samples.has(category):
		samples[category] = {"calls": 0, "total_usec": 0, "peak_usec": 0}
	var bucket: Dictionary = samples[category]
	bucket.calls += 1
	bucket.total_usec += elapsed
	bucket.peak_usec = maxi(bucket.peak_usec, elapsed)


func _ready() -> void:
	set_process(OS.is_debug_build())
	if OS.is_debug_build():
		_active = self
		var player := get_node_or_null(player_path)
		if player != null:
			_tracked_roots.append(player)
		for path in hud_paths:
			var hud := get_node_or_null(path)
			if hud != null and (player == null or not player.is_ancestor_of(hud)):
				_tracked_roots.append(hud)
	_reset_window()


func _exit_tree() -> void:
	if _active == self:
		_active = null


func _reset_window() -> void:
	_samples.clear()
	_last_sample_usec = Time.get_ticks_usec()
	_last_physics_frame = Engine.get_physics_frames()
	_last_render_frame = Engine.get_process_frames()


func _process(_delta: float) -> void:
	if not enabled:
		_reset_window()
		return
	if Time.get_ticks_usec() - _last_sample_usec >= maxf(sample_interval, 1.0) * 1000000.0:
		print("[PlayerPerf] ", JSON.stringify(collect_sample()))


func collect_sample() -> Dictionary:
	var now := Time.get_ticks_usec()
	var ticks := maxi(1, Engine.get_physics_frames() - _last_physics_frame)
	var frames := maxi(1, Engine.get_process_frames() - _last_render_frame)
	var timings: Dictionary = {}
	for category in _samples:
		var bucket: Dictionary = _samples[category]
		timings[category] = {
			"calls": bucket.calls,
			"total_ms": bucket.total_usec / 1000.0,
			"avg_call_ms": bucket.total_usec / (1000.0 * bucket.calls),
			"peak_call_ms": bucket.peak_usec / 1000.0,
			"ms_per_physics_tick": bucket.total_usec / (1000.0 * ticks),
			"ms_per_render_frame": bucket.total_usec / (1000.0 * frames),
		}
	var player := get_node_or_null(player_path)
	var context: Dictionary = {"present": player != null}
	if player != null:
		context["state"] = str(player.state_machine.active_state.name) if player.state_machine.active_state != null else "none"
		context["health"] = player.get_current_health()
		context["speed"] = player.velocity.length()
		context["animation"] = str(player.character_animation_player.current_animation)
		context["hit_reacting"] = player.animation_controller.is_hit_reacting
		context["nodes"] = player.find_children("*", "", true, false).size() + 1
	var hud_counts: Dictionary = {}
	for path in hud_paths:
		var hud := get_node_or_null(path)
		if hud == null: continue
		var controls := hud.find_children("*", "Control", true, false)
		var visible_controls := 0
		for control in controls:
			if control.is_visible_in_tree(): visible_controls += 1
		hud_counts[str(hud.name)] = {"controls": controls.size(), "visible_controls": visible_controls}
	var result := {
		"uptime_s": now / 1000000.0,
		"window_s": (now - _last_sample_usec) / 1000000.0,
		"fps": Engine.get_frames_per_second(),
		"player": context, "hud": hud_counts, "cpu_timings": timings,
		"timings_overlap": true,
	}
	_reset_window()
	return result

extends Node
## One bounded diagnostic sample per interval, including a baseline before combat.
## Hostile timings cover GDScript and synchronous movement/queries, not rendering.

@export var enabled: bool = true
@export_range(1.0, 30.0, 1.0) var sample_interval: float = 5.0

var _last_sample_usec: int = 0
var _last_physics_frame: int = 0


func _ready() -> void:
	set_process(OS.is_debug_build())
	_last_sample_usec = Time.get_ticks_usec()
	_last_physics_frame = Engine.get_physics_frames()


func _process(_delta: float) -> void:
	if Time.get_ticks_usec() - _last_sample_usec < maxf(sample_interval, 1.0) * 1000000.0:
		return
	var sample := collect_sample()
	if enabled:
		print("[CombatPerf] ", JSON.stringify(sample))


func collect_sample() -> Dictionary:
	var now := Time.get_ticks_usec()
	var physics_frames := Engine.get_physics_frames()
	var ticks := maxi(1, physics_frames - _last_physics_frame)
	var total_usec := 0
	var peak_usec := 0
	var ground_usec := 0
	var states: Dictionary = {}
	var reacting := 0
	var relocating := 0
	for hostile in get_tree().get_nodes_in_group(&"hostile"):
		var state_name: String = hostile.State.keys()[hostile.current_state]
		states[state_name] = int(states.get(state_name, 0)) + 1
		if hostile.is_hit_reacting: reacting += 1
		if hostile is RangedHostile and hostile.is_relocating: relocating += 1
		total_usec += hostile.debug_physics_usec
		peak_usec = maxi(peak_usec, hostile.debug_physics_peak_usec)
		ground_usec += hostile.debug_ground_query_usec
		hostile.debug_physics_usec = 0
		hostile.debug_physics_peak_usec = 0
		hostile.debug_ground_query_usec = 0
	var sample := {
		"uptime_s": snappedf(now / 1000000.0, 0.1),
		"window_s": snappedf((now - _last_sample_usec) / 1000000.0, 0.01),
		"fps": Engine.get_frames_per_second(),
		"physics_ms_latest": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"hostile_ms_per_tick": total_usec / (1000.0 * ticks),
		"hostile_peak_call_ms": peak_usec / 1000.0,
		"target_ground_ms_per_tick": ground_usec / (1000.0 * ticks),
		"hostile_states": states,
		"hostile_reacting": reacting,
		"hostile_relocating": relocating,
		"civilians": get_tree().get_nodes_in_group(&"civilian").size(),
		"nodes": get_tree().get_node_count(),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"static_memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"render_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"active_physics_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"landing_effects": get_tree().get_nodes_in_group(&"debug_landing_effects").size(),
		"explosion_effects": get_tree().get_nodes_in_group(&"debug_explosion_effects").size(),
	}
	_last_sample_usec = now
	_last_physics_frame = physics_frames
	return sample

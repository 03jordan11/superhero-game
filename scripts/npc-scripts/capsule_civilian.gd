extends Node3D

const CROWD_PERF = preload("res://scripts/ui-scripts/civilian_crowd_performance_monitor.gd")
## Visual only: no character physics, animation, shadows or avoidance probes.
const JOURNEY := preload("res://scripts/npc-scripts/pedestrian_journey.gd")
var is_lightweight := true
var route_enabled := true
var graph: Node3D
var walk_speed := 2.5
var lane_offset := 0.0
var spacing_speed_limit := INF
var crossing_wait_seconds := 1.2
var waypoint_arrival_distance := 0.2
var completed_destinations := 0
var skin_tone_index := -1
var hair_style_index := -1
var hair_color_index := -1
var _path := PackedInt64Array()
var _waypoints := PackedVector3Array()
var _path_index := 1
var _current_id := 0
var _pause_remaining := 0.0
var _crossing_active := false
var pending_damage: Array = []
var promotion_blocked := false

signal damage_position_changed

func _enter_tree() -> void:
	# Local notifications update damage lookup immediately on movement/teleports.
	# Global notifications also account for a transformed parent.
	set_notify_local_transform(true)
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED or what == NOTIFICATION_TRANSFORM_CHANGED:
		if is_inside_tree(): damage_position_changed.emit()

func begin_ambient_route(network: Node3D, a: int, b: int) -> void:
	graph = network
	_current_id = a
	_path = JOURNEY.make_path(graph,a,b)
	_waypoints = JOURNEY.make_waypoints(graph,_path,lane_offset,0.55)
	_path_index = 1

func spawn_position(progress: float) -> Vector3:
	return _waypoints[0].lerp(_waypoints[1],progress)

func set_visual(mesh: CapsuleMesh, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "CapsuleVisual"
	visual.mesh = mesh
	visual.material_override = material
	visual.position.y = mesh.height*0.5
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func _process(delta: float) -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_process(delta)
	CROWD_PERF.finish(&"capsule_movement", perf_started)


func _profiled_process(delta: float) -> void:
	if not route_enabled or graph == null or not graph.valid or not pending_damage.is_empty() or promotion_blocked: return
	var remaining := delta
	for step in range(32):
		if remaining <= 0.0: return
		if _pause_remaining > 0.0:
			var waited := minf(remaining,_pause_remaining)
			_pause_remaining -= waited
			remaining -= waited
			if remaining <= 0.0: return
		if _path_index >= _path.size():
			completed_destinations += 1
			var neighbors: PackedInt64Array = graph.astar.get_point_connections(_current_id)
			if neighbors.is_empty(): return
			begin_ambient_route(graph,_current_id,neighbors[randi()%neighbors.size()])
		var crossing: bool = graph.is_crossing(_path[_path_index-1],_path[_path_index])
		if crossing and not _crossing_active:
			_crossing_active = true
			_pause_remaining = crossing_wait_seconds
			continue
		if not crossing: _crossing_active = false
		var target := _waypoints[_path_index]
		var offset := target-global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= waypoint_arrival_distance:
			global_position.y = target.y
			_current_id = _path[_path_index]
			_path_index += 1
			continue
		var direction := offset/distance
		var speed := maxf(minf(walk_speed,spacing_speed_limit),0.0)
		if speed <= 0.0: return
		var travel := minf(distance,speed*remaining)
		var next_position := global_position+direction*travel
		# Lightweight walkers have no gravity; follow the authored bridge grade.
		next_position.y = lerpf(global_position.y,target.y,travel/distance)
		global_position = next_position
		look_at(global_position+direction,Vector3.UP)
		remaining -= travel/speed
		if travel < distance: return

func apply_damage(damage_info) -> bool:
	if damage_info == null: return false
	pending_damage.append(damage_info)
	return true

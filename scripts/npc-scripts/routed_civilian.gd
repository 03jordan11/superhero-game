extends "res://scripts/npc-scripts/civilian.gd"

const CROWD_PERF = preload("res://scripts/ui-scripts/civilian_crowd_performance_monitor.gd")
## Shared route movement for ambient crowds and the standalone route pilot.
const JOURNEY := preload("res://scripts/npc-scripts/pedestrian_journey.gd")
var is_lightweight := false
var skin_tone_index := -1
var spacing_speed_limit := INF

@export_category("Pedestrian Route")
@export var route_enabled := true
@export var route_graph_path: NodePath
@export var start_point_id := 0
@export var patrol_stop_ids := PackedInt64Array([9, 10, 13, 14, 9, 0, 2, 5, 4, 3, 1, 0])
@export var allow_crossings := true
@export_range(0.0, 10.0, 0.1) var crossing_wait_seconds := 1.2
@export_range(0.0, 0.2, 0.01) var sidewalk_clearance := 0.05
@export_range(0.05, 0.5, 0.05) var waypoint_arrival_distance := 0.2
@export var show_route_status := true
@export_range(-3.0, 3.0, 0.05) var lane_offset := 0.0
@export_category("Stuck Recovery")
@export var stuck_recovery_enabled := true
@export_range(0.5,5.0,0.1) var stuck_wait_seconds := 1.25
@export_range(0.05,0.5,0.05) var stuck_progress_distance := 0.15
@export_range(1.0,10.0,0.5) var recovery_commit_seconds := 4.0
var stuck_recoveries := 0
var _stuck_elapsed := 0.0
var _recovery_cooldown := 0.0
var _progress_anchor := Vector3.ZERO
var _stuck_wait_variation := randf_range(0.0,0.35)
var ambient_roaming := false
var _waypoints := PackedVector3Array()

var route_status := "Starting"
var completed_destinations := 0
var graph: Node3D
var _path := PackedInt64Array()
var _path_index := 1
var _current_id := 0
var _stop_index := 0
var _pause_remaining := 0.0
var _crossing_active := false
var _body_radius := 0.5

func _ready() -> void:
	super()
	current_state = State.WALK_TO_DESTINATION
	graph = get_node_or_null(route_graph_path)
	_current_id = start_point_id
	var capsule = $CollisionShape3D.shape as CapsuleShape3D
	if capsule != null:
		_body_radius = capsule.radius
	health_label.visible = show_route_status
	if graph == null or not graph.get("valid"):
		_set_status("No valid graph — stopped")
		return
	if not graph.astar.has_point(start_point_id):
		_set_status("Invalid start ID — stopped")
		graph = null
		return
	if ambient_roaming and not _path.is_empty():
		return # The crowd controller validated a position along the first segment.
	var offset: Vector3 = global_position - graph.point_world(start_point_id)
	if Vector2(offset.x,offset.z).length() > 0.3:
		_set_status("Off start point — stopped")
		graph = null

func _process_behavior(delta: float) -> void:
	if current_state != State.WALK_TO_DESTINATION:
		# Damage, fleeing, death and hit reactions retain their existing behavior.
		super(delta)
		return
	_step_route(delta)

func _physics_process(delta: float) -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_physics_process(delta)
	CROWD_PERF.finish(&"walker_physics", perf_started)


func _profiled_physics_process(delta: float) -> void:
	var deliberate_wait := _pause_remaining > 0.0 or spacing_speed_limit < 0.1 or is_hit_reacting or is_dead
	super._physics_process(delta)
	_recovery_cooldown = maxf(0.0,_recovery_cooldown-delta)
	# Measure actual displacement after move_and_slide, not requested velocity.
	var eligible := stuck_recovery_enabled and route_enabled and not deliberate_wait and not is_hit_reacting and not is_dead and is_on_floor() and walk_speed > 0.01 and current_state == State.WALK_TO_DESTINATION
	eligible = eligible and graph != null and graph.valid and _pause_remaining <= 0.0 and _path_index > 0 and _path_index < _path.size()
	var moved := Vector2(global_position.x-_progress_anchor.x,global_position.z-_progress_anchor.z).length()
	if not eligible or _recovery_cooldown > 0.0 or moved >= stuck_progress_distance:
		_stuck_elapsed = 0.0
		_progress_anchor = global_position
		return
	_stuck_elapsed += delta
	if _stuck_elapsed >= stuck_wait_seconds+_stuck_wait_variation:
		_reverse_stuck_route()

func _reverse_stuck_route() -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_reverse_stuck_route()
	CROWD_PERF.finish(&"stuck_recovery", perf_started)


func _profiled_reverse_stuck_route() -> void:
	var a := int(_path[_path_index-1])
	var b := int(_path[_path_index])
	if not graph.astar.are_points_connected(b,a): return
	if ambient_roaming:
		# Keep the same preferred side relative to the NEW travel direction.
		# Walk toward that lane; never teleport across the sidewalk.
		begin_ambient_route(graph,b,a)
		_waypoints[0] = global_position
	else:
		_path = PackedInt64Array([b,a])
		_path_index = 1
		_current_id = b
	spacing_speed_limit = INF
	_stuck_elapsed = 0.0
	_progress_anchor = global_position
	_recovery_cooldown = recovery_commit_seconds
	_stuck_wait_variation = randf_range(0.0,0.35)
	stuck_recoveries += 1
	_set_status("Turning around")

func _set_status(value: String) -> void:
	route_status = value
	if show_route_status and is_instance_valid(health_label):
		health_label.text = "Civilian: "+value

func begin_ambient_route(network: Node3D, a: int, b: int) -> void:
	graph = network
	ambient_roaming = true
	start_point_id = a
	_current_id = a
	_path = JOURNEY.make_path(graph,a,b)
	_path_index = 1
	_waypoints = JOURNEY.make_waypoints(graph,_path,lane_offset,_body_radius+sidewalk_clearance)

func spawn_position(progress: float) -> Vector3:
	return _waypoints[0].lerp(_waypoints[1],progress)

func _waypoint(index: int) -> Vector3:
	return _waypoints[index] if ambient_roaming else graph.point_world(_path[index])

func _stop(value: String) -> void:
	handle_idle()
	_set_status(value)

func _step_route(delta: float) -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_step_route(delta)
	CROWD_PERF.finish(&"route_step", perf_started)


func _profiled_step_route(delta: float) -> void:
	if not route_enabled:
		_stop("Disabled")
		return
	if graph == null or not graph.valid or (not ambient_roaming and patrol_stop_ids.is_empty()):
		_stop("No route — stopped")
		return
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(0.0, _pause_remaining-delta)
		_stop("Waiting to cross" if _crossing_active else "Pausing")
		return
	# Resolve arrivals and destination changes in this same physics tick.
	# Do not play Idle or insert a frame of zero velocity at every corner.
	for transition in range(32):
		if _path.is_empty():
			var destination := patrol_stop_ids[_stop_index]
			_path = graph.route(_current_id, destination, allow_crossings)
			_path_index = 1
			if _path.is_empty():
				_stop("Unreachable destination %d" % destination)
				return
		if _path_index >= _path.size():
			completed_destinations += 1
			if ambient_roaming:
				var next_ids: PackedInt64Array = graph.astar.get_point_connections(_current_id)
				if next_ids.is_empty():
					_stop("No connected route")
					return
				begin_ambient_route(graph,_current_id,next_ids[randi()%next_ids.size()])
				continue
			_stop_index = (_stop_index+1)%patrol_stop_ids.size()
			_path = PackedInt64Array()
			continue
		var next := _waypoint(_path_index)
		if Vector2(global_position.x-next.x,global_position.z-next.z).length() < waypoint_arrival_distance:
			_current_id = _path[_path_index]
			_path_index += 1
			continue
		break
	if _path.is_empty() or _path_index >= _path.size():
		_stop("No distinct destination")
		return
	var a := int(_path[_path_index-1])
	var b := int(_path[_path_index])
	var start := _waypoint(_path_index-1)
	var target := _waypoint(_path_index)
	var flat := Vector3(global_position.x, start.y, global_position.z)
	var segment := Vector2(target.x-start.x,target.z-start.z)
	if segment.length_squared()>0.001:
		var progress := Vector2(flat.x-start.x,flat.z-start.z).dot(segment)/segment.length_squared()
		flat.y = lerpf(start.y,target.y,clampf(progress,0.0,1.0))
	var crossing: bool = graph.is_crossing(a,b)
	if crossing and not _crossing_active:
		_crossing_active = true
		_pause_remaining = crossing_wait_seconds
		_stop("Waiting to cross")
		return
	if not crossing:
		_crossing_active = false
	var displacement := target-flat
	displacement.y = 0.0
	var distance := displacement.length()
	if distance < 0.001:
		return
	var direction := displacement/distance
	var speed := minf(maxf(minf(walk_speed,spacing_speed_limit),0.0), distance/maxf(delta,0.0001))
	# One footprint check against existing route data. No detour search or ground rays.
	# Actual obstacle collisions are handled by NPCBase.move_and_slide().
	if not graph.contains_body(flat+direction*speed*delta,_body_radius+sidewalk_clearance,a,b):
		_stop("Outside walking area")
		return
	velocity.x = direction.x*speed
	velocity.z = direction.z*speed
	look_at(global_position+direction, Vector3.UP)
	animation_controller.call("set_is_walking", speed > 0.0)
	_set_status("Following" if spacing_speed_limit < walk_speed else ("Crossing" if crossing else str(graph.edge_types.get(Vector2i(a,b),"Walking")).capitalize()))

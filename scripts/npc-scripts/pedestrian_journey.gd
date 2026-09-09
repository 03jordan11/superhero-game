extends RefCounted
## Route data shared by full civilians and cheap visual walkers.
const FIELDS := ["_path","_waypoints","_path_index","_current_id","_pause_remaining","_crossing_active","walk_speed","lane_offset","spacing_speed_limit","crossing_wait_seconds","waypoint_arrival_distance","completed_destinations","skin_tone_index"]

static func make_path(graph: Node3D, a: int, b: int) -> PackedInt64Array:
	var path := PackedInt64Array([a,b])
	for step in range(12):
		var neighbors: PackedInt64Array = graph.astar.get_point_connections(path[-1])
		if neighbors.size() > 1:
			var back := neighbors.find(path[-2])
			if back >= 0: neighbors.remove_at(back)
		if neighbors.is_empty(): break
		path.append(neighbors[randi()%neighbors.size()])
	return path

static func make_waypoints(graph: Node3D, path: PackedInt64Array, offset: float, clearance: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in range(path.size()):
		var center: Vector3 = graph.point_world(path[i])
		var incoming: Vector3 = (center-graph.point_world(path[maxi(0,i-1)])).normalized()
		var outgoing: Vector3 = (graph.point_world(path[mini(i+1,path.size()-1)])-center).normalized()
		if incoming == Vector3.ZERO: incoming = outgoing
		if outgoing == Vector3.ZERO: outgoing = incoming
		var side := (incoming+outgoing).cross(Vector3.UP)/maxf(0.5,1.0+incoming.dot(outgoing))
		points.append(center+side.limit_length(1.5)*offset)
	for i in range(1,path.size()):
		for attempt in range(4):
			var clear := true
			var steps := maxi(1,ceili(points[i-1].distance_to(points[i])/0.75))
			for sample in range(steps+1):
				if not graph.contains_body(points[i-1].lerp(points[i],float(sample)/steps),clearance,path[i-1],path[i]):
					clear = false
					break
			if clear: break
			var shrink := 0.5 if attempt < 2 else 0.0
			points[i-1] = graph.point_world(path[i-1]).lerp(points[i-1],shrink)
			points[i] = graph.point_world(path[i]).lerp(points[i],shrink)
	return points

static func capture(walker: Node3D) -> Dictionary:
	var state := {"transform":walker.global_transform}
	for field in FIELDS: state[field] = walker.get(field)
	return state

static func restore(walker: Node3D, state: Dictionary) -> void:
	for field in FIELDS: walker.set(field,state[field])
	walker.global_transform = state.transform

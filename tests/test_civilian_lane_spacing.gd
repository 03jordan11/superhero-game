extends SceneTree

const CAPSULE = preload("res://scripts/npc-scripts/capsule_civilian.gd")
const JOURNEY = preload("res://scripts/npc-scripts/pedestrian_journey.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var graph = load("res://scripts/npc-scripts/pedestrian_route_graph.gd").new()
	root.add_child(graph)
	assert(graph.valid)
	var walkers := Node3D.new()
	root.add_child(walkers)
	var crowd = load("res://scripts/npc-scripts/civilian_crowd.gd").new()
	crowd._graph = graph
	crowd._active = walkers
	var leader = make_walker(walkers,graph,0,6,0.5)
	var follower = make_walker(walkers,graph,0,6,0.5)
	var opposite = make_walker(walkers,graph,6,0,0.5)
	var forward: Vector3 = (graph.point_world(6)-graph.point_world(0)).normalized()
	follower.global_position = leader.global_position-forward*1.8
	# Same positive lane offset puts opposing walkers on opposite physical sides.
	var offset_a: Vector3 = leader.global_position-graph.point_world(0)
	var offset_b: Vector3 = opposite.global_position-graph.point_world(0)
	var side := forward.cross(Vector3.UP)
	assert(offset_a.dot(side) > 0.5 and offset_b.dot(side) < -0.5)
	crowd._update_spacing()
	assert(follower.spacing_speed_limit > 0.0 and follower.spacing_speed_limit < follower.walk_speed)
	assert(is_inf(leader.spacing_speed_limit) and is_inf(opposite.spacing_speed_limit))
	var start: Vector3 = follower.global_position
	follower._profiled_process(0.1)
	assert(follower.global_position.distance_to(start) < 0.1)
	# Representation handoff must preserve the spacing decision.
	var copy = CAPSULE.new()
	walkers.add_child(copy)
	copy.set_process(false)
	JOURNEY.restore(copy,JOURNEY.capture(follower))
	assert(copy.spacing_speed_limit == follower.spacing_speed_limit)
	copy.free()
	# Removing the leader must release the follower on the next spacing update.
	leader.free()
	crowd._update_spacing()
	assert(is_inf(follower.spacing_speed_limit))
	follower.route_enabled = false
	start = follower.global_position
	follower._profiled_process(0.1)
	assert(follower.global_position == start)
	crowd.free()
	walkers.free()
	graph.free()
	print("PASS: directional offsets, same-direction spacing, opposite-lane independence, movement, handoff and removal cleanup")
	quit()

func make_walker(parent: Node3D, graph: Node3D, a: int, b: int, progress: float) -> Node3D:
	var walker = CAPSULE.new()
	walker.lane_offset = 0.7
	walker.crossing_wait_seconds = 0.0
	walker.begin_ambient_route(graph,a,b)
	parent.add_child(walker)
	walker.set_process(false)
	walker.global_position = walker.spawn_position(progress)
	return walker

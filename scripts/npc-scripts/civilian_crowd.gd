extends Node3D

const CROWD_PERF = preload("res://scripts/ui-scripts/civilian_crowd_performance_monitor.gd")
## Bounded nearby population. The city graph owns routes; civilians own movement.
const CIVILIAN := preload("res://scenes/npcs/routed_civilian.tscn")
const CELL_SIZE := 100.0
const SKIN_TONES := [Color(1.15,1.08,1.0), Color(1.0,0.93,0.84), Color(0.87,0.76,0.64), Color(0.73,0.59,0.46), Color(0.59,0.43,0.31), Color(0.44,0.29,0.20), Color(0.30,0.18,0.12), Color(0.19,0.11,0.075)]

@export_category("Population")
@export var crowd_enabled := true
@export var player_path: NodePath
@export var route_graph_path: NodePath = ^"../CityPedestrianRoutes"
@export_range(0,1000,1) var population_target := 40
@export_range(0,1000,1) var max_civilians := 1000
@export_category("Local Density")
@export_range(0.0,30.0,0.5) var civilians_per_100m := 4.0
@export_range(10.0,150.0,5.0) var density_cell_size := 50.0
@export_range(0,100,1) var max_civilians_per_cell := 6
@export_category("Distance and Height")
@export_range(10.0,500.0,1.0) var ground_radius := 150.0
@export_range(0.0,500.0,1.0) var high_altitude_radius := 30.0
@export_range(0.0,1000.0,1.0) var height_reduction_start := 25.0
@export_range(1.0,2000.0,1.0) var height_reduction_end := 200.0
@export_range(0.0,1.0,0.05) var high_altitude_population_fraction := 0.0
@export_range(1.0,200.0,1.0) var despawn_margin := 40.0
@export_range(0.0,30.0,0.25) var despawn_delay := 1.5
@export_range(0.0,100.0,1.0) var minimum_player_distance := 12.0
@export_range(1.1,5.0,0.1) var minimum_npc_spacing := 1.6
@export_category("Walking Lanes")
@export_range(0.1,1.0,0.05) var spacing_update_interval := 0.2
@export_range(0.2,2.0,0.1) var following_time := 0.5
@export_category("Work Budget")
@export_range(0.1,2.0,0.05) var population_update_interval := 0.25
@export_range(1,10,1) var spawns_per_frame := 2
@export_range(1,30,1) var spawn_attempts_per_frame := 6
@export_range(1,20,1) var removals_per_frame := 2
@export_category("Spawn Direction")
@export_range(5.0,100.0,1.0) var nearby_circle_radius := 25.0
@export_range(20.0,180.0,5.0) var forward_cone_angle := 75.0
@export_range(0.0,120.0,5.0) var retention_angle_margin := 35.0
@export_range(0.0,1.0,0.05) var forward_spawn_share := 0.7
@export_range(0.1,1.0,0.05) var forward_distance_fraction := 0.65
@export_range(0.0,100.0,1.0) var movement_bias_start_speed := 6.0
@export_range(1.0,200.0,1.0) var movement_bias_full_speed := 30.0
@export var prefer_offscreen_spawns := false
@export_category("Civilian Variation")
@export_range(0.0,3.0,0.05) var minimum_lane_offset := 0.55
@export_range(0.0,3.0,0.05) var maximum_lane_offset := 1.4
@export_range(0.5,5.0,0.1) var minimum_walk_speed := 2.1
@export_range(0.5,5.0,0.1) var maximum_walk_speed := 2.9
@export var random_skin_tones := true
@export var show_civilian_status := false
@export_category("Population Debug")
@export var show_population_area := false

# Inspect these in the Remote tree without per-character debug labels.
var active_count := 0
var current_target := 0
var current_radius := 0.0
var density_capacity := 0
var rejected_spawns := 0
var status := "Waiting for player and routes"
var _graph: Node3D
var _player: Node3D
var _active: Node3D
var _cells: Dictionary = {}
var _edges: Array[Vector2i] = []
var _nearby: Array[Vector2i] = []
var _intervals: Array[Vector2] = []
var _cell_lengths: Dictionary = {}
var _cell_capacities: Dictionary = {}
var _cell_counts: Dictionary = {}
var _counted_cells: Dictionary = {}
var _weights := PackedFloat32Array()
var _total_weight := 0.0
var _forward_weights := PackedFloat32Array()
var _forward_total := 0.0
var _spawn_forward := Vector3.FORWARD
var _last_player_position := Vector3.ZERO
var _has_player_sample := false
var _outside_time: Dictionary = {}
var _retiring: Dictionary = {}
var _skin_materials: Dictionary = {}
var _timer := 0.0
var _spawn_retry := 0.0
var _spacing_timer := 0.0
var _spawn_shape := CapsuleShape3D.new()
var _area_debug: MeshInstance3D
var _route_height := 0.03
var _lod: Node

func _ready() -> void:
	_active = $ActiveCivilians
	_lod = $CapsuleLOD
	_spawn_shape.height = 1.7544
	_graph = get_node_or_null(route_graph_path)
	if _graph == null:
		status = "Missing route graph"
		set_physics_process(false)
		return
	_graph.rebuilt.connect(_index_routes)
	if _graph.valid: _index_routes()

func _index_routes() -> void:
	_cells.clear()
	_edges.clear()
	_nearby.clear()
	# A changed checkbox invalidates old journeys; recreate ambient walkers gradually.
	for walker in _active.get_children():
		walker.route_enabled = false
		_retiring[walker] = true
	for edge: Vector2i in _graph.edge_types:
		if edge.x > edge.y or _graph.is_crossing(edge.x,edge.y): continue
		var a: Vector3 = _graph.point_world(edge.x)
		var b: Vector3 = _graph.point_world(edge.y)
		var index := _edges.size()
		_edges.append(edge)
		for x in range(floori(minf(a.x,b.x)/CELL_SIZE),floori(maxf(a.x,b.x)/CELL_SIZE)+1):
			for z in range(floori(minf(a.z,b.z)/CELL_SIZE),floori(maxf(a.z,b.z)/CELL_SIZE)+1):
				var cell := Vector2i(x,z)
				if not _cells.has(cell): _cells[cell] = []
				_cells[cell].append(index)
	_timer = 0.0

func _physics_process(delta: float) -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_physics_process(delta)
	CROWD_PERF.finish(&"population_manager", perf_started)


func _profiled_physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_has_player_sample = false
		_player = get_node_or_null(player_path) if not player_path.is_empty() else get_tree().get_first_node_in_group(&"player")
	_timer -= delta
	if _timer <= 0.0:
		_update_population(maxf(population_update_interval,0.1))
		_timer = maxf(population_update_interval,0.1)
	var removed := 0
	for walker in _retiring.keys():
		if not is_instance_valid(walker):
			_retiring.erase(walker)
			_outside_time.erase(walker)
			continue
		if crowd_enabled and _protected(walker): continue
		_retiring.erase(walker)
		_outside_time.erase(walker)
		if _counted_cells.has(walker):
			var cell: Vector2i = _counted_cells[walker]
			_cell_counts[cell] = maxi(0,int(_cell_counts.get(cell,0))-1)
			_counted_cells.erase(walker)
		_lod.forget(walker)
		walker.free()
		removed += 1
		if removed >= maxi(removals_per_frame,1): break
	active_count = _active.get_child_count()
	if not crowd_enabled or not is_instance_valid(_player) or not _graph.valid: return
	_lod.update(delta)
	_spacing_timer -= delta
	if _spacing_timer <= 0.0:
		_update_spacing()
		_spacing_timer = maxf(spacing_update_interval,0.1)
	_spawn_retry = maxf(0.0,_spawn_retry-delta)
	if _spawn_retry > 0.0: return
	var spawned := 0
	var new_positions: Array[Vector3] = []
	for attempt in range(maxi(spawn_attempts_per_frame,1)):
		if active_count >= mini(current_target,maxi(max_civilians,0)) or _nearby.is_empty(): break
		if _try_spawn(attempt < floori(spawn_attempts_per_frame * 0.5),new_positions):
			spawned += 1
			active_count += 1
			if spawned >= maxi(spawns_per_frame,1): break
		else:
			rejected_spawns += 1
	if spawned == 0: _spawn_retry = maxf(population_update_interval,0.1)

func _update_spacing() -> void:
	var perf_started := CROWD_PERF.begin(self)
	# Temporary lists, bounded by the live population; no retained walker references.
	# A directed edge is one walking lane. Intersections rely on normal physics.
	var lanes: Dictionary = {}
	for walker in _active.get_children():
		walker.spacing_speed_limit = INF
		if not walker.route_enabled or walker._path_index < 1 or walker._path_index >= walker._path.size(): continue
		if not walker.is_lightweight and (walker.is_dead or walker.is_hit_reacting or walker.current_state != walker.State.WALK_TO_DESTINATION): continue
		var edge := Vector2i(walker._path[walker._path_index-1],walker._path[walker._path_index])
		var start: Vector3 = _graph.point_world(edge.x)
		var forward: Vector3 = (_graph.point_world(edge.y)-start).normalized()
		var progress: float = (walker.global_position-start).dot(forward)
		if not lanes.has(edge): lanes[edge] = []
		lanes[edge].append([progress,walker])
	for lane: Array in lanes.values():
		lane.sort_custom(func(a,b): return a[0] > b[0])
		for i in range(1,lane.size()):
			var gap: float = lane[i-1][0]-lane[i][0]
			# Slow down behind the next person, without searching for a way around.
			lane[i][1].spacing_speed_limit = maxf(0.0,(gap-minimum_npc_spacing)/maxf(following_time,spacing_update_interval))
	CROWD_PERF.finish(&"lane_spacing", perf_started)

func _update_population(elapsed: float) -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_update_population(elapsed)
	CROWD_PERF.finish(&"population_update", perf_started)


func _profiled_update_population(elapsed: float) -> void:
	_nearby.clear()
	_intervals.clear()
	_cell_lengths.clear()
	_cell_capacities.clear()
	_cell_counts.clear()
	_counted_cells.clear()
	density_capacity = 0
	_weights.clear()
	_total_weight = 0.0
	_forward_weights.clear()
	_forward_total = 0.0
	current_target = 0
	if crowd_enabled and is_instance_valid(_player) and _graph.valid:
		_update_spawn_direction(elapsed)
		var p := _player.global_position
		var radius := maxf(ground_radius,high_altitude_radius)
		if _lod.enabled: radius = maxf(radius,_lod.view_distance)
		var candidates: Dictionary = {}
		var closest := INF
		var route_height := p.y-height_reduction_end
		for x in range(floori((p.x-radius)/CELL_SIZE),floori((p.x+radius)/CELL_SIZE)+1):
			for z in range(floori((p.z-radius)/CELL_SIZE),floori((p.z+radius)/CELL_SIZE)+1):
				for index in _cells.get(Vector2i(x,z),[]): candidates[index] = true
		for index in candidates:
			var edge := _edges[index]
			var a: Vector3 = _graph.point_world(edge.x)
			var b: Vector3 = _graph.point_world(edge.y)
			var projected := Geometry3D.get_closest_point_to_segment(Vector3(p.x,a.y,p.z),a,b)
			var distance := Vector2(projected.x-p.x,projected.z-p.z).length()
			if distance < closest:
				closest = distance
				route_height = projected.y
		var height_blend := clampf((p.y-route_height-height_reduction_start)/maxf(height_reduction_end-height_reduction_start,1.0),0.0,1.0)
		_route_height = route_height
		current_radius = lerpf(ground_radius,high_altitude_radius,height_blend)
		var high_fraction := high_altitude_population_fraction
		var target_budget := maxi(population_target,0)
		if _lod.enabled:
			high_fraction = maxf(high_fraction,_lod.high_altitude_population_fraction)
			target_budget += maxi(_lod.max_capsules,0)
		var population_factor := lerpf(1.0,clampf(high_fraction,0,1),height_blend)
		current_target = mini(maxi(max_civilians,0),roundi(target_budget*population_factor))
		for index in candidates:
			var edge := _edges[index]
			var a: Vector3 = _graph.point_world(edge.x)
			var b: Vector3 = _graph.point_world(edge.y)
			var projected := Geometry3D.get_closest_point_to_segment(Vector3(p.x,a.y,p.z),a,b)
			if Vector2(projected.x-p.x,projected.z-p.z).length() > radius: continue
			# Short intervals approximate clipped route length, instead of counting
			# a whole edge when only its tip enters the circle/cone. No scene nodes.
			var length := a.distance_to(b)
			var steps := maxi(1,ceili(length/5.0))
			for part in range(steps):
				var interval := Vector2(float(part)/steps,float(part+1)/steps)
				var point := a.lerp(b,(interval.x+interval.y)*0.5)
				if not _spawn_distance_ok(point): continue
				var cell := _density_cell(point)
				_cell_lengths[cell] = float(_cell_lengths.get(cell,0.0))+length/steps
				_nearby.append(edge)
				_intervals.append(interval)
		for cell in _cell_lengths:
			var capacity := _capacity_for_length(_cell_lengths[cell],population_factor)
			_cell_capacities[cell] = capacity
			density_capacity += capacity
		current_target = mini(current_target,density_capacity)
		status = "Populating" if density_capacity > 0 else "No local density capacity"
		if _nearby.is_empty(): status = "No enabled routes in circle/cone"
	else:
		status = "Disabled" if not crowd_enabled else "Waiting for player and routes"
	var walkers := _active.get_children()
	for walker in walkers:
		var cell := _density_cell(walker.global_position)
		_cell_counts[cell] = int(_cell_counts.get(cell,0))+1
		_counted_cells[walker] = cell
	# Do not keep sampling full cells while waiting for the next update.
	for i in range(_nearby.size()):
		var edge := _nearby[i]
		var interval := _intervals[i]
		var a: Vector3 = _graph.point_world(edge.x)
		var b: Vector3 = _graph.point_world(edge.y)
		var point := a.lerp(b,(interval.x+interval.y)*0.5)
		var length := a.distance_to(b)*(interval.y-interval.x) if _cell_has_space(point) else 0.0
		_total_weight += length
		_weights.append(_total_weight)
		_forward_total += length*_forward_preference(point)
		_forward_weights.append(_forward_total)
	if is_instance_valid(_player):
		walkers.sort_custom(func(a,b): return a.global_position.distance_squared_to(_player.global_position) > b.global_position.distance_squared_to(_player.global_position))
	var excess := maxi(0,walkers.size()-current_target)
	for walker in walkers:
		var outside: bool = not crowd_enabled or not is_instance_valid(_player) or not walker.route_enabled
		if is_instance_valid(_player):
			outside = outside or not _in_population_area(walker.global_position,true)
			var trim_distance := minimum_player_distance if walkers.size() > maxi(max_civilians,0) else minf(nearby_circle_radius,current_radius)
			if excess > 0 and walker.global_position.distance_to(_player.global_position) > trim_distance:
				outside = true
				excess -= 1
		if outside:
			_outside_time[walker] = float(_outside_time.get(walker,0.0))+elapsed
			if not crowd_enabled or _outside_time[walker] >= despawn_delay: _retiring[walker] = true
		else:
			_outside_time.erase(walker)
			_retiring.erase(walker)
	_draw_population_area()
	_lod.refresh_counts()

func _draw_population_area() -> void:
	if not show_population_area or not crowd_enabled or not is_instance_valid(_player):
		if is_instance_valid(_area_debug): _area_debug.visible = false
		return
	if not is_instance_valid(_area_debug):
		_area_debug = MeshInstance3D.new()
		_area_debug.name = "PopulationArea"
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		_area_debug.material_override = material
		_area_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_area_debug)
	_area_debug.visible = true
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var center := Vector3(_player.global_position.x,_route_height+0.15,_player.global_position.z)
	for retaining in [true,false]:
		var margin := maxf(despawn_margin,0.0) if retaining else 0.0
		var near_radius := minf(nearby_circle_radius,current_radius)+minf(margin,10.0)
		var far_radius := current_radius+margin
		var half_angle := deg_to_rad(minf(360.0,forward_cone_angle+(retention_angle_margin if retaining else 0.0))*0.5)
		mesh.surface_set_color(Color("657077") if retaining else Color("35eddf"))
		for i in range(64):
			for angle in [TAU*i/64.0,TAU*(i+1)/64.0]:
				mesh.surface_add_vertex(to_local(center+Vector3(cos(angle),0,sin(angle))*near_radius))
		mesh.surface_set_color(Color("657077") if retaining else Color("ffcd38"))
		for i in range(32):
			for angle in [lerpf(-half_angle,half_angle,i/32.0),lerpf(-half_angle,half_angle,(i+1)/32.0)]:
				mesh.surface_add_vertex(to_local(center+_spawn_forward.rotated(Vector3.UP,angle)*far_radius))
		for angle in [-half_angle,half_angle]:
			for radius in [near_radius,far_radius]:
				mesh.surface_add_vertex(to_local(center+_spawn_forward.rotated(Vector3.UP,angle)*radius))
	mesh.surface_end()
	_area_debug.mesh = mesh

func _protected(walker: Node3D) -> bool:
	if walker.is_lightweight: return not walker.pending_damage.is_empty()
	if walker.is_hit_reacting: return true
	return is_instance_valid(_player) and walker.current_state != walker.State.WALK_TO_DESTINATION and walker.global_position.distance_to(_player.global_position) < minimum_player_distance+despawn_margin

func _density_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x/maxf(density_cell_size,10.0)),floori(point.z/maxf(density_cell_size,10.0)))

func _capacity_for_length(length: float, height_factor := 1.0) -> int:
	return mini(maxi(max_civilians_per_cell,0),floori(maxf(length,0.0)*maxf(civilians_per_100m,0.0)*height_factor/100.0))

func _cell_has_space(point: Vector3) -> bool:
	var cell := _density_cell(point)
	return int(_cell_counts.get(cell,0)) < int(_cell_capacities.get(cell,0))

func _in_population_area(point: Vector3, retaining := false) -> bool:
	if _lod.enabled and _lod.in_distant_area(point,retaining): return true
	var offset := point-_player.global_position
	offset.y = 0.0
	var distance := offset.length()
	var margin := maxf(despawn_margin,0.0) if retaining else 0.0
	if distance > current_radius+margin: return false
	if distance <= minf(nearby_circle_radius,current_radius)+minf(margin,10.0): return true
	var angle := minf(360.0,forward_cone_angle+(retention_angle_margin if retaining else 0.0))
	return offset.normalized().dot(_spawn_forward) >= cos(deg_to_rad(angle*0.5))

func _update_spawn_direction(elapsed: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var facing := -camera.global_basis.z if camera != null else -_player.global_basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.001: facing = _spawn_forward
	facing = facing.normalized()
	var travel := Vector3.ZERO
	if _player is CharacterBody3D:
		travel = _player.velocity
	elif _has_player_sample:
		travel = (_player.global_position-_last_player_position)/maxf(elapsed,0.01)
	_last_player_position = _player.global_position
	_has_player_sample = true
	travel.y = 0.0
	var blend := clampf((travel.length()-movement_bias_start_speed)/maxf(movement_bias_full_speed-movement_bias_start_speed,1.0),0.0,1.0)
	_spawn_forward = facing.lerp(travel.normalized(),blend)
	if _spawn_forward.length_squared() < 0.001: _spawn_forward = facing
	_spawn_forward = _spawn_forward.normalized()

func _forward_preference(point: Vector3) -> float:
	var offset := point-_player.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < minimum_player_distance or distance > current_radius: return 0.0
	var alignment := maxf(0.0,offset.normalized().dot(_spawn_forward))
	var preferred_distance := current_radius*forward_distance_fraction
	var distance_weight := 1.0/(1.0+4.0*absf(distance-preferred_distance)/maxf(current_radius,1.0))
	return alignment*alignment*distance_weight

func _try_spawn(offscreen_only: bool, new_positions: Array[Vector3]) -> bool:
	var perf_started := CROWD_PERF.begin(self)
	var result: bool = _profiled_try_spawn(offscreen_only, new_positions)
	CROWD_PERF.finish(&"spawn_attempt", perf_started, not result)
	return result


func _profiled_try_spawn(offscreen_only: bool, new_positions: Array[Vector3]) -> bool:
	if _total_weight <= 0.0: return false
	var index := mini(_weights.bsearch(randf()*_total_weight),_nearby.size()-1)
	var forward_attempt := _forward_total > 0.0 and randf() < forward_spawn_share
	if forward_attempt:
		index = mini(_forward_weights.bsearch(randf_range(0.000001,_forward_total)),_nearby.size()-1)
	var edge := _nearby[index]
	var interval := _intervals[index]
	if randf() < 0.5:
		edge = Vector2i(edge.y,edge.x)
		interval = Vector2(1.0-interval.y,1.0-interval.x)
	var a: Vector3 = _graph.point_world(edge.x)
	var b: Vector3 = _graph.point_world(edge.y)
	var progress := randf_range(interval.x,interval.y)
	var point := a.lerp(b,progress)
	if forward_attempt:
		# A few cheap samples along the selected segment favor its forward part.
		for sample in range(3):
			var candidate_progress := randf_range(interval.x,interval.y)
			if _forward_preference(a.lerp(b,candidate_progress)) > _forward_preference(point):
				progress = candidate_progress
				point = a.lerp(b,progress)
	if not _spawn_distance_ok(point) or not _cell_has_space(point): return false
	var camera := get_viewport().get_camera_3d()
	if prefer_offscreen_spawns and offscreen_only and camera != null and camera.is_position_in_frustum(point+Vector3.UP): return false
	# A distant spawn never instantiates the full model or character physics.
	var lightweight: bool = _lod.enabled and not _lod.wants_full(point)
	if lightweight and _lod.capsule_count >= _lod.max_capsules: return false
	if not lightweight and _lod.enabled and _lod.full_count >= population_target: return false
	var tone := randi()%SKIN_TONES.size() if random_skin_tones else -1
	var walker = _lod.create_capsule(tone) if lightweight else CIVILIAN.instantiate()
	walker.skin_tone_index = tone
	# Same side relative to travel, so opposite directions occupy opposite lanes.
	walker.lane_offset = randf_range(clampf(minimum_lane_offset,0.0,maximum_lane_offset),maximum_lane_offset)
	walker.begin_ambient_route(_graph,edge.x,edge.y)
	point = walker.spawn_position(progress)
	if not _spawn_distance_ok(point) or not _cell_has_space(point) or not _spawn_clear(point,new_positions):
		walker.free()
		return false
	walker.walk_speed = randf_range(minimum_walk_speed,maxf(minimum_walk_speed,maximum_walk_speed))
	if not lightweight:
		walker.route_graph_path = _graph.get_path()
		walker.show_route_status = show_civilian_status
	walker.position = _active.to_local(point+Vector3.UP*0.01)
	if not lightweight and tone >= 0: _apply_skin(walker,tone)
	_active.add_child(walker)
	if lightweight: _lod.capsule_count += 1
	else: _lod.full_count += 1
	var cell := _density_cell(point)
	_cell_counts[cell] = int(_cell_counts.get(cell,0))+1
	_counted_cells[walker] = cell
	new_positions.append(point)
	return true

func _spawn_distance_ok(point: Vector3) -> bool:
	var distance := Vector2(point.x-_player.global_position.x,point.z-_player.global_position.z).length()
	return distance >= minimum_player_distance and _in_population_area(point)

func _spawn_clear(point: Vector3, new_positions: Array[Vector3]) -> bool:
	for walker in _active.get_children():
		if walker.is_lightweight and point.distance_to(walker.global_position) < minimum_npc_spacing: return false
	for other in new_positions:
		if point.distance_to(other) < minimum_npc_spacing: return false
	var space := get_world_3d().direct_space_state
	for offset in [Vector3.ZERO,Vector3.LEFT*0.5,Vector3.RIGHT*0.5,Vector3.FORWARD*0.5,Vector3.BACK*0.5]:
		var foot: Vector3 = point+offset
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*0.2,foot-Vector3.UP*0.2,1))
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.7: return false
	_spawn_shape.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _spawn_shape
	query.transform.origin = point+Vector3.UP*0.89
	query.collision_mask = 1
	if not space.intersect_shape(query,1).is_empty(): return false
	# Wider horizontal spacing query raised above the ground (no floor overlap).
	var spacing := SphereShape3D.new()
	spacing.radius = maxf(minimum_npc_spacing-0.5,0.6)
	query.shape = spacing
	query.transform.origin.y = point.y+spacing.radius+0.1
	return space.intersect_shape(query,1).is_empty()

func _promotion_clear(walker: Node3D) -> bool:
	var point := walker.global_position
	var space := get_world_3d().direct_space_state
	var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.2,point-Vector3.UP*0.2,1))
	if support.is_empty() or not support.collider is StaticBody3D: return false
	_spawn_shape.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _spawn_shape
	query.transform.origin = point+Vector3.UP*0.89
	query.collision_mask = 1
	if not space.intersect_shape(query,1).is_empty(): return false
	# Include bodies created earlier in this transition batch, before physics sync.
	for other in _active.get_children():
		if not other.is_lightweight and point.distance_to(other.global_position) < 1.05: return false
	return true

func _apply_skin(walker: Node3D, tone: int) -> void:
	# Eight shared body-material variants; eyes/hair and shared source assets stay intact.
	for mesh in walker.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_active_material(surface)
			if not material is StandardMaterial3D or material.resource_name != "MI_Superhero_Female": continue
			if not _skin_materials.has(tone):
				var variant = material.duplicate()
				variant.albedo_color = SKIN_TONES[tone]
				_skin_materials[tone] = variant
			mesh.set_surface_override_material(surface,_skin_materials[tone])

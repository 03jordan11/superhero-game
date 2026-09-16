extends Node3D
## Small local traffic population. No destination searches or pedestrian coordination.
const ENTRY = preload("res://scripts/traffic/traffic_vehicle_entry.gd")
const LANES = preload("res://scripts/traffic/traffic_lanes.gd")
const PERF = preload("res://scripts/ui-scripts/vehicle_performance_monitor.gd")

@export_category("Traffic Population")
@export var traffic_enabled := true
@export var focus_path: NodePath
@export var use_camera_without_player := true
@export_range(0,100,1) var population_target := 8
@export_range(0,100,1) var max_vehicles := 12
@export_range(20.0,500.0,5.0) var spawn_radius := 160.0
@export_range(5.0,100.0,1.0) var minimum_spawn_distance := 30.0
@export_range(30.0,1000.0,5.0) var despawn_radius := 230.0
@export_range(0.1,5.0,0.1) var spawn_interval := 0.5
@export_range(1,20,1) var spawn_attempts_per_update := 6
@export var prefer_offscreen_spawns := true
@export_category("Local Traffic Distribution")
@export_range(0.0,1.0,0.05) var forward_spawn_bias := 0.75
@export_range(10.0,150.0,5.0) var surrounding_radius := 45.0
@export_range(1,12,1) var max_vehicles_per_lane := 2
@export_range(0.0,10.0,0.25) var despawn_delay := 2.0
@export_range(10.0,200.0,5.0) var visible_retention_margin := 80.0
@export_range(5.0,120.0,1.0) var offscreen_stopped_recycle_delay := 25.0
@export_category("Abandoned Vehicle Cleanup")
@export var abandoned_cleanup_enabled := true
## Horizontal distance from the traffic focus. Visible vehicles are always protected.
@export_range(20.0,1000.0,10.0) var abandoned_cleanup_distance := 250.0
## All conditions must remain true continuously; pickup, movement or visibility resets this timer.
@export_range(1.0,300.0,1.0) var abandoned_cleanup_delay := 30.0
@export_range(0.0,5.0,0.1) var abandoned_max_linear_speed := 1.0
## Radians per second. Prevent cleanup while a thrown vehicle is still spinning.
@export_range(0.0,5.0,0.1) var abandoned_max_angular_speed := 0.5
@export_category("Vehicle Selection")
@export var vehicle_entries: Array[ENTRY] = []
@export var show_health_labels := false
@export_category("Driving")
@export_range(0.0,30.0,0.5) var minimum_speed := 5.0
@export_range(0.0,30.0,0.5) var maximum_speed := 8.0
@export_range(0.1,20.0,0.1) var acceleration := 2.5
@export_range(0.1,30.0,0.1) var braking := 6.0
## Each vehicle keeps one sampled bumper gap for its lifetime in traffic.
@export_range(0.5,15.0,0.5) var minimum_following_gap := 2.0
@export_range(0.5,15.0,0.5) var maximum_following_gap := 4.0
@export_range(0.5,10.0,0.5) var junction_stop_margin := 2.0
@export_category("Intersections")
@export_range(0.0,5.0,0.1) var intersection_pause := 0.8
## Each vehicle keeps one sampled junction speed, capped by its cruise speed.
@export_range(0.5,15.0,0.5) var minimum_intersection_speed := 3.0
@export_range(0.5,15.0,0.5) var maximum_intersection_speed := 5.0
## Relative weight of straight ahead versus each available turn.
@export_range(0.0,10.0,0.5) var straight_ahead_weight := 3.0
@export_category("Generated Lanes (Restart to Rebuild)")
@export_file("*.json") var layout_file := "res://assets/super-city/layout.json"
@export_range(1.5,8.0,0.25) var lane_center_offset := 3.0
@export var keep_right := true
@export var road_height := 0.03
@export var show_lane_debug := false

var lanes: Array[Dictionary] = []
var active_count := 0
var stopped_count := 0
var at_junction_count := 0
var retained_count := 0
var crossings_completed := 0
var abandoned_cleaned_count := 0
var status := "Starting"
var _cars: Array[Dictionary] = []
var _owned: Array[WeakRef] = []
var _abandoned: Dictionary = {}
var _timer := 0.0
var _focus: Node3D
var _spawn_forward := Vector3.FORWARD
var _junction_owners: Dictionary = {}
var _next_arrival := 0
var _next_traffic_id := 0
var _population_baseline: Dictionary = {}
var _traffic_controls: Node
@onready var _active: Node3D = $ActiveVehicles
@onready var _released: Node3D = $ReleasedVehicles
@onready var _lod = get_node_or_null("DistantTraffic")

func _ready() -> void:
	add_to_group(&"traffic_managers")
	var layout = JSON.parse_string(FileAccess.get_file_as_string(layout_file))
	if not layout is Dictionary:
		status = "Invalid road manifest"
		set_physics_process(false)
		return
	lanes = LANES.build(layout,lane_center_offset,road_height,keep_right)
	if _lod != null: _lod.setup(self)
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		settings.population_settings_changed.connect(_on_population_settings_changed)
		_on_population_settings_changed()
	if show_lane_debug: _draw_lanes()
	status = "Waiting for player or camera"

func _on_population_settings_changed() -> void:
	var settings := get_node("/root/GameSettings")
	apply_population_settings(settings.vehicle_scale(), settings.distance_scale())

func apply_population_settings(density: float, distance: float) -> void:
	# Capture scene overrides once, never multiply the last applied preset.
	if _population_baseline.is_empty():
		for key in ["population_target", "max_vehicles", "max_vehicles_per_lane"]:
			_population_baseline[key] = get(key)
	density = clampf(density, 0.0, 1.0)
	population_target = roundi(_population_baseline.population_target*density)
	max_vehicles = roundi(_population_baseline.max_vehicles*density)
	max_vehicles_per_lane = maxi(1, roundi(_population_baseline.max_vehicles_per_lane*density))
	if _lod != null: _lod.apply_population_settings(density, distance)
	_timer = 0.0

func _physics_process(delta: float) -> void:
	var started := PERF.begin(self)
	_step(delta)
	PERF.finish(&"traffic_manager",started)

func _step(delta: float) -> void:
	# Carried/released cars still count toward the hard cap until they are freed.
	# Weak references do not keep destroyed vehicles alive.
	for i in range(_owned.size()-1,-1,-1):
		if _owned[i].get_ref() == null: _owned.remove_at(i)
	retained_count = _owned.size()
	_focus = get_node_or_null(focus_path) if not focus_path.is_empty() else get_tree().get_first_node_in_group(&"player")
	if not is_instance_valid(_focus) and use_camera_without_player:
		_focus = get_viewport().get_camera_3d()
	if is_instance_valid(_focus): _update_spawn_direction()
	if _lod != null: _lod.step(delta)
	var retiring := false
	stopped_count = 0
	at_junction_count = 0
	for i in range(_cars.size()-1,-1,-1):
		var record: Dictionary = _cars[i]
		if not is_instance_valid(record.car):
			_release_junction(record)
			_cars.remove_at(i)
			continue
		var car: Vehicle = record.car
		if not car.traffic_controlled or car.is_destroyed or not car.freeze or car.get_parent() != _active:
			car.leave_traffic()
			_release_junction(record)
			_cars.remove_at(i)
			continue
		if _lod != null and _lod.try_demote(record,delta):
			_release_junction(record)
			car.queue_free()
			_cars.remove_at(i)
			continue
		var distance := _flat_distance(car.global_position,_focus.global_position) if is_instance_valid(_focus) else 0.0
		var retire_radius := maxf(despawn_radius,spawn_radius+20.0)
		var outside := is_instance_valid(_focus) and distance > retire_radius
		record.outside_time = record.outside_time+delta if outside else 0.0
		record.stopped_time = record.stopped_time+delta if record.speed < 0.1 else 0.0
		var unseen := false
		if (outside and record.outside_time >= despawn_delay) or (distance > minimum_spawn_distance and record.stopped_time > offscreen_stopped_recycle_delay):
			unseen = not _car_visible(car)
		var retire_far: bool = outside and record.outside_time >= despawn_delay and (unseen or distance > retire_radius+visible_retention_margin)
		var recycle: bool = unseen and distance > minimum_spawn_distance and record.stopped_time > offscreen_stopped_recycle_delay
		# LOD distance/delay takes precedence over ordinary distance retirement.
		if _lod != null and _lod.keeps_for_lod(record): retire_far = false
		# A lowered preset can leave existing cars above the new cap. Retire only
		# ambient, offscreen cars, one per tick; held/released cars never enter here.
		var over_budget: bool = _owned.size() > max_vehicles or (_cars.size() > mini(population_target,max_vehicles) and (_lod == null or not _lod.enabled))
		var excess: bool = over_budget and distance > minimum_spawn_distance and record.connection.is_empty() and not _car_visible(car)
		if not retiring and (not traffic_enabled or retire_far or recycle or excess):
			_release_junction(record)
			car.queue_free()
			_cars.remove_at(i)
			retiring = true # At most one retirement per physics tick.
			continue
		if traffic_enabled and is_instance_valid(_focus): _drive(record,delta)
		if record.speed < 0.1: stopped_count += 1
		if record.connection.is_empty() and record.progress >= record.stop_at-0.05: at_junction_count += 1
	active_count = _cars.size()
	_cleanup_abandoned(delta,not retiring)
	if _lod != null: _lod.draw_boxes()
	if not traffic_enabled:
		status = "Disabled"
		return
	if not is_instance_valid(_focus):
		status = "Waiting for player or camera"
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = maxf(spawn_interval,0.1)
		if active_count < mini(maxi(population_target,0),maxi(max_vehicles,0)) and retained_count < max_vehicles:
			_spawn_near_focus()
	active_count = _cars.size()
	status = "Driving" if active_count > 0 else "No clear nearby lane or enabled vehicle entry"

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _cleanup_abandoned(delta: float, allow_retirement: bool) -> void:
	# Only track this manager's released cars; no city scan or physics queries.
	for id in _abandoned.keys():
		var record: Dictionary = _abandoned[id]
		var car := record.vehicle.get_ref() as Vehicle
		if car == null or car.is_queued_for_deletion():
			_abandoned.erase(id)
			continue
		# Pickup reparents the car away from ReleasedVehicles and freezes it.
		# Keep the weak record so subsequent drops are covered too.
		var eligible := abandoned_cleanup_enabled and is_instance_valid(_focus)
		eligible = eligible and car.get_parent() == _released and not car.freeze and not car.traffic_controlled
		if eligible:
			eligible = _flat_distance(car.global_position,_focus.global_position) > abandoned_cleanup_distance
			eligible = eligible and car.linear_velocity.length_squared() <= abandoned_max_linear_speed*abandoned_max_linear_speed
			eligible = eligible and car.angular_velocity.length_squared() <= abandoned_max_angular_speed*abandoned_max_angular_speed
		if eligible: eligible = not _car_visible(car) # No camera also protects the car.
		record.elapsed = record.elapsed+delta if eligible else 0.0
		if eligible and record.elapsed >= abandoned_cleanup_delay and allow_retirement:
			car.queue_free()
			_abandoned.erase(id)
			abandoned_cleaned_count += 1
			allow_retirement = false # Share the one-retirement-per-tick budget with ordinary traffic.

func _car_visible(car: Vehicle) -> bool:
	var camera := get_viewport().get_camera_3d()
	# Be conservative without a camera: don't recycle a stopped car on that basis.
	if camera == null: return true
	var visual := car.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if visual == null: return camera.is_position_in_frustum(car.global_position)
	var bounds := visual.get_aabb()
	if camera.is_position_in_frustum(visual.to_global(bounds.get_center())): return true
	for i in range(8):
		if camera.is_position_in_frustum(visual.to_global(bounds.get_endpoint(i))): return true
	return false

func _update_spawn_direction() -> void:
	var camera := get_viewport().get_camera_3d()
	var facing := -camera.global_basis.z if camera != null else -_focus.global_basis.z
	facing.y = 0.0
	if facing.length_squared() > 0.001: _spawn_forward = facing.normalized()
	if _focus is CharacterBody3D:
		var travel: Vector3 = _focus.velocity
		travel.y = 0.0
		if travel.length() > 6.0: _spawn_forward = travel.normalized()

func _choose_entry() -> Resource:
	var total := 0.0
	for entry in vehicle_entries:
		if entry != null and entry.scene != null: total += maxf(entry.weight,0.0)
	if total <= 0.0: return null
	var roll := randf()*total
	for entry in vehicle_entries:
		if entry == null or entry.scene == null or entry.weight <= 0.0: continue
		roll -= entry.weight
		if roll < 0.0: return entry
	return null

func _spawn_near_focus() -> void:
	# Weight the road length inside the local circle, with a gentle forward bias.
	var candidates: Array[int] = []
	var intervals: Array[Vector2] = []
	var weights := PackedFloat32Array()
	var total := 0.0
	var center: Vector3 = get_parent().to_local(_focus.global_position)
	for i in range(lanes.size()):
		var lane: Dictionary = lanes[i]
		var count := 0
		for car in _cars:
			if car.lane == i or (not car.connection.is_empty() and car.connection.to == i): count += 1
		if count >= max_vehicles_per_lane: continue
		var along: float = (center-lane.start).dot(lane.forward)
		var nearest: Vector3 = lane.start+lane.forward*along
		var lateral := _flat_distance(center,nearest)
		if lateral >= spawn_radius: continue
		var reach := sqrt(spawn_radius*spawn_radius-lateral*lateral)
		var interval := Vector2(maxf(8.0,along-reach),minf(lane.length-15.0,along+reach))
		if interval.y <= interval.x: continue
		var midpoint: Vector3 = get_parent().to_global(lane.start+lane.forward*(interval.x+interval.y)*0.5)
		var offset: Vector3 = midpoint-_focus.global_position
		offset.y = 0.0
		var preference := 1.0
		if offset.length() > surrounding_radius:
			preference = lerpf(1.0,0.1+0.9*maxf(0.0,offset.normalized().dot(_spawn_forward)),forward_spawn_bias)
		total += (interval.y-interval.x)*preference
		candidates.append(i)
		intervals.append(interval)
		weights.append(total)
	if candidates.is_empty(): return
	for attempt in range(maxi(spawn_attempts_per_update,1)):
		var entry = _choose_entry()
		if entry == null: return
		var index := mini(weights.bsearch(randf()*total),candidates.size()-1)
		var lane_id: int = candidates[index]
		var lane: Dictionary = lanes[lane_id]
		var progress := randf_range(intervals[index].x,intervals[index].y)
		var point: Vector3 = get_parent().to_global(lane.start+lane.forward*progress)
		var distance := _flat_distance(point,_focus.global_position)
		if distance < minimum_spawn_distance or distance > spawn_radius: continue
		if _lod != null and _lod.enabled and not _lod.wants_full(point): continue
		var camera := get_viewport().get_camera_3d()
		if prefer_offscreen_spawns and camera != null and camera.is_position_in_frustum(point+Vector3.UP): continue
		if _spawn_vehicle(entry,lane_id,progress) != null: return

func _spawn_vehicle(entry: Resource, lane_id: int, progress: float, transfer: Dictionary = {}) -> Vehicle:
	if _owned.size() >= max_vehicles: return null
	var crossing: Dictionary = transfer.get("connection",{})
	if not crossing.is_empty() and _junction_owners.has(lanes[lane_id].junction): return null
	var instance = entry.scene.instantiate()
	if not instance is Vehicle:
		instance.free()
		push_warning("Traffic entries require a Vehicle scene: "+entry.scene.resource_path)
		return null
	var car: Vehicle = instance
	var collision := car.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D:
		car.free()
		push_warning("Traffic requires the vehicle's existing BoxShape3D collision.")
		return null
	var lane: Dictionary = lanes[lane_id]
	var size: Vector3 = collision.shape.size*collision.scale.abs()
	var half_length := size.z*0.5+absf(collision.position.z)
	var stop_at: float = lane.length-half_length-junction_stop_margin
	if (progress >= stop_at and transfer.is_empty()) or size.x > lane_center_offset*2.0:
		car.free()
		return null
	var gap := randf_range(minimum_following_gap,maxf(minimum_following_gap,maximum_following_gap))
	if not transfer.is_empty(): gap = transfer.following_gap
	if _lod != null and _lod.blocks_spawn(lane_id,progress,half_length,gap,transfer.get("traffic_id",-1)):
		car.free()
		return null
	for other in _cars:
		if not other.connection.is_empty() and other.connection.to == lane_id and progress < half_length+other.half_length+junction_stop_margin+other.following_gap:
			car.free()
			return null
		# The car behind determines the required bumper gap, including new spawns.
		var required_gap: float = gap if progress < other.progress else other.following_gap
		if other.lane == lane_id and absf(other.progress-progress) < half_length+other.half_length+required_gap:
			car.free()
			return null
	var position_in_city: Vector3 = lane.start+lane.forward*progress
	position_in_city.y += maxf(0.0,size.y*0.5-collision.position.y)+0.02
	# +Z is the supplied meshes' nose direction. Allow other scene orientations.
	var basis_in_city := Basis(Vector3.UP,atan2(lane.forward.x,lane.forward.z)+deg_to_rad(entry.heading_offset_degrees))
	var pose: Transform3D = get_parent().global_transform*Transform3D(basis_in_city,position_in_city)
	if not crossing.is_empty():
		position_in_city = _crossing_point(transfer,transfer.crossing_progress)
		pose = _pose(position_in_city,lane.forward,deg_to_rad(entry.heading_offset_degrees))
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := BoxShape3D.new()
	probe.size = Vector3(size.x,maxf(size.y-0.12,0.1),size.z)
	query.shape = probe
	query.collision_mask = car.collision_mask
	query.transform = pose*Transform3D(Basis.IDENTITY,collision.position)
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		car.free()
		return null
	car.transform = _active.global_transform.affine_inverse()*pose
	car.freeze = true
	car.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	car.traffic_controlled = true
	_active.add_child(car)
	if transfer.is_empty() and prefer_offscreen_spawns and get_viewport().get_camera_3d() != null and _car_visible(car):
		car.free()
		return null
	car.health_label.visible = show_health_labels
	car.traffic_released.connect(_on_traffic_released)
	_owned.append(weakref(car))
	query.exclude = [car.get_rid()]
	_cars.append({"car":car,"lane":lane_id,"progress":progress,"speed":0.0,
		"entry":entry,"traffic_id":_allocate_traffic_id() if transfer.is_empty() else transfer.traffic_id,
		"cruise":randf_range(minimum_speed,maxf(minimum_speed,maximum_speed)),
		"following_gap":gap,"intersection_speed":randf_range(minimum_intersection_speed,maxf(minimum_intersection_speed,maximum_intersection_speed)),
		"half_length":half_length,"stop_at":stop_at,"query":query,
		"probe_offset":collision.position,"height":position_in_city.y,"basis":basis_in_city,
		"heading_offset":deg_to_rad(entry.heading_offset_degrees),"connection":{},"chosen_exit":{},
		"crossing_progress":0.0,"wait_time":0.0,"arrival":-1,"reserved_junction":-1,
		"id":car.get_instance_id(),"outside_time":0.0,"stopped_time":0.0})
	if not transfer.is_empty():
		var record: Dictionary = _cars[-1]
		for key in ["speed","cruise","following_gap","intersection_speed","connection","crossing_progress"]:
			record[key] = transfer[key]
		car.traffic_speed = record.speed
		if not crossing.is_empty():
			record.reserved_junction = lane.junction
			_junction_owners[lane.junction] = record.id
	return car

func _allocate_traffic_id() -> int:
	_next_traffic_id += 1
	return _next_traffic_id

func _drive(record: Dictionary, delta: float) -> void:
	var car: Vehicle = record.car
	var lane: Dictionary = lanes[record.lane]
	if record.connection.is_empty() and record.progress >= record.stop_at-0.05:
		_wait_at_junction(record,delta)
	if not record.connection.is_empty():
		var started := PERF.begin(self)
		_drive_crossing(record,delta)
		PERF.finish(&"traffic_junction_movement",started)
		return
	var remaining: float = maxf(0.0,record.stop_at-record.progress)
	for other in _cars:
		if not other.connection.is_empty(): continue
		if other.car == car or other.lane != record.lane or other.progress <= record.progress: continue
		if not is_instance_valid(other.car) or not other.car.traffic_controlled: continue
		remaining = minf(remaining,maxf(0.0,other.progress-record.progress-record.half_length-other.half_length-record.following_gap))
	# A single bounded sweep each physics tick; wait rather than search around obstacles.
	var query: PhysicsShapeQueryParameters3D = record.query
	query.transform = car.global_transform*Transform3D(Basis.IDENTITY,record.probe_offset)
	var lookahead: float = record.following_gap+record.speed*delta+record.speed*record.speed/(2.0*maxf(braking,0.1))
	var forward: Vector3 = (get_parent().global_basis*lane.forward).normalized()
	query.motion = forward*lookahead
	var started := PERF.begin(self)
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	# cast_motion ignores shapes already overlapping at the starting position.
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): remaining = 0.0
	PERF.finish(&"traffic_obstacle_sweep",started)
	if fractions[0] < 1.0: remaining = minf(remaining,maxf(0.0,lookahead*fractions[0]-record.following_gap))
	var desired := minf(record.cruise,sqrt(2.0*maxf(braking,0.1)*remaining))
	record.speed = move_toward(record.speed,desired,(acceleration if desired > record.speed else braking)*delta)
	var travel := minf(record.speed*delta,remaining)
	if travel <= 0.0001: record.speed = 0.0
	record.progress += travel
	var point: Vector3 = lane.start+lane.forward*record.progress
	point.y = record.height
	car.global_transform = get_parent().global_transform*Transform3D(record.basis,point)
	car.traffic_speed = record.speed

func _wait_at_junction(record: Dictionary, delta: float) -> void:
	var lane: Dictionary = lanes[record.lane]
	if lane.connections.is_empty(): return # A genuine road end, not a missing transition.
	if record.arrival < 0:
		record.arrival = _next_arrival
		_next_arrival += 1
		record.chosen_exit = _choose_connection(lane.connections)
	record.wait_time += delta
	if record.wait_time < intersection_pause or _junction_owners.has(lane.junction): return
	if not junction_lane_allowed(lane): return
	for other in _cars:
		if other.arrival >= 0 and other.arrival < record.arrival and other.connection.is_empty() and lanes[other.lane].junction == lane.junction:
			# A vehicle waiting at a red light cannot block the green approach's queue.
			if is_instance_valid(other.car) and other.car.traffic_controlled and junction_lane_allowed(lanes[other.lane]): return
	if not _exit_clear(record,record.chosen_exit): return
	_junction_owners[lane.junction] = record.id
	record.reserved_junction = lane.junction
	record.connection = record.chosen_exit
	record.crossing_progress = record.progress-lane.length
	record.speed = 0.0

func junction_control_kind(lane: Dictionary) -> String:
	if not is_instance_valid(_traffic_controls):
		_traffic_controls=get_tree().get_first_node_in_group(&"city_traffic_controls")
	return _traffic_controls.control_kind(lane) if is_instance_valid(_traffic_controls) else ""

func junction_lane_allowed(lane: Dictionary) -> bool:
	if junction_control_kind(lane)!="signal": return true
	return _traffic_controls.allows_lane(lane)

func _choose_connection(connections: Array) -> Dictionary:
	var total := 0.0
	for connection in connections: total += straight_ahead_weight if connection.straight else 1.0
	if total <= 0.0: return connections[0] # Straight-only junction even if preference is zero.
	var roll := randf()*total
	for connection in connections:
		roll -= straight_ahead_weight if connection.straight else 1.0
		if roll < 0.0: return connection
	return connections[-1]

func _exit_clear(record: Dictionary, connection: Dictionary) -> bool:
	var clearance: float = record.half_length+junction_stop_margin
	for other in _cars:
		if other.id == record.id or not is_instance_valid(other.car) or not other.car.traffic_controlled: continue
		if other.lane == connection.to and other.progress < clearance+record.half_length+other.half_length+record.following_gap: return false
	# Physical wrecks and other obstacles can also occupy the exit.
	var lane: Dictionary = lanes[connection.to]
	var point: Vector3 = lane.start+lane.forward*clearance
	point.y = record.height
	var pose := _pose(point,lane.forward,record.heading_offset)
	var query: PhysicsShapeQueryParameters3D = record.query
	query.transform = pose*Transform3D(Basis.IDENTITY,record.probe_offset)
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _crossing_point(record: Dictionary, distance: float) -> Vector3:
	var connection: Dictionary = record.connection
	var source: Dictionary = lanes[record.lane]
	var target: Dictionary = lanes[connection.to]
	var point: Vector3
	if distance < 0.0:
		point = source.end+source.forward*distance
	elif distance > connection.length:
		point = target.start+target.forward*(distance-connection.length)
	else:
		point = connection.curve.sample_baked(distance)
	point.y = record.height
	return point

func _pose(point: Vector3, forward: Vector3, heading: float) -> Transform3D:
	return get_parent().global_transform*Transform3D(Basis(Vector3.UP,atan2(forward.x,forward.z)+heading),point)

func _drive_crossing(record: Dictionary, delta: float) -> void:
	var car: Vehicle = record.car
	var connection: Dictionary = record.connection
	var finish: float = connection.length+record.half_length+junction_stop_margin
	var remaining: float = maxf(0.0,finish-record.crossing_progress)
	var lookahead: float = record.following_gap+record.speed*delta+record.speed*record.speed/(2.0*maxf(braking,0.1))
	var query: PhysicsShapeQueryParameters3D = record.query
	query.transform = car.global_transform*Transform3D(Basis.IDENTITY,record.probe_offset)
	# Sweep toward a point on the planned turn, not straight through its outside wall.
	query.motion = get_parent().to_global(_crossing_point(record,record.crossing_progress+lookahead))-car.global_position
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	if fractions[0] < 1.0: remaining = minf(remaining,maxf(0.0,lookahead*fractions[0]-record.following_gap))
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): remaining = 0.0
	var desired := minf(record.cruise,record.intersection_speed)
	if fractions[0] < 1.0: desired = minf(desired,sqrt(2.0*maxf(braking,0.1)*remaining))
	record.speed = move_toward(record.speed,desired,(acceleration if desired > record.speed else braking)*delta)
	var travel := minf(record.speed*delta,remaining)
	var progress: float = record.crossing_progress+travel
	var point := _crossing_point(record,progress)
	var tangent := (_crossing_point(record,progress+0.05)-_crossing_point(record,progress-0.05)).normalized()
	var pose := _pose(point,tangent,record.heading_offset)
	# Also check the next orientation, since a translating box sweep doesn't rotate.
	query.transform = pose*Transform3D(Basis.IDENTITY,record.probe_offset)
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		travel = 0.0
	if travel <= 0.0001:
		record.speed = 0.0
	else:
		record.crossing_progress = progress
		car.global_transform = pose
	car.traffic_speed = record.speed
	if record.crossing_progress >= finish-0.001:
		record.lane = connection.to
		record.progress = record.crossing_progress-connection.length
		record.stop_at = lanes[record.lane].length-record.half_length-junction_stop_margin
		record.basis = Basis(Vector3.UP,atan2(lanes[record.lane].forward.x,lanes[record.lane].forward.z)+record.heading_offset)
		record.connection = {}
		record.chosen_exit = {}
		record.wait_time = 0.0
		record.arrival = -1
		_release_junction(record)
		crossings_completed += 1

func _release_junction(record: Dictionary) -> void:
	if _junction_owners.get(record.reserved_junction,-1) == record.id:
		_junction_owners.erase(record.reserved_junction)
	record.reserved_junction = -1

func _on_traffic_released(car: Vehicle) -> void:
	_abandoned[car.get_instance_id()] = {"vehicle":weakref(car),"elapsed":0.0}
	for record in _cars:
		if record.id == car.get_instance_id(): _release_junction(record)
	# Pickup stores this parent for release. Move it before pickup reparents it again.
	if car.get_parent() == _active: car.reparent(_released)

func _draw_lanes() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffad32")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
	for lane in lanes:
		mesh.surface_add_vertex(to_local(get_parent().to_global(lane.start+Vector3.UP*0.12)))
		mesh.surface_add_vertex(to_local(get_parent().to_global(lane.end+Vector3.UP*0.12)))
		for connection in lane.connections:
			var points: PackedVector3Array = connection.curve.get_baked_points()
			for i in range(1,points.size()):
				mesh.surface_add_vertex(to_local(get_parent().to_global(points[i-1]+Vector3.UP*0.12)))
				mesh.surface_add_vertex(to_local(get_parent().to_global(points[i]+Vector3.UP*0.12)))
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

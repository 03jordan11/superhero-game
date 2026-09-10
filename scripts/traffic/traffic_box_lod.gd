extends Node3D
## Visual traffic only. Regional MultiMeshes share silhouette/rectangle meshes and one material.
const PERF = preload("res://scripts/ui-scripts/vehicle_performance_monitor.gd")
const PROXY_MESH = preload("res://scripts/traffic/traffic_proxy_mesh.gd")

@export var enabled := true
@export_category("Distant Coverage")
@export_range(300.0,2000.0,50.0) var view_distance := 900.0
@export_range(0,1000,1) var population_target := 160
@export_range(0,1500,1) var max_boxes := 240
@export_range(20.0,300.0,10.0) var retention_margin := 100.0
@export_range(0.0,10.0,0.5) var retire_delay := 2.0
@export_range(5.0,120.0,1.0) var terminal_recycle_delay := 15.0
@export_category("Very Distant Traffic (Tier 3)")
@export var far_enabled := true
## Outer horizontal coverage; never smaller than View Distance.
@export_range(500.0,4000.0,50.0) var far_view_distance := 1800.0
## Additional population outside the original horizontal View Distance.
@export_range(0,1500,1) var far_population_target := 200
## Additional proxy capacity, added to Max Boxes. Movement across the boundary shares this total cap.
@export_range(0,2000,1) var far_max_proxies := 320
## Actual 3D distance: return to a silhouette inside this radius.
@export_range(300.0,3000.0,50.0) var far_promote_distance := 800.0
## Actual 3D distance: become a flat rectangle beyond this radius (at least 50 m above promotion).
@export_range(400.0,3500.0,50.0) var far_demote_distance := 1000.0
@export_category("Full Vehicle Transition")
@export_range(50.0,500.0,10.0) var promote_distance := 150.0
@export_range(60.0,600.0,10.0) var demote_distance := 220.0
@export_range(0.0,3.0,0.1) var approach_lead_seconds := 1.0
@export_range(0.0,10.0,0.25) var demote_delay := 1.0
## Hide a blocked proxy this close, rather than show a car the player can pass through.
@export_range(15.0,80.0,5.0) var interaction_guard_distance := 35.0
@export_range(0.05,1.0,0.05) var transition_interval := 0.1
## Budget per direction per check, including failed promotion attempts.
@export_range(1,8,1) var transitions_per_check := 2
@export_category("Population Work")
@export_range(0.1,2.0,0.05) var population_interval := 0.25
@export_range(1,16,1) var spawns_per_update := 4
@export_range(1,40,1) var spawn_attempts_per_update := 20
@export_range(5.0,80.0,1.0) var initial_spacing := 20.0
@export_category("Rendering (Restart to Rebuild)")
@export_range(100.0,500.0,25.0) var region_size := 250.0
@export_category("Car Silhouette (Restart to Rebuild)")
## Fraction of total vehicle height occupied by the lower body.
@export_range(0.25,0.8,0.05) var body_height_ratio := 0.55
@export_range(0.4,1.0,0.05) var cabin_width_ratio := 0.8
@export_range(0.25,0.85,0.05) var cabin_length_ratio := 0.5
## Fraction of total length; negative moves the cabin toward the rear (-Z).
@export_range(-0.25,0.25,0.01) var cabin_offset_ratio := -0.08
## Window tint multiplier. The body and roof retain the selected vehicle paint.
@export_range(0.0,0.4,0.02) var window_brightness := 0.12

var proxies: Array[Dictionary] = []
var promotions := 0
var demotions := 0
var blocked_promotions := 0
var hidden_count := 0
var silhouette_count := 0
var rectangle_count := 0
var flat_promotions := 0
var flat_demotions := 0
var _manager: Node3D
var _city: Node3D
var _metadata: Dictionary = {}
var _straight: Array[Dictionary] = []
var _batches: Dictionary = {}
var _mesh: ArrayMesh
var _flat_mesh := PlaneMesh.new()
var _transition_timer := 0.0
var _population_timer := 0.0
var _demotions_left := 0
var _promotion_radius := 150.0
var _previous_focus := Vector3.ZERO
var _had_focus := false
var _region_size := 250.0
var _population_baseline: Dictionary = {}

func apply_population_settings(density: float, distance: float) -> void:
	if _population_baseline.is_empty():
		for key in ["view_distance", "far_view_distance", "population_target", "max_boxes", "far_population_target", "far_max_proxies"]:
			_population_baseline[key] = get(key)
	var base_near: float = _population_baseline.view_distance
	var base_far: float = maxf(base_near, _population_baseline.far_view_distance)
	# Preserve room for full vehicles and their maximum approach lead.
	var near_floor := maxf(_manager.spawn_radius+40.0, maxf(demote_distance+40.0, maxf(promote_distance,interaction_guard_distance)+190.0))
	view_distance = minf(base_near, maxf(near_floor, base_near*clampf(distance,0.0,1.0)))
	far_view_distance = maxf(view_distance, base_far*clampf(distance,0.0,1.0))
	if distance >= 1.0: far_view_distance = _population_baseline.far_view_distance
	# Approximate road coverage by area. A smaller ring must not squeeze its
	# original population into the streets that remain.
	var near_area := pow(view_distance/maxf(base_near,1.0), 2.0)
	var base_ring := base_far*base_far-base_near*base_near
	var ring_area := clampf((far_view_distance*far_view_distance-view_distance*view_distance)/maxf(base_ring,1.0),0.0,1.0)
	if distance >= 1.0: ring_area = 1.0
	population_target = roundi(_population_baseline.population_target*density*near_area)
	max_boxes = roundi(_population_baseline.max_boxes*density*near_area)
	far_population_target = roundi(_population_baseline.far_population_target*density*ring_area)
	far_max_proxies = roundi(_population_baseline.far_max_proxies*density*ring_area)
	_population_timer = 0.0

func setup(manager: Node3D) -> void:
	_manager = manager
	_city = manager.get_parent()
	_region_size = maxf(region_size,100.0)
	_mesh = PROXY_MESH.build(body_height_ratio,cabin_width_ratio,cabin_length_ratio,cabin_offset_ratio,window_brightness)
	_flat_mesh.size = Vector2.ONE
	_flat_mesh.material = _mesh.surface_get_material(0)
	for lane in _manager.lanes:
		var straight: Dictionary = {}
		for connection in lane.connections:
			# Only truly aligned roads qualify for a straight-only proxy.
			var offset: Vector3 = _manager.lanes[connection.to].start-lane.end
			if connection.straight and offset.cross(lane.forward).length() < 0.1:
				straight = connection
				break
		_straight.append(straight)
	# Inspect each entry once without adding its scene to the tree or running _ready.
	for entry in _manager.vehicle_entries:
		if entry != null and entry.scene != null: _get_metadata(entry)

func _get_metadata(entry: Resource) -> Dictionary:
	if _metadata.has(entry): return _metadata[entry]
	var result: Dictionary = {}
	var instance = entry.scene.instantiate()
	if instance is Vehicle:
		var visual := instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
		var collision := instance.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if visual != null and visual.mesh != null and collision != null and collision.shape is BoxShape3D:
			var bounds: AABB = visual.transform*visual.get_aabb()
			var size: Vector3 = collision.shape.size*collision.scale.abs()
			result = {"size":bounds.size,"center":bounds.get_center(),
				"half_length":size.z*0.5+absf(collision.position.z),
				"height":_manager.road_height+maxf(0.0,size.y*0.5-collision.position.y)+0.02}
	instance.free()
	_metadata[entry] = result
	return result

func wants_full(point: Vector3) -> bool:
	return is_instance_valid(_manager._focus) and point.distance_to(_manager._focus.global_position) <= _promotion_radius

func _coverage_radius() -> float:
	return maxf(view_distance,far_view_distance) if far_enabled else view_distance

func _proxy_limit() -> int:
	return maxi(0,max_boxes)+maxi(0,far_max_proxies) if far_enabled else maxi(0,max_boxes)

func _population_counts() -> Vector2i:
	var counts := Vector2i.ZERO
	for record in proxies:
		var outer: bool = far_enabled and _manager._flat_distance(_city.to_global(_point(record)),_manager._focus.global_position) > view_distance
		counts[int(outer)] += 1
	return counts

func _update_tier(record: Dictionary, point: Vector3) -> void:
	var was_flat: bool = record.get("flat",false)
	var flat := was_flat
	var return_distance := maxf(far_promote_distance,_promotion_radius+40.0)
	var enter_distance := maxf(far_demote_distance,return_distance+50.0)
	var distance: float = point.distance_to(_manager._focus.global_position)
	if not far_enabled or distance <= return_distance: flat = false
	elif distance >= enter_distance: flat = true
	if record.has("flat") and flat != was_flat:
		if flat: flat_demotions += 1
		else: flat_promotions += 1
	record["flat"] = flat

func _point(record: Dictionary) -> Vector3:
	if not record.connection.is_empty(): return _manager._crossing_point(record,record.crossing_progress)
	var lane: Dictionary = _manager.lanes[record.lane]
	var point: Vector3 = lane.start+lane.forward*record.progress
	point.y = record.height
	return point

func _visible(record: Dictionary) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return true
	var pose: Transform3D = _manager._pose(_point(record),_manager.lanes[record.lane].forward,record.heading_offset)
	var data: Dictionary = _get_metadata(record.entry)
	var bounds := AABB(data.center-data.size*0.5,data.size)
	if camera.is_position_in_frustum(pose*bounds.get_center()): return true
	for i in range(8):
		if camera.is_position_in_frustum(pose*bounds.get_endpoint(i)): return true
	return false

func step(delta: float) -> void:
	var started := PERF.begin(self)
	_step(delta)
	PERF.finish(&"traffic_box_simulation",started)

func _step(delta: float) -> void:
	if not enabled or not _manager.traffic_enabled:
		proxies.clear()
		_demotions_left = 0
		_had_focus = false
		return
	if not is_instance_valid(_manager._focus):
		_had_focus = false
		return
	var focus: Vector3 = _manager._focus.global_position
	var velocity := Vector3.ZERO
	if _manager._focus is CharacterBody3D:
		velocity = _manager._focus.velocity
	elif _had_focus and delta > 0.0:
		velocity = (focus-_previous_focus)/delta
	_previous_focus = focus
	_had_focus = true
	_promotion_radius = maxf(promote_distance,interaction_guard_distance)+minf(velocity.length()*approach_lead_seconds,150.0)
	_transition_timer -= delta
	var check_transitions := _transition_timer <= 0.0
	if check_transitions:
		_transition_timer = maxf(transition_interval,0.05)
		_demotions_left = transitions_per_check
		# Nearer vehicles get the limited promotion slots first.
		proxies.sort_custom(func(a,b): return _city.to_global(_point(a)).distance_squared_to(focus) < _city.to_global(_point(b)).distance_squared_to(focus))
	var attempts := transitions_per_check if check_transitions else 0
	var removed := 0
	var counts := _population_counts()
	for i in range(proxies.size()-1,-1,-1):
		var record: Dictionary = proxies[i]
		var world_point := _city.to_global(_point(record))
		var horizontal_distance: float = _manager._flat_distance(world_point,focus)
		var band := int(far_enabled and horizontal_distance > view_distance)
		var target := mini(far_population_target,far_max_proxies) if band == 1 else mini(population_target,max_boxes)
		var outside: bool = horizontal_distance > _coverage_radius()+retention_margin
		record.outside_time = record.outside_time+delta if outside else 0.0
		var excess: bool = counts[band] > target or proxies.size() > _proxy_limit()
		if removed < spawns_per_update and ((outside and record.outside_time >= retire_delay) or (record.stopped_time >= terminal_recycle_delay and not _visible(record)) or (excess and not _visible(record))):
			proxies.remove_at(i)
			counts[band] -= 1
			removed += 1
	# Forward order for near-first promotion, remove by identity after iteration.
	var promoted: Array[Dictionary] = []
	for record in proxies:
		var world_point := _city.to_global(_point(record))
		_update_tier(record,world_point)
		var near := wants_full(world_point)
		record.hidden = near and world_point.distance_to(focus) <= interaction_guard_distance
		if near:
			if attempts > 0 and _manager._owned.size() < _manager.max_vehicles:
				attempts -= 1
				var car: Vehicle = _manager._spawn_vehicle(record.entry,record.lane,record.progress,record)
				if car != null:
					promoted.append(record)
					promotions += 1
				else:
					blocked_promotions += 1
			# Hold until space/capacity is available. Never ghost through close obstacles.
			continue
		record.hidden = false
		_advance(record,delta)
	for record in promoted: proxies.erase(record)
	_population_timer -= delta
	if _population_timer <= 0.0:
		_population_timer = maxf(population_interval,0.1)
		_seed_nearby()
		if far_enabled: _seed_nearby(true)

func _advance(record: Dictionary, delta: float) -> void:
	var lane: Dictionary = _manager.lanes[record.lane]
	var lane_speed: float = (_manager.minimum_speed+maxf(_manager.minimum_speed,_manager.maximum_speed))*0.5
	record.speed = move_toward(record.speed,lane_speed,_manager.acceleration*delta)
	var travel: float = record.speed*delta
	if not record.connection.is_empty():
		record.crossing_progress += travel
		var finish: float = record.connection.length+record.half_length+_manager.junction_stop_margin
		if record.crossing_progress >= finish:
			record.lane = record.connection.to
			record.progress = record.crossing_progress-record.connection.length
			record.connection = {}
		return
	var stop_at: float = lane.length-record.half_length-_manager.junction_stop_margin
	if _straight[record.lane].is_empty():
		record.progress = minf(record.progress+travel,stop_at)
		if record.progress >= stop_at:
			record.speed = 0.0
			record.stopped_time += delta
		return
	record.progress += travel
	if record.progress >= lane.length:
		record.connection = _straight[record.lane]
		record.crossing_progress = record.progress-lane.length

func try_demote(record: Dictionary, delta: float) -> bool:
	if not enabled or not _manager.traffic_enabled or not is_instance_valid(_manager._focus): return false
	var car: Vehicle = record.car
	var far := car.global_position.distance_to(_manager._focus.global_position) > maxf(demote_distance,_promotion_radius+40.0)
	record["lod_far_time"] = record.get("lod_far_time",0.0)+delta if far else 0.0
	if not far or record.lod_far_time < demote_delay or _demotions_left <= 0 or proxies.size() >= _proxy_limit(): return false
	if not record.connection.is_empty() or car.get_current_health() < car.get_max_health(): return false
	if _manager._flat_distance(car.global_position,_manager._focus.global_position) > _coverage_radius(): return false
	if _get_metadata(record.entry).is_empty(): return false
	var proxy: Dictionary = {}
	for key in ["entry","traffic_id","lane","progress","speed","cruise","following_gap","intersection_speed","half_length","height","heading_offset"]:
		proxy[key] = record[key]
	proxy.merge({"connection":{},"crossing_progress":0.0,"outside_time":0.0,"stopped_time":0.0,"hidden":false})
	_update_tier(proxy,car.global_position)
	proxies.append(proxy)
	_demotions_left -= 1
	demotions += 1
	return true

func keeps_for_lod(record: Dictionary) -> bool:
	if not enabled or not _manager.traffic_enabled or not is_instance_valid(_manager._focus): return false
	if _manager._flat_distance(record.car.global_position,_manager._focus.global_position) > _coverage_radius(): return false
	# Finish crossings even if the box cap is full; preserve normal retirement for damaged cars.
	return not record.connection.is_empty() or (proxies.size() < _proxy_limit() and record.car.get_current_health() >= record.car.get_max_health())

func blocks_spawn(lane: int, progress: float, half_length: float, gap: float, ignored_id: int) -> bool:
	for record in proxies:
		if record.traffic_id == ignored_id: continue
		if record.lane != lane: continue
		var required: float = gap if progress < record.progress else record.following_gap
		if absf(progress-record.progress) < half_length+record.half_length+required: return true
	return false

func _seed_nearby(outer_band: bool = false) -> void:
	var target := mini(far_population_target,far_max_proxies) if outer_band else mini(population_target,max_boxes)
	var count := _population_counts()[int(outer_band)]
	if count >= target or proxies.size() >= _proxy_limit(): return
	var radius := _coverage_radius() if outer_band else view_distance
	var center: Vector3 = _city.to_local(_manager._focus.global_position)
	var candidates: Array[Dictionary] = []
	var total := 0.0
	for i in range(_manager.lanes.size()):
		var lane: Dictionary = _manager.lanes[i]
		var along: float = (center-lane.start).dot(lane.forward)
		var lateral: float = _manager._flat_distance(center,lane.start+lane.forward*along)
		if lateral >= radius: continue
		var reach := sqrt(radius*radius-lateral*lateral)
		var interval := Vector2(maxf(8.0,along-reach),minf(lane.length-15.0,along+reach))
		if interval.y <= interval.x: continue
		total += interval.y-interval.x
		candidates.append({"lane":i,"interval":interval,"weight":total})
	if candidates.is_empty(): return
	var added := 0
	for attempt in range(spawn_attempts_per_update):
		if added >= spawns_per_update or count+added >= target or proxies.size() >= _proxy_limit(): break
		var roll := randf()*total
		var candidate: Dictionary = candidates[-1]
		for option in candidates:
			if option.weight >= roll:
				candidate = option
				break
		var lane: Dictionary = _manager.lanes[candidate.lane]
		var progress := randf_range(candidate.interval.x,candidate.interval.y)
		var point: Vector3 = lane.start+lane.forward*progress
		var world_point := _city.to_global(point)
		if outer_band and _manager._flat_distance(world_point,_manager._focus.global_position) <= view_distance: continue
		if world_point.distance_to(_manager._focus.global_position) <= maxf(demote_distance,_promotion_radius+40.0): continue
		var entry = _manager._choose_entry()
		if entry == null: return
		var data := _get_metadata(entry)
		if data.is_empty() or progress >= lane.length-data.half_length-_manager.junction_stop_margin: continue
		if blocks_spawn(candidate.lane,progress,data.half_length,initial_spacing,-1): continue
		var occupied := false
		for full in _manager._cars:
			if full.lane == candidate.lane and absf(full.progress-progress) < data.half_length+full.half_length+initial_spacing:
				occupied = true
				break
		if occupied: continue
		proxies.append({"entry":entry,"traffic_id":_manager._allocate_traffic_id(),"lane":candidate.lane,
			"progress":progress,"speed":(_manager.minimum_speed+_manager.maximum_speed)*0.5,
			"cruise":randf_range(_manager.minimum_speed,maxf(_manager.minimum_speed,_manager.maximum_speed)),
			"following_gap":randf_range(_manager.minimum_following_gap,maxf(_manager.minimum_following_gap,_manager.maximum_following_gap)),
			"intersection_speed":randf_range(_manager.minimum_intersection_speed,maxf(_manager.minimum_intersection_speed,_manager.maximum_intersection_speed)),
			"half_length":data.half_length,"height":data.height,"heading_offset":deg_to_rad(entry.heading_offset_degrees),
			"connection":{},"crossing_progress":0.0,"outside_time":0.0,"stopped_time":0.0,"hidden":false})
		_update_tier(proxies[-1],world_point)
		added += 1

func draw_boxes() -> void:
	var started := PERF.begin(self)
	# Match the city's coordinates even if the manager has an organizational transform.
	global_transform = _city.global_transform
	var groups: Dictionary = {}
	hidden_count = 0
	silhouette_count = 0
	rectangle_count = 0
	for record in proxies:
		if record.hidden:
			hidden_count += 1
			continue
		var point := _point(record)
		var flat: bool = record.get("flat",false)
		if flat: rectangle_count += 1
		else: silhouette_count += 1
		var cell := Vector3i(floori(point.x/_region_size),floori(point.z/_region_size),int(flat))
		if not groups.has(cell): groups[cell] = []
		groups[cell].append(record)
	for cell in _batches.keys():
		if not groups.has(cell):
			_batches[cell].visible = false
			_batches[cell].queue_free()
			_batches.erase(cell)
	for cell in groups:
		var records: Array = groups[cell]
		var batch: MultiMeshInstance3D
		if not _batches.has(cell):
			batch = MultiMeshInstance3D.new()
			batch.name = "Region_%d_%d_Tier%d" % [cell.x,cell.y,cell.z+2]
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.use_colors = true
			batch.multimesh.mesh = _flat_mesh if cell.z == 1 else _mesh
			add_child(batch)
			batch.position = Vector3(cell.x*_region_size,0,cell.y*_region_size)
			_batches[cell] = batch
		else:
			batch = _batches[cell]
		var mm := batch.multimesh
		if mm.instance_count < records.size(): mm.instance_count = maxi(16,records.size()*2)
		mm.visible_instance_count = records.size()
		# Include dimensions/height of every box, and avoid implicit engine bounds rebuilding.
		var bounds := AABB()
		for i in range(records.size()):
			var record: Dictionary = records[i]
			var data := _get_metadata(record.entry)
			var forward: Vector3 = _manager.lanes[record.lane].forward
			var basis := Basis(Vector3.UP,atan2(forward.x,forward.z)+record.heading_offset)
			var box_transform := Transform3D(basis.scaled_local(data.size),_point(record)+basis*data.center-batch.position)
			mm.set_instance_transform(i,box_transform)
			mm.set_instance_color(i,record.entry.distant_color)
			var box_bounds: AABB = box_transform*AABB(Vector3.ONE*-0.5,Vector3.ONE)
			bounds = box_bounds if i == 0 else bounds.merge(box_bounds)
		mm.custom_aabb = bounds.grow(1.0)
	PERF.finish(&"traffic_box_render_update",started)

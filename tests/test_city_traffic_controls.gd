extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Traffic-controls removal test timed out"); quit(1))
	var city:=Node3D.new()
	root.add_child(city)
	current_scene=city
	var life=load("res://scenes/city_life.tscn").instantiate()
	city.add_child(life)
	life.set_process(false)
	life.blimp_ad_audio_enabled=false
	var focus:=Node3D.new()
	focus.name="Focus"
	city.add_child(focus)
	var manager=load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.focus_path=^"../Focus"
	manager.prefer_offscreen_spawns=false
	city.add_child(manager)
	manager.set_physics_process(false)
	manager._timer=1000000
	var lod=manager.get_node("DistantTraffic")
	lod._population_timer=1000000
	await physics_frame
	await physics_frame
	check(not life.has_node("TrafficControls"),"Traffic-control props are absent")
	check(get_nodes_in_group(&"city_traffic_controls").is_empty(),"No signal controller remains registered")
	var lane_id: int=-1
	for i in manager.lanes.size():
		var lane: Dictionary=manager.lanes[i]
		check(manager.junction_control_kind(lane).is_empty() and manager.junction_lane_allowed(lane),"Road approaches do not wait for removed signals")
		if lane_id<0 and not lod._straight[i].is_empty(): lane_id=i
	check(lane_id>=0,"Traffic road connections remain available")
	if lane_id<0: quit(1); return
	var lane: Dictionary=manager.lanes[lane_id]
	focus.position=lane.end
	var car=manager._spawn_vehicle(manager.vehicle_entries[0],lane_id,lane.length-12)
	check(car!=null,"Physical traffic still spawns")
	if car==null: quit(1); return
	var record: Dictionary=manager._cars[0]
	manager._wait_at_junction(record,manager.intersection_pause*0.5)
	check(record.connection.is_empty(),"Normal intersection pause is preserved")
	manager._wait_at_junction(record,manager.intersection_pause+0.1)
	check(not record.connection.is_empty(),"Vehicle enters intersection without a signal provider")
	check(manager._junction_owners.size()==1,"Crossing keeps its junction reservation")
	for step in 500:
		if record.connection.is_empty(): break
		manager._drive_crossing(record,0.1)
	check(manager.crossings_completed==1,"Physical vehicle completes the crossing")
	check(manager._junction_owners.is_empty(),"Completed crossing releases the junction")
	var distant:=proxy(lane_id,lane.length-2-manager.junction_stop_margin)
	lod.proxies.assign([distant])
	for step in 300: lod._advance(distant,0.1)
	check(distant.lane!=lane_id,"Distant traffic still crosses intersections")
	print("Traffic-controls removal: %d failures"%failures)
	city.free()
	quit(0 if failures==0 else 1)

func proxy(lane_id: int, progress: float) -> Dictionary:
	return {"lane":lane_id,"progress":progress,"speed":8.0,"cruise":8.0,"half_length":2.0,"height":1.0,"connection":{},"crossing_progress":0.0,"stopped_time":0.0}

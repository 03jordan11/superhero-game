extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Signal test timed out"); quit(1))
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
	var junction: int=-1
	var red_lane: int=-1
	var green_lane: int=-1
	var stop_lane: int=-1
	for i in manager.lanes.size():
		var lane: Dictionary=manager.lanes[i]
		if lod._straight[i].is_empty(): continue
		if manager.junction_control_kind(lane)=="stop": stop_lane=i
		if manager.junction_control_kind(lane)!="signal": continue
		if junction<0: junction=lane.junction
		if lane.junction!=junction: continue
		if absf(lane.forward.x)>0.5: red_lane=i
		else: green_lane=i
	check(red_lane>=0 and green_lane>=0 and stop_lane>=0,"Controlled lanes match the generated road network")
	if red_lane<0 or green_lane<0 or stop_lane<0: quit(1); return
	var offset: float=life.controls[junction].offset
	for step in 184:
		life.elapsed=46-offset+step*0.25
		check(not (life.signal_color(junction,0)==2 and life.signal_color(junction,1)==2),"Conflicting approaches never receive green together")
	life.elapsed=46-offset+18.5
	check(life.signal_color(junction,1)==1 and not manager.junction_lane_allowed(manager.lanes[green_lane]),"Amber holds new arrivals")
	life.elapsed=46-offset+21.5
	check(life.signal_color(junction,0)==0 and life.signal_color(junction,1)==0,"All-red clearance between phases")
	life.elapsed=46-offset
	var red: Dictionary=manager.lanes[red_lane]
	var green: Dictionary=manager.lanes[green_lane]
	focus.position=red.end
	var car_a=manager._spawn_vehicle(manager.vehicle_entries[0],red_lane,red.length-12)
	var car_b=manager._spawn_vehicle(manager.vehicle_entries[0],green_lane,green.length-12)
	check(car_a!=null and car_b!=null,"Physical traffic can spawn at signal approaches")
	if car_a==null or car_b==null: quit(1); return
	var a: Dictionary=manager._cars[0]
	var b: Dictionary=manager._cars[1]
	manager._wait_at_junction(a,manager.intersection_pause+0.1)
	check(a.connection.is_empty(),"Full vehicle waits for red")
	manager._wait_at_junction(b,manager.intersection_pause+0.1)
	check(not b.connection.is_empty(),"Green vehicle is not deadlocked behind an older red arrival")
	check(manager._junction_owners.size()==1,"Signals preserve the crossing reservation")
	car_b.leave_traffic()
	car_a.leave_traffic()
	car_a.free()
	car_b.free()
	manager._cars.clear()
	await physics_frame
	var front:=proxy(red_lane,red.length-2-manager.junction_stop_margin)
	var following:=proxy(red_lane,front.progress-12)
	lod.proxies.assign([front,following])
	for step in 100:
		lod._advance(front,0.1)
		lod._advance(following,0.1)
	check(front.lane!=red_lane,"Distant vehicle ignores red and completes the crossing")
	life.elapsed=46-offset+23
	for step in 160:
		lod._advance(front,0.1)
		lod._advance(following,0.1)
	check(front.lane!=red_lane,"Distant traffic resumes and completes the crossing on green")
	var stop: Dictionary=manager.lanes[stop_lane]
	var stopped:=proxy(stop_lane,stop.length-2-manager.junction_stop_margin)
	var initial: float=stopped.progress
	lod._advance(stopped,manager.intersection_pause*0.5)
	check(stopped.progress>initial or not stopped.connection.is_empty(),"Distant cars ignore stop signs")
	for step in 300: lod._advance(stopped,0.1)
	check(stopped.lane!=stop_lane,"Stop-sign traffic resumes")
	life.traffic_controls_enabled=false
	check(manager.junction_lane_allowed(red) and manager.junction_control_kind(red).is_empty(),"Inspector toggle disables controls")
	print("City traffic controls: %d failures"%failures)
	city.free()
	quit(0 if failures==0 else 1)

func proxy(lane_id: int, progress: float) -> Dictionary:
	return {"lane":lane_id,"progress":progress,"speed":8.0,"cruise":8.0,"half_length":2.0,"height":1.0,"connection":{},"crossing_progress":0.0,"stopped_time":0.0}

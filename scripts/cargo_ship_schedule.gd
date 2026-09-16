extends Node
## Deterministic harbor service. The placed ship transform is the exact berth.
## Route points are meters relative to the berth: -Z bow, +X seaward here.
enum Phase { BERTHED, DEPARTING, OFFSHORE, ARRIVING }
@export var enabled:=true
@export_range(0,24,.25,"suffix:h") var first_arrival_hour:=0.0
@export_range(.25,5,.25,"suffix:h") var docked_hours:=3.0
@export_range(.5,5,.25,"suffix:h") var departure_hours:=3.5
@export_range(.5,5,.25,"suffix:h") var approach_hours:=3.5
@export var inbound_points:=PackedVector3Array([
	Vector3(2200,0,-1000),Vector3(650,0,200),Vector3(150,0,550),Vector3(0,0,350),Vector3.ZERO])
@export var outbound_points:=PackedVector3Array([
	Vector3.ZERO,Vector3(0,0,-200),Vector3(280,0,-420),Vector3(700,0,-600),Vector3(2400,0,-1800)])
@export var offshore_points:=PackedVector3Array([
	Vector3(2400,0,-1800),Vector3(3000,0,-2200),Vector3(3100,0,-1500),Vector3(2200,0,-1000)])
var phase: Phase=Phase.BERTHED
var speed_mps:=0.0
var berth_transform:=Transform3D.IDENTITY
var _ship: Node3D
var _clock: Node
var _hours:=0.0
var _inbound: Curve3D
var _outbound: Curve3D
var _offshore: Curve3D
var _berth_hold_remaining:=0.0

func _ready() -> void:
	add_to_group(&"cargo_ship_schedule")
	_ship=get_parent() as Node3D
	berth_transform=_ship.global_transform
	rebuild_routes()
	_bind_clock.call_deferred()

func rebuild_routes() -> void:
	_inbound=_curve(inbound_points,Vector3.ZERO,Vector3.FORWARD)
	_outbound=_curve(outbound_points,Vector3.FORWARD,Vector3.ZERO)
	_straighten(_inbound,inbound_points.size()-2,Vector3.FORWARD)
	_straighten(_outbound,1,Vector3.FORWARD)
	var outgoing: Vector3=(outbound_points[-1]-outbound_points[-2]).normalized()
	var incoming: Vector3=(inbound_points[1]-inbound_points[0]).normalized()
	_offshore=_curve(offshore_points,outgoing,incoming)

func _straighten(curve: Curve3D, index: int, direction: Vector3) -> void:
	var point:=curve.get_point_position(index)
	curve.set_point_in(index,-direction*point.distance_to(curve.get_point_position(index-1))*.25)
	curve.set_point_out(index,direction*point.distance_to(curve.get_point_position(index+1))*.25)

func _curve(points: PackedVector3Array, first_direction: Vector3, last_direction: Vector3) -> Curve3D:
	var curve:=Curve3D.new(); curve.bake_interval=1.0
	for i in points.size():
		var previous: Vector3=points[maxi(0,i-1)]
		var following: Vector3=points[mini(points.size()-1,i+1)]
		var direction: Vector3=(following-previous).normalized()
		if i==0 and not first_direction.is_zero_approx(): direction=first_direction
		if i==points.size()-1 and not last_direction.is_zero_approx(): direction=last_direction
		curve.add_point(points[i],-direction*points[i].distance_to(previous)*.25,direction*points[i].distance_to(following)*.25)
	return curve

func _bind_clock() -> void:
	_clock=get_tree().get_first_node_in_group(&"day_night_cycle")
	if _clock==null: return # Independent ship previews remain stationary.
	_hours=_clock.time_of_day
	if enabled: _apply_hour(_hours,0)

func _physics_process(delta: float) -> void:
	if not enabled: speed_mps=0; return
	if not is_instance_valid(_clock):
		_bind_clock()
		return
	# Integrate at the physics rate instead of moving the platform in 30 Hz jumps
	# from the visual sky clock. Deliberate time commands seek the schedule.
	var rate: float=24.0/(maxf(_clock.day_length_minutes,.5)*60.0)*maxf(_clock.time_scale,0)
	var previous_hour:=_hours
	if _clock.cycle_running:
		_hours=fposmod(_hours+delta*rate,24.0)
		var error:=wrapf(float(_clock.time_of_day)-_hours,-12,12)
		if absf(error)>maxf(rate*.2,.002): _hours=_clock.time_of_day
	else: _hours=_clock.time_of_day
	if _berth_hold_remaining>0.0:
		_berth_hold_remaining=maxf(0.0,_berth_hold_remaining-maxf(0.0,wrapf(_hours-previous_hour,-12,12)))
		if _berth_hold_remaining>0.0:
			_ship.global_transform=berth_transform
			phase=Phase.BERTHED; speed_mps=0; _ship.navigation_mode=2
			return
	_apply_hour(_hours,delta)

func resume_from_berth() -> void:
	# Remain at the rescued berth until the next regular 03:00/15:00 departure.
	if is_instance_valid(_clock): _hours=_clock.time_of_day
	_berth_hold_remaining=fposmod(first_arrival_hour+clampf(docked_hours,.25,5.0)-_hours,12.0)
	_ship.global_transform=berth_transform
	phase=Phase.BERTHED; speed_mps=0; _ship.navigation_mode=2; enabled=true

func sample_schedule(hour: float) -> Dictionary:
	var elapsed:=fposmod(hour-first_arrival_hour,12.0)
	# Keep a positive offshore interval even if Inspector durations overlap.
	var stay:=clampf(docked_hours,.25,5.0)
	var leaving:=clampf(departure_hours,.5,(12.0-stay-.25)*.5)
	var arriving:=clampf(approach_hours,.5,12.0-stay-leaving-.25)
	if elapsed<stay:
		return {"phase":Phase.BERTHED,"transform":berth_transform}
	if elapsed<stay+leaving:
		return {"phase":Phase.DEPARTING,"transform":_route_pose(_outbound,(elapsed-stay)/leaving)}
	if elapsed<12.0-arriving:
		return {"phase":Phase.OFFSHORE,"transform":_route_pose(_offshore,(elapsed-stay-leaving)/(12.0-arriving-stay-leaving))}
	return {"phase":Phase.ARRIVING,"transform":_route_pose(_inbound,(elapsed-(12.0-arriving))/arriving)}

func _route_pose(curve: Curve3D, fraction: float) -> Transform3D:
	# Quintic easing gives zero speed/acceleration at the berth and phase joins.
	var t:=clampf(fraction,0,1)
	var eased:=t*t*t*(t*(t*6-15)+10)
	var distance:=curve.get_baked_length()*eased
	var point:=curve.sample_baked(distance,true)
	var direction:=curve.sample_baked(minf(distance+.5,curve.get_baked_length()),true)-curve.sample_baked(maxf(distance-.5,0),true)
	var basis:=Basis.looking_at(direction.normalized(),Vector3.UP)
	return berth_transform*Transform3D(basis,point)

func _apply_hour(hour: float, delta: float) -> void:
	var state:=sample_schedule(hour)
	phase=state.phase
	var previous:=_ship.global_position
	_ship.global_transform=state.transform
	speed_mps=_ship.global_position.distance_to(previous)/delta if delta>0 else 0.0
	var light_mode:=2 if phase==Phase.BERTHED else 0
	if _ship.navigation_mode!=light_mode: _ship.navigation_mode=light_mode

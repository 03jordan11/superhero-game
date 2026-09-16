extends Node3D
## Scheduled background flights share one runway; the two schedules are 100 seconds apart.
@export var air_traffic_running := true
@export_range(0.25,3.0,0.05) var air_traffic_speed := 1.0
@export_range(0.0,2.0,0.05) var airport_light_brightness := 1.0
var elapsed:=0.0
var _planes: Array[Node3D]=[]
var _glows: Array[StandardMaterial3D]=[]
var _lights: Array[Light3D]=[]
var _strobes: Array[MeshInstance3D]=[]
var _horizon: ShaderMaterial
const LAP:=330.0
const GROUND_Y:=10.0
const FLIGHT: Array[Vector4]=[
	Vector4(-6500,500,200,0),Vector4(-5000,130,200,20),Vector4(-4420,17,200,32),
	Vector4(-4120,10,200,38),Vector4(-3250,10,200,52),Vector4(-2920,10,200,59),
	Vector4(-2880,10,140,64),Vector4(-2880,10,40,70),Vector4(-3050,10,40,78),
	Vector4(-3050,10,-90,86),Vector4(-3050,10,-90,111),Vector4(-3050,10,40,125),
	Vector4(-3190,10,50,128),Vector4(-4330,10,50,158),Vector4(-4410,10,160,165),
	Vector4(-4380,10,200,169),Vector4(-4250,10,200,178),Vector4(-3900,10,200,187),
	Vector4(-3300,10,200,195),Vector4(-2750,30,200,201),Vector4(-2180,150,460,212),
	Vector4(-2300,300,1600,230),Vector4(-4500,650,4000,262),Vector4(-7300,650,2800,288),
	Vector4(-7700,650,750,304),Vector4(-7000,560,200,320),Vector4(-6500,500,200,330)]

static func point(index: int) -> Vector3:
	var p:=FLIGHT[index]
	return Vector3(p.x,p.y,p.z)

static func flight_position(seconds: float) -> Vector3:
	var time:=fposmod(seconds,LAP)
	if time>=86 and time<=111: return point(9)
	if time>111 and time<=125: return point(10).lerp(point(11),smoothstep(111,125,time))
	for i in FLIGHT.size()-1:
		if time>FLIGHT[i+1].w: continue
		var weight: float=(time-FLIGHT[i].w)/(FLIGHT[i+1].w-FLIGHT[i].w)
		var before:=point(i-1 if i>0 else FLIGHT.size()-2)
		var after:=point(i+2 if i+2<FLIGHT.size() else 1)
		var p:=point(i).cubic_interpolate(point(i+1),before,after,weight)
		p.y=maxf(p.y,GROUND_Y)
		if time>=32 and time<=38: p.y=lerpf(17.0,GROUND_Y,smoothstep(32,38,time))
		if time>=38 and time<=195: p.y=GROUND_Y
		if (time>=32 and time<=59) or (time>=169 and time<=195): p.z=200
		return p
	return point(0)

static func flight_state(seconds: float) -> String:
	var t:=fposmod(seconds,LAP)
	if t<38: return "Approach"
	if t<59: return "Landing rollout"
	if t<86: return "Taxi to gate"
	if t<111: return "At gate"
	if t<125: return "Pushback"
	if t<169: return "Taxi to runway"
	if t<201: return "Takeoff"
	if t<230: return "Climb"
	return "Coastal circuit"

func _ready() -> void:
	for plane in $Airport/AirTraffic.get_children(): _planes.append(plane)
	var copies: Dictionary={}
	for mesh in find_children("*","GeometryInstance3D",true,false):
		if mesh.has_meta("strobe"):
			mesh.material_override=mesh.material_override.duplicate()
			_strobes.append(mesh)
		elif mesh.material_override is StandardMaterial3D and mesh.material_override.has_meta("night_glow"):
			var source: StandardMaterial3D=mesh.material_override
			if not copies.has(source):
				copies[source]=source.duplicate()
				_glows.append(copies[source])
			mesh.material_override=copies[source]
	for light in find_children("*","Light3D",true,false):
		light.set_meta("base_energy",light.light_energy)
		_lights.append(light)
	_horizon=$DistantLandscape.material_override.duplicate()
	$DistantLandscape.material_override=_horizon
	_bind_clock.call_deferred()
	update_air_traffic(0)

func _bind_clock() -> void:
	var clock:=get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock!=null:
		clock.night_lighting_changed.connect(apply_night)
		apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	for mat in _glows: mat.emission_energy_multiplier=float(mat.get_meta("night_glow"))*amount*airport_light_brightness
	for light in _lights:
		light.light_energy=float(light.get_meta("base_energy"))*amount*airport_light_brightness
		light.visible=light.light_energy>0.001
	_horizon.set_shader_parameter("night_amount",amount)

func _physics_process(delta: float) -> void: update_air_traffic(delta)

func update_air_traffic(delta: float) -> void:
	if air_traffic_running: elapsed+=delta*air_traffic_speed
	for plane in _planes:
		var time:=fposmod(elapsed+float(plane.get_meta("phase")),LAP)
		plane.position=flight_position(time)
		var direction: Vector3=flight_position(time+0.15)-flight_position(time-0.15)
		if time>=86 and time<=119: direction=Vector3.FORWARD
		elif time>119 and time<128: direction=Vector3.FORWARD.rotated(Vector3.UP,PI*0.5*smoothstep(119,128,time))
		if direction.length_squared()>0.0001:
			direction=direction.normalized()
			var next: Vector3=(flight_position(time+0.5)-plane.position).normalized()
			var bank:=clampf(direction.cross(next).y*4.0,-0.25,0.25) if plane.position.y>30 else 0.0
			var right:=Vector3.UP.cross(direction).normalized()
			plane.basis=Basis(right,direction.cross(right).normalized(),direction)*Basis(Vector3.BACK,bank)
		plane.get_node("LandingGear").visible=time<202 or time>314
		plane.set_meta("flight_state",flight_state(time))
	for strobe in _strobes:
		var active:=fposmod(elapsed+float(strobe.get_meta("strobe")),1.5)<0.13
		strobe.material_override.emission_energy_multiplier=9.0 if active else 0.35

extends Node3D
## Baked street scenery, coordinated signals and the Roadstar advertising blimp.
@export_range(0.0, 3.0, 0.05) var animation_speed := 1.0
@export_range(90.0, 1200.0, 10.0) var blimp_lap_seconds := 420.0
@export_range(310.0, 700.0, 10.0) var blimp_altitude := 360.0
@export var blimp_ad_audio_enabled := true
@export_range(-40.0, 0.0, 1.0) var blimp_ad_volume_db := -12.0
@export_range(25.0, 180.0, 5.0) var ad_repeat_seconds := 70.0
@export_range(8.0, 40.0, 1.0) var signal_green_seconds := 18.0
@export_range(2.0, 5.0, 0.5) var signal_yellow_seconds := 3.0
@export_range(1.0, 4.0, 0.5) var signal_clearance_seconds := 2.0
@export var traffic_controls_enabled := true
var elapsed := 0.0
var controls: Dictionary = {}
var _signal_lenses: Array[MeshInstance3D] = []
var _glows: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _blinks: Array[MeshInstance3D] = []
var _ad_labels: Array[Label3D] = []
var _propellers: Array[Node3D] = []
var _night := 0.0
var _ad_timer := 5.0
var _update_timer := 0.0
@onready var blimp: Node3D = $Blimp
@onready var ad_audio: AudioStreamPlayer3D = $Blimp/Advertisement
const AD_LINES := ["ROADSTAR TIRES", "BIG CITY GRIP", "SMALL TOWN PRICES", "ROADSTAR  •  KEEP ROLLING"]

func _ready() -> void:
	add_to_group(&"city_traffic_controls")
	for control in $TrafficControls.get_children():
		controls[int(control.get_meta("junction"))] = {"kind":control.get_meta("kind"),"offset":float(control.get_meta("offset",0))}
	var copies: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("signal_color"):
			node.material_override=node.material_override.duplicate()
			_signal_lenses.append(node)
		elif node.has_meta("blink"):
			node.material_override=node.material_override.duplicate()
			_blinks.append(node)
		elif node.material_override is StandardMaterial3D and node.material_override.has_meta("night_glow"):
			var source: StandardMaterial3D=node.material_override
			if not copies.has(source):
				copies[source]=source.duplicate()
				_glows.append(copies[source])
			node.material_override=copies[source]
	for node in find_children("AdText*","Label3D",true,false): _ad_labels.append(node)
	for node in blimp.find_children("Propeller*","Node3D",true,false): _propellers.append(node)
	for light in find_children("*","Light3D",true,false):
		light.set_meta("base_energy",light.light_energy)
		_lights.append(light)
	_bind_clock.call_deferred()
	update_animation(0.0)

func _bind_clock() -> void:
	var clock:=get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock!=null:
		clock.night_lighting_changed.connect(apply_night)
		apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	_night=amount
	for mat in _glows: mat.emission_energy_multiplier=float(mat.get_meta("night_glow"))*amount
	for light in _lights:
		light.light_energy=float(light.get_meta("base_energy"))*amount
		light.visible=amount>0.001

func control_kind(lane: Dictionary) -> String:
	if not traffic_controls_enabled: return ""
	return str(controls.get(int(lane.junction),{}).get("kind",""))

func signal_color(junction: int, axis: int) -> int:
	# 0 red, 1 amber, 2 green. Both axes receive an all-red clearance interval.
	var half:=signal_green_seconds+signal_yellow_seconds+signal_clearance_seconds
	var phase:=fposmod(elapsed+float(controls.get(junction,{}).get("offset",0)),half*2.0)
	if axis==0: phase=fposmod(phase-half,half*2.0)
	if phase<signal_green_seconds: return 2
	if phase<signal_green_seconds+signal_yellow_seconds: return 1
	return 0

func allows_lane(lane: Dictionary) -> bool:
	if control_kind(lane)!="signal": return true
	var axis:=0 if absf(lane.forward.x)>0.5 else 1
	return signal_color(int(lane.junction),axis)==2

func _process(delta: float) -> void:
	update_animation(delta)

func update_animation(delta: float) -> void:
	elapsed += delta*animation_speed
	var angle:=elapsed/ maxf(blimp_lap_seconds,90.0)*TAU+0.7
	blimp.position=Vector3(-50+1320*cos(angle),blimp_altitude+sin(angle*2.0)*12.0,-120+730*sin(angle))
	var direction:=Vector3(-1320*sin(angle),0,730*cos(angle)).normalized()
	blimp.rotation.y=atan2(direction.x,direction.z)
	for prop in _propellers: prop.rotation.z=elapsed*23.0
	for lens in _blinks:
		var flash:=fposmod(elapsed+float(lens.get_meta("blink")),1.6)<0.16
		lens.material_override.emission_energy_multiplier=12.0 if flash else 0.5
	var ad_index:=int(elapsed/7.0)%AD_LINES.size()
	for text in _ad_labels:
		text.text=AD_LINES[ad_index]
		text.font_size=76 if text.text.length()>18 else 96
	_update_timer+=delta
	if _update_timer>=0.1 or delta==0.0:
		_update_timer=0.0
		for lens in _signal_lenses:
			var active:=traffic_controls_enabled and int(lens.get_meta("signal_color"))==signal_color(int(lens.get_meta("junction")),int(lens.get_meta("axis")))
			lens.material_override.emission_energy_multiplier=3.2 if active else 0.0
			lens.material_override.albedo_color=lens.get_meta("lens_color") if active else Color(0.015,0.02,0.02)
	ad_audio.volume_db=blimp_ad_volume_db
	if not blimp_ad_audio_enabled:
		ad_audio.stop()
		return
	_ad_timer-=delta
	if _ad_timer<=0.0:
		var camera:=get_viewport().get_camera_3d()
		if camera!=null and camera.global_position.distance_to(blimp.global_position)<ad_audio.max_distance:
			ad_audio.play()
			_ad_timer=ad_repeat_seconds
		else: _ad_timer=4.0

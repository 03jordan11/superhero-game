extends Node3D
## Baked street scenery and the Roadstar advertising blimp.
@export_range(0.0, 3.0, 0.05) var animation_speed := 1.0
@export_range(90.0, 1200.0, 10.0) var blimp_lap_seconds := 420.0
@export_range(310.0, 700.0, 10.0) var blimp_altitude := 360.0
@export var blimp_ad_audio_enabled := true
@export_range(-40.0, 0.0, 1.0) var blimp_ad_volume_db := -12.0
@export_range(25.0, 180.0, 5.0) var ad_repeat_seconds := 70.0
var elapsed := 0.0
var _glows: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _blinks: Array[OmniLight3D] = []
var _ad_labels: Array[Label3D] = []
var _propellers: Array[Node3D] = []
var _night := 0.0
var _ad_timer := 5.0
@onready var blimp: Node3D = $Blimp
@onready var ad_audio: AudioStreamPlayer3D = $Blimp/Advertisement
const AD_LINES := ["ROADSTAR TIRES", "BIG CITY GRIP", "SMALL TOWN PRICES", "ROADSTAR  •  KEEP ROLLING"]

func _ready() -> void:
	var copies: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.material_override is StandardMaterial3D and node.material_override.has_meta("night_glow"):
			var source: StandardMaterial3D=node.material_override
			if not copies.has(source):
				copies[source]=source.duplicate()
				_glows.append(copies[source])
			node.material_override=copies[source]
	for node in find_children("AdText*","Label3D",true,false): _ad_labels.append(node)
	for node in blimp.find_children("Propeller*","Node3D",true,false): _propellers.append(node)
	for light in find_children("*","Light3D",true,false):
		if light.has_meta("blink"):
			_blinks.append(light)
			continue
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
		lens.light_energy=3.0 if flash else 0.125
	var ad_index:=int(elapsed/7.0)%AD_LINES.size()
	for text in _ad_labels:
		text.text=AD_LINES[ad_index]
		text.font_size=76 if text.text.length()>18 else 96
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

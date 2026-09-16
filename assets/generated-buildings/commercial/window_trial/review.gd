extends Node3D
## A single isolated comparison. Both modes use the same current sky/environment.
const ORIGINAL=preload("res://assets/generated-buildings/commercial/textures/commercial_skyscraper_02_emission.res")
@export var trial_enabled:=true
var _facade: StandardMaterial3D
var _trial_texture: Texture2D
var _dragging:=false
var _yaw:=.48
var _pitch:=.16
var _distance:=155.0
func _ready() -> void:
	var visual: MeshInstance3D=$Building/MeshInstance3D
	for surface in visual.mesh.get_surface_count():
		var material:=visual.get_active_material(surface) as StandardMaterial3D
		if material!=null and material.albedo_texture!=null and material.albedo_texture.resource_path.ends_with("dark_glass.res"):
			_facade=material; _trial_texture=material.emission_texture; break
	set_trial(trial_enabled); _update_camera()
func set_trial(enabled: bool) -> void:
	trial_enabled=enabled
	_facade.emission_on_uv2=enabled
	_facade.emission_texture=_trial_texture if enabled else ORIGINAL
	$UI/Instructions.text=("TRIAL — modest window reduction" if enabled else "ORIGINAL — restored emission")+"\n1: Original   2: Trial   Drag: Orbit   Wheel: Zoom"
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_1: set_trial(false)
		if event.keycode==KEY_2: set_trial(true)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: _dragging=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: _distance=maxf(25,_distance*.9)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: _distance=minf(350,_distance/ .9)
		_update_camera()
	if event is InputEventMouseMotion and _dragging:
		_yaw-=event.relative.x*.006; _pitch=clampf(_pitch+event.relative.y*.006,-.3,1.2); _update_camera()
func _update_camera() -> void:
	var target:=Vector3(0,55,0)
	$Camera3D.position=target+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),-cos(_yaw)*cos(_pitch))*_distance
	$Camera3D.look_at(target)

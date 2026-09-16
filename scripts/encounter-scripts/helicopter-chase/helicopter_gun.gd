extends Node3D
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const SHOT = preload("res://assets/audio/combat/weapons/guns/pistol_shot_single.wav")
@export_range(300,950,10) var rounds_per_minute := 650.0
@export var bullet_damage := 4.0
@export var maximum_range := 95.0
@export var burst_duration := 1.6
@export var burst_pause := 2.0
@export var sweep_degrees := 24.0
@export var horizontal_error_degrees := 4.0
@export var vertical_error_degrees := 2.0
@export var movement_error_per_mps := 0.08
var shooter: CharacterBody3D
var target: Node3D
var enabled := true
var shots_fired := 0
var hits := 0
var bursting := false
var _elapsed := 0.0
var _cooldown := 1.5
var _shot_clock := 0.0
var _last_fraction := 0.0
var _sweep_sign := 1.0
var _aim_point := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _audio: AudioStreamPlayer3D
var _tracer: MeshInstance3D
var _flash: MeshInstance3D
var _trace_time := 0.0

func _ready() -> void:
	_rng.randomize()
	_audio=AudioStreamPlayer3D.new()
	_audio.name="Gunshot"
	_audio.stream=SHOT
	_audio.bus=&"SFX"
	_audio.volume_db=-10
	_audio.unit_size=18
	_audio.max_distance=180
	_audio.max_polyphony=5
	add_child(_audio)
	var barrel:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=.065; mesh.bottom_radius=.085; mesh.height=1.1; mesh.radial_segments=8
	barrel.mesh=mesh; barrel.rotation.x=PI/2; barrel.position.z=-.45
	var metal:=StandardMaterial3D.new(); metal.albedo_color=Color("242a2e"); metal.roughness=.7
	barrel.material_override=metal; add_child(barrel)
	_tracer=MeshInstance3D.new(); _tracer.mesh=ImmediateMesh.new(); _tracer.top_level=true
	var glow:=StandardMaterial3D.new(); glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color=Color(1,.68,.18); glow.emission_enabled=true; glow.emission=Color(1,.35,.04); glow.emission_energy_multiplier=2
	_tracer.material_override=glow; _tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tracer)
	_flash=MeshInstance3D.new(); var flash_mesh:=SphereMesh.new(); flash_mesh.radius=.13; flash_mesh.height=.26; flash_mesh.radial_segments=8; flash_mesh.rings=4
	_flash.mesh=flash_mesh; _flash.material_override=glow; _flash.position.z=-1; _flash.hide(); add_child(_flash)

func stop() -> void:
	enabled=false; bursting=false; _audio.stop(); _tracer.hide(); _flash.hide()

func update_weapon(delta: float, speed: float) -> void:
	_trace_time=maxf(0,_trace_time-delta)
	_tracer.visible=_trace_time>0
	_flash.visible=_trace_time>0
	if not enabled or not is_instance_valid(target) or not is_instance_valid(shooter): return
	if global_position.distance_to(target.global_position)>maximum_range:
		bursting=false; _cooldown=maxf(_cooldown,.5); return
	if not bursting:
		_cooldown-=delta
		if _cooldown>0: return
		# Do not start firing into a building. Cover can still interrupt an active sweep.
		var sight:=ray_to(target.global_position)
		if sight.is_empty() or sight.collider!=target: _cooldown=.3; return
		begin_burst(speed)
	_elapsed+=delta
	_shot_clock-=delta
	if _shot_clock<=0:
		var fraction:=clampf(_elapsed/maxf(burst_duration,.1),0,1)
		fire_sweep(_last_fraction,fraction)
		_last_fraction=fraction
		# Preserve average cadence, but never dump accumulated rounds after a hitch.
		_shot_clock=maxf(0,_shot_clock+60.0/maxf(rounds_per_minute,1))
	if _elapsed>=burst_duration:
		bursting=false; _cooldown=burst_pause

func begin_burst(speed: float) -> void:
	bursting=true; _elapsed=0; _shot_clock=0; _last_fraction=0
	_sweep_sign=-_sweep_sign
	var direction: Vector3=(target.global_position-global_position).normalized()
	var spread:=horizontal_error_degrees+speed*movement_error_per_mps
	direction=direction.rotated(Vector3.UP,deg_to_rad(_rng.randf_range(-spread,spread)))
	var right:=direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right=Vector3.RIGHT
	var vertical:=vertical_error_degrees+speed*movement_error_per_mps*.3
	direction=direction.rotated(right,deg_to_rad(_rng.randf_range(-vertical,vertical)))
	_aim_point=global_position+direction*global_position.distance_to(target.global_position)

func sweep_direction(fraction: float) -> Vector3:
	return (_aim_point-global_position).normalized().rotated(Vector3.UP,deg_to_rad(lerpf(-sweep_degrees*.5,sweep_degrees*.5,fraction))*_sweep_sign)

func fire_sweep(previous: float, current: float) -> bool:
	shots_fired+=1
	var origin:=global_position
	var start:=sweep_direction(previous)
	var finish:=sweep_direction(current)
	var hit:=ray_to(origin+finish*maximum_range)
	var damage_hit: Dictionary=hit if not hit.is_empty() and hit.collider==target else {}
	if damage_hit.is_empty() and is_instance_valid(target):
		# Closest ray in the swept angular slice. It must intersect the real player
		# body first, so small targets aren't skipped between rounds and cover wins.
		var nearest:=closest_sweep_direction(start,finish,(target.global_position-origin).normalized())
		var swept:=ray_to(origin+nearest*maximum_range)
		if not swept.is_empty() and swept.collider==target:
			damage_hit=swept; hit=swept; finish=nearest
	look_at(origin+finish,Vector3.RIGHT if absf(finish.y)>.98 else Vector3.UP)
	_audio.pitch_scale=_rng.randf_range(.94,1.03); _audio.play()
	var end: Vector3=hit.position if not hit.is_empty() else origin+finish*maximum_range
	_draw_tracer(origin,end)
	if damage_hit.is_empty(): return false
	var info=DAMAGE.new(bullet_damage,origin,finish,&"none",shooter)
	info.damage_type=&"bullet"
	target.apply_damage(info)
	hits+=1
	return true

static func closest_sweep_direction(start: Vector3, finish: Vector3, toward_target: Vector3) -> Vector3:
	var angle:=start.angle_to(finish)
	if angle<.00001: return finish
	var tangent: Vector3=(finish-start*start.dot(finish)).normalized()
	var along:=clampf(atan2(toward_target.dot(tangent),toward_target.dot(start)),0,angle)
	return (start*cos(along)+tangent*sin(along)).normalized()

func ray_to(endpoint: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(global_position,endpoint,1)
	query.exclude=[shooter.get_rid()]
	query.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _draw_tracer(origin: Vector3, endpoint: Vector3) -> void:
	var mesh:=_tracer.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(endpoint)
	mesh.surface_end()
	_tracer.global_transform=Transform3D.IDENTITY
	_trace_time=.045; _tracer.show(); _flash.show()

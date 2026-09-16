extends BaseEncounter
## One shared ship, two independent mooring lines, two flight contact points.
@export var offshore_distance:=110.0
@export var minimum_start_angle:=12.0
@export var maximum_start_angle:=28.0
@export var docking_tolerance:=5.0
@export var push_speed:=8.0
@export var reel_speed:=3.6
## Effective strength includes purchased strength bonuses. Each point above 1 adds 5%.
@export_range(0.0,0.25,0.01) var strength_speed_per_point:=0.05
@export_range(1.0,5.0,0.1) var maximum_strength_speed_multiplier:=3.0
@export var maximum_rope_tension:=9.6
@export var interaction_radius:=3.2
@export var stop_damping:=2.5
## Contact centers measured against the tapered hull, with room for the hero's body.
@export var bow_push_point:=Vector3(11.75,4,-55)
@export var stern_push_point:=Vector3(12.8,4,55)
var ship: Node3D
var schedule: Node
var berth:=Transform3D.IDENTITY
var linear_velocity:=Vector3.ZERO
var angular_velocity:=0.0
var dock_points: Array[Vector3]=[]
var rope_lengths: Array[float]=[]
var rope_minimums: Array[float]=[]
var active_end: int=-1
var active_method: StringName=&""
var effort:=false
var _claimed:=false
var _saved_enabled:=true
var _original_pose:=Transform3D.IDENTITY
var _start_pose:=Transform3D.IDENTITY
var _push_rings: Array[Node3D]=[]
var _dock_rings: Array[Node3D]=[]
var _ropes: MeshInstance3D
var _hud: Label
var _rng:=RandomNumberGenerator.new()
var _hull:=BoxShape3D.new()

func _init() -> void:
	encounter_id=&"ship_docking"; display_name="Ship Docking"
	xp_reward=200; money_reward=200; cleanup_delay=3.0
	_rng.randomize(); _hull.size=Vector3(24,10,156)

func _prepare_encounter() -> bool:
	schedule=get_tree().get_first_node_in_group(&"cargo_ship_schedule")
	if not is_instance_valid(schedule):
		spawn_error="No scheduled cargo vessel exists in this scene."; return false
	ship=schedule.get_parent()
	if ship.has_meta(&"docking_encounter"):
		spawn_error="The cargo vessel already has an active docking encounter."; return false
	berth=schedule.berth_transform
	var space:=get_world_3d().direct_space_state
	for end in range(2):
		var spot:=berth*Vector3(-28,0,_end_z(end))
		var ray:=PhysicsRayQueryParameters3D.create(spot+Vector3.UP*30,spot-Vector3.UP*10,1,[ship.get_node("Collision").get_rid()])
		var hit:=space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<.9:
			spawn_error="The dock needs clear ground for both mooring stations."; return false
		dock_points.append(hit.position+Vector3.UP*.06)
	for attempt in range(30):
		var angle: float=deg_to_rad(_rng.randf_range(minimum_start_angle,maximum_start_angle))*([-1,1][_rng.randi_range(0,1)])
		_start_pose=berth
		_start_pose.origin+=berth.basis*Vector3(offshore_distance,0,_rng.randf_range(-12,12))
		_start_pose.basis=Basis(Vector3.UP,angle)*berth.basis
		if _pose_is_clear(_start_pose): return true
	spawn_error="No clear water for the crooked cargo vessel."; return false

func _activate_encounter() -> void:
	add_to_group(&"ship_docking")
	_claimed=true; ship.set_meta(&"docking_encounter",self)
	_saved_enabled=schedule.enabled; _original_pose=ship.global_transform
	schedule.enabled=false; ship.global_transform=_start_pose
	ship.navigation_mode=1
	for end in range(2):
		rope_lengths.append(_horizontal(rope_attachment(end)-dock_points[end]).length())
		rope_minimums.append(_horizontal(berth*Vector3(-11.5,4,_end_z(end))-dock_points[end]).length())
		_push_rings.append(_ring("Fly here • E: push "+_end_name(end),true))
		var station:=_ring("E: grab "+_end_name(end)+" line",false)
		station.global_position=dock_points[end]; _dock_rings.append(station)
	_ropes=MeshInstance3D.new(); _ropes.mesh=ImmediateMesh.new(); add_child(_ropes)
	var rope_material:=StandardMaterial3D.new(); rope_material.albedo_color=Color(.64,.48,.24)
	rope_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	_ropes.material_override=rope_material
	var canvas:=CanvasLayer.new(); add_child(canvas)
	_hud=Label.new(); canvas.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud.offset_top=-120; _hud.offset_bottom=-30
	_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _hud.add_theme_font_size_override("font_size",20)
	_hud.add_theme_color_override("font_outline_color",Color.BLACK)
	_hud.add_theme_constant_override("outline_size",6)
	_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_update_visuals()

func _end_z(end: int) -> float: return -55.0 if end==0 else 55.0
func _end_name(end: int) -> String: return "bow" if end==0 else "stern"
func _horizontal(v: Vector3) -> Vector3: return Vector3(v.x,0,v.z)
func end_position(end: int) -> Vector3: return ship.global_transform*Vector3(0,0,_end_z(end))
func target_position(end: int) -> Vector3: return berth*Vector3(0,0,_end_z(end))
func push_position(end: int) -> Vector3: return ship.global_transform*(bow_push_point if end==0 else stern_push_point)
func rope_attachment(end: int) -> Vector3: return ship.global_transform*Vector3(-11.5,4,_end_z(end))
func end_error(end: int) -> float: return _horizontal(end_position(end)-target_position(end)).length()
func is_ship_stopped() -> bool: return linear_velocity.length()<.08 and absf(angular_velocity)<.001

func nearest_interaction(player: PlayerCharacter) -> Dictionary:
	if state!=EncounterState.ACTIVE or active_end>=0: return {}
	var best:=interaction_radius
	var result: Dictionary={}
	for end in range(2):
		var method: StringName=&"push" if player.is_flying else &"rope"
		if method==&"push" and not is_ship_stopped(): continue
		var spot:=push_position(end) if method==&"push" else dock_points[end]+Vector3.UP*1.0
		var distance:=player.global_position.distance_to(spot)
		if distance<best: best=distance; result={"end":end,"method":method}
	return result

func attach(end: int, method: StringName) -> void:
	active_end=end; active_method=method; effort=false
func detach() -> void:
	active_end=-1; active_method=&""; effort=false
func attachment_position() -> Vector3:
	return push_position(active_end) if active_method==&"push" else dock_points[active_end]+Vector3.UP*1.0
func attachment_direction() -> Vector3:
	return -ship.global_basis.x if active_method==&"push" else _horizontal(rope_attachment(active_end)-dock_points[active_end]).normalized()

func _physics_process(delta: float) -> void:
	if state!=EncounterState.ACTIVE: return
	if not is_instance_valid(ship) or not is_instance_valid(reward_player) or reward_player.is_dead:
		fail_encounter(); return
	advance_ship(delta)
	_update_visuals()
	if end_error(0)<=docking_tolerance and end_error(1)<=docking_tolerance:
		# Both ends must qualify; moving only the center cannot finish the task.
		linear_velocity=Vector3.ZERO; angular_velocity=0
		reward_player.ship_interaction.release()
		ship.global_transform=berth
		complete_encounter(); _release_ship(true)
		for ring in _push_rings+_dock_rings: ring.hide()
		_ropes.hide(); _hud.text="Ship docked!  +200 XP  +$200"

func get_strength_speed_multiplier() -> float:
	var strength:=reward_player.stats.get_effective_strength() if is_instance_valid(reward_player) else 1
	return clampf(1.0+float(maxi(strength-1,0))*strength_speed_per_point,1.0,maximum_strength_speed_multiplier)

func advance_ship(delta: float) -> void:
	var strength_multiplier:=get_strength_speed_multiplier()
	var acceleration:=Vector3.ZERO
	var turn_acceleration:=0.0
	if active_end>=0 and effort and active_method==&"rope":
		rope_lengths[active_end]=maxf(rope_minimums[active_end],rope_lengths[active_end]-reel_speed*strength_multiplier*delta)
	for end in range(2):
		var r:=_horizontal(end_position(end)-ship.global_position)
		var point_velocity:=linear_velocity+Vector3.UP.cross(r)*angular_velocity
		var force:=Vector3.ZERO
		if end==active_end and active_method==&"push" and effort:
			var offset:=_horizontal(target_position(end)-end_position(end))
			force=(offset.limit_length(push_speed*strength_multiplier)-point_velocity)*2.0
		# Reeled lines remain tied off when released. Slack lines exert no pull.
		var line:=_horizontal(dock_points[end]-rope_attachment(end))
		var stretch:=line.length()-rope_lengths[end]
		if stretch>0.0:
			# Scale the force limit too, so stronger heroes move the hull faster,
			# rather than merely shortening an increasingly stretched line.
			var tension:=clampf(stretch*2.5-point_velocity.dot(line.normalized())*1.5,0,maximum_rope_tension*strength_multiplier)
			force+=line.normalized()*tension
		acceleration+=force
		turn_acceleration+=r.cross(force).y/2200.0
	linear_velocity=(linear_velocity+acceleration*delta)/(1.0+stop_damping*delta)
	angular_velocity=clampf((angular_velocity+turn_acceleration*delta)/(1.0+stop_damping*delta),-.06*strength_multiplier,.06*strength_multiplier)
	var next:=ship.global_transform
	next.origin+=linear_velocity*delta
	next.basis=Basis(Vector3.UP,angular_velocity*delta)*next.basis
	if _pose_is_clear(next): ship.global_transform=next
	else: linear_velocity=Vector3.ZERO; angular_velocity=0
	ship.navigation_mode=1 if is_ship_stopped() else 0

func _pose_is_clear(pose: Transform3D) -> bool:
	var q:=PhysicsShapeQueryParameters3D.new(); q.shape=_hull; q.transform=pose; q.collision_mask=1
	q.exclude=[ship.get_node("Collision").get_rid(),reward_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()

func _ring(text: String, upright: bool) -> Node3D:
	var node:=Node3D.new(); add_child(node)
	var mesh:=MeshInstance3D.new(); var torus:=TorusMesh.new()
	torus.inner_radius=1.65; torus.outer_radius=1.95; torus.rings=24; torus.ring_segments=6
	mesh.mesh=torus
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color(.12,1,.35)
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.emission_enabled=true; mat.emission=mat.albedo_color
	mesh.material_override=mat; node.add_child(mesh)
	if upright: mesh.rotation.z=PI/2
	var label:=Label3D.new(); label.text=text; label.position.y=2.5; label.font_size=32; label.pixel_size=.012
	if upright: label.position.x=3.0
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; node.add_child(label)
	return node

func _update_visuals() -> void:
	for end in range(2):
		_push_rings[end].global_transform=Transform3D(ship.global_basis,push_position(end))
		_push_rings[end].visible=is_ship_stopped() and active_end!=end
	var mesh:=_ropes.mesh as ImmediateMesh; mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for end in range(2):
		var start:=dock_points[end]+Vector3.UP*.8
		var finish:=rope_attachment(end)
		var slack:=maxf(0,rope_lengths[end]-_horizontal(finish-start).length())
		for i in range(16):
			var a:=float(i)/16; var b:=float(i+1)/16
			var p:=start.lerp(finish,a)-Vector3.UP*sin(a*PI)*minf(slack*.08+.3,2.0)
			var q:=start.lerp(finish,b)-Vector3.UP*sin(b*PI)*minf(slack*.08+.3,2.0)
			var width: Vector3=(q-p).cross(Vector3.UP).normalized()*.055
			for vertex in [p-width,p+width,q+width,p-width,q+width,q-width]: mesh.surface_add_vertex(to_local(vertex))
	mesh.surface_end()
	var instructions:="Fly to a green ship circle to push, or use either dock rope."
	if active_end>=0:
		instructions=("Hold W: push" if active_method==&"push" else "Hold S: pull in")+" • E: release"
	_hud.text="Dock the ship — Bow: %.1f m   Stern: %.1f m\n%s"%[end_error(0),end_error(1),instructions]

func get_waypoint_position() -> Vector3:
	return berth.origin
func fail_encounter() -> void:
	if state in [EncounterState.COMPLETED,EncounterState.FAILED]: return
	super.fail_encounter()
	_release_ship(false)
	for ring in _push_rings+_dock_rings: ring.hide()
	if is_instance_valid(_ropes): _ropes.hide()
	if is_instance_valid(_hud): _hud.text="Ship docking interrupted."
func _release_ship(success: bool) -> void:
	if not _claimed: return
	_claimed=false
	if is_instance_valid(reward_player): reward_player.ship_interaction.release()
	if is_instance_valid(ship):
		ship.remove_meta(&"docking_encounter")
		if not success: ship.global_transform=_original_pose
	if is_instance_valid(schedule):
		if success and _saved_enabled: schedule.resume_from_berth()
		else: schedule.enabled=_saved_enabled
func _exit_tree() -> void: _release_ship(false)

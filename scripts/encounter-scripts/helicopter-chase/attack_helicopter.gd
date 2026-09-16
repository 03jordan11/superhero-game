extends CharacterBody3D
const FLIGHT=preload("res://assets/aircraft/helicopter/helicopter_flying.tscn")
const HEALTH=preload("res://scripts/health_component.gd")
const GUN=preload("res://scripts/encounter-scripts/helicopter-chase/helicopter_gun.gd")
const WRECK=preload("res://scripts/encounter-scripts/helicopter-chase/helicopter_wreck.gd")
const EXPLOSION=preload("res://effects/vehicle_explosion_effect.tscn")
const AIRCRAFT_EXPLOSION_SCRIPT=preload("res://effects/helicopter_explosion.gd")
signal defeated
@export var max_health:=100.0
@export_range(10,100,1,"suffix:m") var engagement_distance:=25.0
@export_range(5,50,1,"suffix:m") var height_offset:=10.0
@export var pursuit_speed:=90.0
@export var orbit_speed:=5.0
@export var wreck_lifetime:=30.0
## Minimum flight-root height over terrain/roofs; includes room for banking/skids.
@export_range(8,40,1,"suffix:m") var ground_clearance:=12.0
var target: Node3D
var is_dead:=false
var health_component
var flight: Node3D
var gun: Node3D
var health_label: Label3D
var wreck: RigidBody3D
var _solids: Array[CollisionShape3D]=[]
var _original_transforms: Array[Transform3D]=[]
var _safe_destination:=Vector3.ZERO
var _navigation_clock:=0.0
var _blocked_climb_time:=0.0

func _ready() -> void:
	name="AttackHelicopter"
	add_to_group(&"attack_helicopter")
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer=1; collision_mask=1
	health_component=HEALTH.new(max_health)
	health_component.depleted.connect(_on_depleted)
	health_component.health_changed.connect(_health_changed)
	flight=FLIGHT.instantiate(); flight.name="Flight"; add_child(flight)
	flight.set_physics_process(false)
	flight.maximum_speed=pursuit_speed; flight.maximum_acceleration=8.0
	flight.maximum_climb_speed=35.0; flight.vertical_acceleration=8.0
	flight.heading_rate_degrees=50.0
	flight.get_node("Helicopter").livery=3
	flight.initialize_flight(global_position,Vector3.ZERO)
	var model: Node3D=flight.get_node("Helicopter")
	for source in model.get_node("ParkedCollision").get_children():
		var shape:=CollisionShape3D.new(); shape.shape=source.shape; shape.transform=source.transform
		add_child(shape); _solids.append(shape); _original_transforms.append(source.transform)
	gun=GUN.new(); gun.name="SweepingGun"; gun.position=Vector3(0,1.25,-3.55)
	gun.shooter=self; gun.target=target; model.add_child(gun)
	health_label=Label3D.new(); health_label.position=Vector3(0,5.5,0)
	health_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; health_label.font_size=36
	health_label.pixel_size=.018; health_label.modulate=Color(1,.55,.2); add_child(health_label)
	_health_changed(max_health,max_health)
	_safe_destination=global_position

func apply_damage(info) -> bool:
	if is_dead: return false
	return health_component.apply_damage(info)
func get_current_health() -> float: return health_component.current_health
func get_max_health() -> float: return health_component.max_health
func _health_changed(current: float, _maximum: float) -> void:
	if health_label!=null: health_label.text="Helicopter  %d"%ceili(current)

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(target): return
	_navigation_clock-=delta
	if _navigation_clock<=0:
		_safe_destination=choose_destination()
		_navigation_clock=.2
	var to_destination:=_safe_destination-global_position
	var target_velocity:=Vector3.ZERO
	if target is CharacterBody3D: target_velocity=target.velocity
	var requested: Vector3=to_destination*1.1+target_velocity*.85
	_blocked_climb_time=maxf(0,_blocked_climb_time-delta)
	if _blocked_climb_time>0: requested.y=maxf(requested.y,18.0)
	var horizontal:=Vector3(requested.x,0,requested.z).limit_length(pursuit_speed)
	requested=Vector3(horizontal.x,clampf(requested.y,-35,35),horizontal.z)
	# Look ahead far enough to brake before a wall. Climb to go over it while
	# physical collision below prevents penetration if the guidance is late.
	var travel:=Vector3(flight.velocity.x,0,flight.velocity.z)
	if travel.length()>2:
		var lookahead:=travel.normalized()*(travel.length_squared()/16.0+12.0)
		var query:=PhysicsShapeQueryParameters3D.new(); var sphere:=SphereShape3D.new(); sphere.radius=5
		query.shape=sphere; query.transform.origin=global_position+Vector3.UP*2
		query.motion=lookahead; query.exclude=[get_rid()]; query.collision_mask=1
		var result:=get_world_3d().direct_space_state.cast_motion(query)
		if result[0]<1.0:
			requested.x*=maxf(result[0]-.15,0); requested.z*=maxf(result[0]-.15,0)
			requested.y=maxf(requested.y,14.0)
	# Player fall velocity must not pull the aircraft through its stopping height.
	# Probe the whole footprint, and start climbing before reaching higher ground.
	var ground_floor:=_ground_floor_at(global_position)
	var ahead:=global_position+travel*clampf(absf(flight.velocity.y)/8.0+1.0,1.0,3.0)
	var upcoming_floor:=maxf(ground_floor,_ground_floor_at(ahead))
	if is_finite(upcoming_floor):
		requested.y=maxf(requested.y,(upcoming_floor-global_position.y)*1.5)
	if is_finite(ground_floor):
		# Use half the available acceleration to leave room for the smoothed response.
		var safe_descent:=sqrt(2.0*maxf(flight.vertical_acceleration*.5,.1)*maxf(global_position.y-ground_floor,0))
		requested.y=maxf(requested.y,-safe_descent)
		if flight.velocity.y < -safe_descent:
			flight.velocity.y=-safe_descent
			flight.acceleration.y=maxf(flight.acceleration.y,0)
	flight.set_flight_command(requested)
	var before:=global_position
	flight.advance_flight(delta)
	var destination: Vector3=flight.global_position
	# Final swept-step height guard, including lateral movement onto rising terrain.
	# Only cancel unsafe descent; recovery from an already low position climbs normally.
	var step_floor:=maxf(ground_floor,_ground_floor_at(destination))
	if step_floor>maxf(maxf(before.y,destination.y),ground_floor)+.01:
		# Rising ground must not be reached faster than the aircraft can climb.
		# Shorten lateral travel rather than snapping upward onto a hillside/roof.
		var low:=0.0
		var high:=1.0
		for i in range(6):
			var fraction: float=(low+high)*.5
			var probe:=before.lerp(destination,fraction)
			probe.y=destination.y
			if _ground_floor_at(probe)<=maxf(maxf(before.y,probe.y),ground_floor): low=fraction
			else: high=fraction
		destination.x=lerpf(before.x,destination.x,low)
		destination.z=lerpf(before.z,destination.z,low)
		flight.velocity.x=0; flight.velocity.z=0
		flight.acceleration.x=0; flight.acceleration.z=0
		_blocked_climb_time=2.0
		step_floor=maxf(ground_floor,_ground_floor_at(destination))
	if is_finite(step_floor) and destination.y<step_floor:
		destination.y=maxf(destination.y,minf(before.y,step_floor))
		flight.velocity.y=maxf(flight.velocity.y,0)
		flight.acceleration.y=maxf(flight.acceleration.y,0)
	var attitude: Basis=flight.global_basis
	flight.global_position=before
	global_basis=attitude
	flight.global_basis=attitude
	for i in _solids.size(): _solids[i].transform=flight.visual.transform*_original_transforms[i]
	var collision:=move_and_collide(destination-before)
	flight.position=Vector3.ZERO
	if collision!=null:
		flight.velocity=flight.velocity.slide(collision.get_normal())
		if absf(collision.get_normal().y)<.7: _blocked_climb_time=2.0
		flight.acceleration=Vector3.ZERO
	velocity=flight.velocity
	gun.target=target
	gun.update_weapon(delta,velocity.length())

func _ground_floor_at(point: Vector3) -> float:
	var floor_height: float=-INF
	var space:=get_world_3d().direct_space_state
	var excluded: Array[RID]=[get_rid()]
	if target is CollisionObject3D: excluded.append(target.get_rid())
	# Center plus perimeter covers skids, nose and tail while pitched/banked.
	for i in range(9):
		var offset:=Vector3.ZERO
		if i>0:
			var angle:=float(i-1)*TAU/8.0
			offset=Vector3(cos(angle),0,sin(angle))*7.0
		var origin:=point+offset+Vector3.UP*ground_clearance
		var ray:=PhysicsRayQueryParameters3D.create(origin,point+offset-Vector3.UP*600,1,excluded)
		var hit:=space.intersect_ray(ray)
		if not hit.is_empty(): floor_height=maxf(floor_height,hit.position.y+ground_clearance)
	return floor_height

func choose_destination() -> Vector3:
	var offset:=global_position-target.global_position; offset.y=0
	if offset.length_squared()<1: offset=Vector3.BACK
	var radial:=offset.normalized()
	# Slowly circle while close; keep return fire feasible instead of racing past.
	var preferred:=radial.rotated(Vector3.UP,orbit_speed/maxf(engagement_distance,10)*.65)
	var space:=get_world_3d().direct_space_state
	var shape:=SphereShape3D.new(); shape.radius=7.0
	for turn in [0.0,.5,-.5,1.0,-1.0,PI]:
		var candidate: Vector3=target.global_position+preferred.rotated(Vector3.UP,turn)*engagement_distance+Vector3.UP*height_offset
		var q:=PhysicsShapeQueryParameters3D.new(); q.shape=shape
		q.transform.origin=candidate+Vector3.UP*2; q.exclude=[get_rid()]; q.collision_mask=1
		if space.intersect_shape(q,1).is_empty(): return candidate
	# A narrow alley/roof obstruction can force a higher approach; never teleport.
	var above:=target.global_position+Vector3.UP*(height_offset+25)
	var ray:=PhysicsRayQueryParameters3D.create(above+Vector3.UP*350,above-Vector3.UP*60,1,[get_rid()])
	var ground:=space.intersect_ray(ray)
	if not ground.is_empty(): above.y=maxf(above.y,ground.position.y+12)
	return above

func _on_depleted(_info) -> void:
	if is_dead: return
	is_dead=true
	gun.stop(); set_physics_process(false)
	# Deferred transition keeps physics queries and power-hit callbacks valid.
	_finish_destruction.call_deferred()

func _finish_destruction() -> void:
	if not is_inside_tree(): return
	var model: Node3D=flight.visual
	var pose:=model.global_transform
	collision_layer=0; collision_mask=0
	flight.hide(); health_label.hide()
	var effect: Node3D=EXPLOSION.instantiate(); effect.position=position+Vector3.UP*2
	effect.set_script(AIRCRAFT_EXPLOSION_SCRIPT)
	get_parent().add_child(effect); effect.global_position=global_position+Vector3.UP*2
	wreck=WRECK.new(); wreck.lifetime=wreck_lifetime
	get_parent().add_child(wreck)
	wreck.global_transform=pose
	wreck.linear_velocity=Vector3(velocity.x,minf(velocity.y,-2.0),velocity.z)
	wreck.angular_velocity=Vector3(.45,.15,.7)
	wreck.model.get_node("MainRotorPivot").rotation=model.get_node("MainRotorPivot").rotation
	wreck.model.get_node("TailRotorPivot").rotation=model.get_node("TailRotorPivot").rotation
	defeated.emit()
	queue_free()

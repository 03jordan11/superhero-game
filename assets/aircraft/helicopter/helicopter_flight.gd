extends Node3D
## Kinematic flight presentation shared by patrols and future encounter guidance.
## Guidance requests world-space velocity/acceleration; this node limits response.
@export_group("Flight response")
@export_range(1.0, 100.0, 1.0, "suffix:m/s") var maximum_speed := 65.0
@export_range(0.1, 12.0, 0.1, "suffix:m/s²") var maximum_acceleration := 4.0
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var maximum_climb_speed := 5.0
@export_range(0.1, 10.0, 0.1, "suffix:m/s²") var vertical_acceleration := 2.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var velocity_response := 1.0
@export_range(0.05, 3.0, 0.05, "suffix:s") var acceleration_response := 0.35
@export_group("Attitude")
@export_range(1.0, 45.0, 1.0, "suffix:°") var maximum_bank_degrees := 30.0
@export_range(1.0, 25.0, 1.0, "suffix:°") var maximum_pitch_degrees := 14.0
@export_range(1.0, 90.0, 1.0, "suffix:°/s") var heading_rate_degrees := 35.0
@export_range(0.05, 4.0, 0.05, "suffix:s") var attitude_response := 0.7
## Approximate drag compensation: gives about 4 degrees nose-down at 38 m/s.
@export_range(0.0, 0.002, 0.00001) var cruise_pitch_drag := 0.00048

var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var requested_velocity := Vector3.ZERO
var requested_acceleration := Vector3.ZERO
var bank_degrees := 0.0
var pitch_degrees := 0.0
var _heading := 0.0
var _bank := 0.0
var _pitch := 0.0
@onready var visual: Node3D = $Helicopter

func _ready() -> void:
	visual.rotors_spinning = true
	visual.parked_collision_enabled = false
	_heading = global_rotation.y

func set_flight_command(world_velocity: Vector3, feed_forward_acceleration := Vector3.ZERO) -> void:
	requested_velocity = world_velocity
	requested_acceleration = feed_forward_acceleration

## Spawn already established in flight. Do not use for mid-flight route changes.
func initialize_flight(world_position: Vector3, world_velocity: Vector3, world_acceleration := Vector3.ZERO) -> void:
	global_position = world_position
	velocity = world_velocity
	acceleration = world_acceleration
	set_flight_command(world_velocity,world_acceleration)
	_update_attitude(0.0,true)
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	advance_flight(delta)

func advance_flight(delta: float) -> void:
	if delta <= 0.0: return
	var desired := Vector3(requested_velocity.x,0,requested_velocity.z).limit_length(maxf(maximum_speed,0.1))
	desired.y = clampf(requested_velocity.y,-maximum_climb_speed,maximum_climb_speed)
	var target_accel := (desired-velocity)/maxf(velocity_response,0.05)+requested_acceleration
	var horizontal := Vector3(target_accel.x,0,target_accel.z).limit_length(maxf(maximum_acceleration,0.1))
	horizontal.y = clampf(target_accel.y,-vertical_acceleration,vertical_acceleration)
	acceleration = acceleration.lerp(horizontal,1.0-exp(-delta/maxf(acceleration_response,0.01)))
	var previous_velocity := velocity
	velocity += acceleration*delta
	# Trapezoidal integration avoids the systematic outward drift of Euler steps.
	global_position += (previous_velocity+velocity)*0.5*delta
	_update_attitude(delta)

func _update_attitude(delta: float, immediate := false) -> void:
	var speed := Vector2(velocity.x,velocity.z).length()
	if speed > 0.5:
		var heading := atan2(-velocity.x,-velocity.z)
		_heading = heading if immediate else rotate_toward(_heading,heading,deg_to_rad(heading_rate_degrees)*delta)
	var yaw_basis := Basis(Vector3.UP,_heading)
	var right := yaw_basis.x
	var forward := -yaw_basis.z
	# Bank corresponds to the lateral force needed for a coordinated level turn.
	var target_bank := clampf(-atan2(acceleration.dot(right),9.81),-deg_to_rad(maximum_bank_degrees),deg_to_rad(maximum_bank_degrees))
	var drag := speed*speed*cruise_pitch_drag
	var target_pitch := clampf(-atan2(acceleration.dot(forward)+drag,9.81),-deg_to_rad(maximum_pitch_degrees),deg_to_rad(maximum_pitch_degrees))
	var weight := 1.0 if immediate else 1.0-exp(-delta/maxf(attitude_response,0.01))
	_bank = lerpf(_bank,target_bank,weight)
	_pitch = lerpf(_pitch,target_pitch,weight)
	global_basis = yaw_basis
	visual.rotation = Vector3(_pitch,0,_bank)
	bank_degrees = rad_to_deg(_bank)
	pitch_degrees = rad_to_deg(_pitch)

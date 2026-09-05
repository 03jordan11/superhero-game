class_name PlayerVehicleInteractor
extends Node

## Owns vehicle pickup, carry, drop, and throw behavior for a Player body.

signal vehicle_released(vehicle: RigidBody3D, release_speed: float)
signal throw_charge_changed(is_visible: bool, hold_time: float, max_charge_time: float)

@export_category("Vehicle Pickup")
@export var vehicle_pickup_range: float = 12.0
@export var held_vehicle_offset: Vector3 = Vector3(0.0, 1.5, -2.0)
@export var vehicle_throw_charge_time: float = 1.2
@export var vehicle_throw_min_hold_time: float = 0.2
@export var vehicle_throw_min_speed: float = 20.0
@export var vehicle_throw_max_speed: float = 75.0
@export var vehicle_throw_spin_speed: float = 10.0
@export var vehicle_throw_release_distance: float = 5.0

var player_body: CharacterBody3D
var camera: Camera3D
var held_vehicle: RigidBody3D
var held_vehicle_parent: Node
var held_vehicle_collision_layer: int
var held_vehicle_collision_mask: int
var vehicle_throw_hold_time: float = 0.0
var is_charging_vehicle_throw: bool = false
var _last_published_throw_hold_time: float = -1.0
var _last_published_throw_visibility: bool = false


func setup(target_player_body: CharacterBody3D, target_camera: Camera3D) -> void:
	player_body = target_player_body
	camera = target_camera


func has_held_vehicle() -> bool:
	return held_vehicle != null


func is_charging_throw() -> bool:
	return is_charging_vehicle_throw


func get_throw_charge_percent() -> float:
	if not is_charging_vehicle_throw:
		return 0.0
	return vehicle_throw_hold_time / maxf(vehicle_throw_charge_time, 0.001)


func try_pick_up_vehicle() -> bool:
	if held_vehicle != null or player_body == null or camera == null:
		return false

	var ray_start := camera.global_position
	var ray_end := ray_start + -camera.global_transform.basis.z * vehicle_pickup_range
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [player_body.get_rid()]
	var hit := player_body.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if not collider is RigidBody3D:
		return false

	var vehicle := collider as RigidBody3D
	if vehicle.get_parent() == null or vehicle.get_parent().name != &"Vehicles":
		return false

	vehicle.freeze = true
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	held_vehicle_parent = vehicle.get_parent()
	held_vehicle_collision_layer = vehicle.collision_layer
	held_vehicle_collision_mask = vehicle.collision_mask
	vehicle.collision_layer = 0
	vehicle.collision_mask = 0
	vehicle.reparent(player_body)
	vehicle.position = held_vehicle_offset
	held_vehicle = vehicle
	return true


func update_throw(delta: float, input_snapshot: PlayerInputSnapshot) -> void:
	if held_vehicle == null:
		return

	if input_snapshot.vehicle_interact_just_pressed:
		is_charging_vehicle_throw = true
		vehicle_throw_hold_time = 0.0

	if is_charging_vehicle_throw and input_snapshot.vehicle_interact_pressed:
		var max_charge_time := maxf(vehicle_throw_charge_time, 0.001)
		vehicle_throw_hold_time = minf(vehicle_throw_hold_time + delta, max_charge_time)

	if is_charging_vehicle_throw and input_snapshot.vehicle_interact_just_released:
		if vehicle_throw_hold_time >= vehicle_throw_min_hold_time:
			_throw_held_vehicle()
		else:
			drop_held_vehicle()
	_publish_throw_charge()


func drop_held_vehicle() -> void:
	_release_held_vehicle(Vector3.ZERO)


func _throw_held_vehicle() -> void:
	if held_vehicle == null or player_body == null or camera == null:
		return

	var throw_percent := vehicle_throw_hold_time / maxf(vehicle_throw_charge_time, 0.001)
	var throw_speed := lerpf(vehicle_throw_min_speed, vehicle_throw_max_speed, throw_percent)
	var throw_direction := -camera.global_transform.basis.z.normalized()
	var spin_axis := (
		camera.global_transform.basis.x + camera.global_transform.basis.y * 0.25
	).normalized()
	var spin_speed := vehicle_throw_spin_speed * lerpf(0.4, 1.0, throw_percent)
	var release_direction := Vector3(throw_direction.x, 0.0, throw_direction.z).normalized()
	if release_direction.length_squared() > 0.0:
		held_vehicle.global_position = (
			player_body.global_position
			+ release_direction * vehicle_throw_release_distance
			+ Vector3.UP * held_vehicle_offset.y
		)
	_release_held_vehicle(
		throw_direction * throw_speed + player_body.velocity,
		spin_axis * spin_speed
	)


func _release_held_vehicle(
	release_velocity: Vector3,
	release_angular_velocity: Vector3 = Vector3.ZERO
) -> void:
	if held_vehicle == null:
		return

	var vehicle := held_vehicle
	vehicle.reparent(held_vehicle_parent)
	vehicle.collision_layer = held_vehicle_collision_layer
	vehicle.collision_mask = held_vehicle_collision_mask
	vehicle.freeze = false
	vehicle.sleeping = false
	vehicle.linear_velocity = release_velocity
	vehicle.angular_velocity = release_angular_velocity
	held_vehicle = null
	held_vehicle_parent = null
	vehicle_throw_hold_time = 0.0
	is_charging_vehicle_throw = false
	_publish_throw_charge()
	vehicle_released.emit(vehicle, release_velocity.length())


func _publish_throw_charge(force: bool = false) -> void:
	if (
		not force
		and is_charging_vehicle_throw == _last_published_throw_visibility
		and is_equal_approx(
			vehicle_throw_hold_time,
			_last_published_throw_hold_time
		)
	):
		return
	_last_published_throw_visibility = is_charging_vehicle_throw
	_last_published_throw_hold_time = vehicle_throw_hold_time
	throw_charge_changed.emit(
		is_charging_vehicle_throw,
		vehicle_throw_hold_time,
		maxf(vehicle_throw_charge_time, 0.001)
	)

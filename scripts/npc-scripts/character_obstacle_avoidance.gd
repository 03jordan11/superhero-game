class_name CharacterObstacleAvoidance
extends RefCounted

var look_ahead_distance: float = 3.0
var emergency_distance: float = 0.75
var probe_radius: float = 0.5
var probe_height: float = 0.9
var turn_angle_degrees: float = 55.0
var turn_commit_duration: float = 0.75
var collision_mask: int = 1

var _turn_sign: float = 1.0
var _turn_commit_remaining: float = 0.0
var _committed_turn_angle_degrees: float = 55.0
var _probe_shape := SphereShape3D.new()


func configure(
	new_look_ahead_distance: float,
	new_emergency_distance: float,
	new_probe_radius: float,
	new_probe_height: float,
	new_turn_angle_degrees: float,
	new_turn_commit_duration: float,
	new_collision_mask: int
) -> void:
	look_ahead_distance = new_look_ahead_distance
	emergency_distance = new_emergency_distance
	probe_radius = new_probe_radius
	probe_height = new_probe_height
	turn_angle_degrees = new_turn_angle_degrees
	_committed_turn_angle_degrees = turn_angle_degrees
	turn_commit_duration = new_turn_commit_duration
	collision_mask = new_collision_mask
	_probe_shape.radius = probe_radius


func get_steered_direction(
	body: CharacterBody3D,
	desired_direction: Vector3,
	delta: float
) -> Vector3:
	var horizontal_direction := Vector3(desired_direction.x, 0.0, desired_direction.z)
	if horizontal_direction.length_squared() < 0.01:
		_turn_commit_remaining = 0.0
		return Vector3.ZERO

	horizontal_direction = horizontal_direction.normalized()
	_turn_commit_remaining = maxf(_turn_commit_remaining - delta, 0.0)

	var forward_clearance := _get_clearance(body, horizontal_direction)
	if forward_clearance >= look_ahead_distance:
		if _turn_commit_remaining <= 0.0:
			return horizontal_direction
		return _get_committed_turn_direction(horizontal_direction)

	var turn_radians := deg_to_rad(turn_angle_degrees)
	var left_direction := horizontal_direction.rotated(Vector3.UP, turn_radians)
	var right_direction := horizontal_direction.rotated(Vector3.UP, -turn_radians)
	var left_clearance := _get_clearance(body, left_direction)
	var right_clearance := _get_clearance(body, right_direction)

	if left_clearance > right_clearance:
		_turn_sign = 1.0
	elif right_clearance > left_clearance:
		_turn_sign = -1.0
	else:
		_turn_sign *= -1.0

	_committed_turn_angle_degrees = (
		90.0 if forward_clearance < emergency_distance else turn_angle_degrees
	)
	_turn_commit_remaining = turn_commit_duration
	return _get_committed_turn_direction(horizontal_direction)


func _get_committed_turn_direction(direction: Vector3) -> Vector3:
	return direction.rotated(
		Vector3.UP,
		deg_to_rad(_committed_turn_angle_degrees) * _turn_sign
	).normalized()


func _get_clearance(body: CharacterBody3D, direction: Vector3) -> float:
	var probe_distances: Array[float] = [
		emergency_distance,
		look_ahead_distance / 3.0,
		look_ahead_distance * 2.0 / 3.0,
		look_ahead_distance
	]
	for distance in probe_distances:
		if _is_blocked(body, body.global_position + direction * distance):
			return maxf(distance - emergency_distance, 0.0)
	return look_ahead_distance


func _is_blocked(body: CharacterBody3D, probe_position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe_shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		probe_position + Vector3.UP * probe_height
	)
	query.collision_mask = collision_mask
	query.exclude = [body.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var collisions: Array[Dictionary] = body.get_world_3d().direct_space_state.intersect_shape(query)
	for collision in collisions:
		var collider: Object = collision.get("collider")
		# Characters are handled by their own behavior, rather than becoming
		# obstacles that make civilians orbit the player or each other.
		if collider is CharacterBody3D:
			continue
		return true

	return false

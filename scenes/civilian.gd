extends "res://scripts/npc_base.gd"

enum State {
	IDLE,
	WANDER,
	WALK_TO_DESTINATION,
	FLEE,
	PANIC,
	KNOCKED_DOWN,
	DEAD
}

@export var walk_speed: float = 2.5
@export var min_wander_time: float = 2.0
@export var max_wander_time: float = 5.0
@export var flee_speed: float = 5.5
@export_range(1.0, 180.0, 1.0) var flee_vision_angle_degrees: float = 110.0
@export var flee_direction_change_cooldown: float = 1.0
@export var obstacle_look_ahead_distance: float = 3.0
@export var obstacle_emergency_distance: float = 0.75
@export var obstacle_probe_radius: float = 0.5
@export var obstacle_probe_height: float = 0.9
@export_range(1.0, 90.0, 1.0) var obstacle_turn_angle_degrees: float = 55.0
@export var obstacle_turn_commit_duration: float = 0.75
@export var obstacle_collision_mask: int = 1

var current_state: State = State.WANDER

var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var flee_target: Node3D
var flee_direction: Vector3 = Vector3.ZERO
var flee_direction_change_cooldown_remaining: float = 0.0
var obstacle_avoidance := CharacterObstacleAvoidance.new()

func _ready() -> void:
	super()
	add_to_group(&"civilian")
	obstacle_avoidance.configure(
		obstacle_look_ahead_distance,
		obstacle_emergency_distance,
		obstacle_probe_radius,
		obstacle_probe_height,
		obstacle_turn_angle_degrees,
		obstacle_turn_commit_duration,
		obstacle_collision_mask
	)


func _process_behavior(delta: float) -> void:
	match current_state:
		State.IDLE:
			handle_idle()

		State.WANDER:
			handle_wander(delta)

		State.WALK_TO_DESTINATION:
			pass

		State.FLEE:
			handle_flee(delta)

		State.PANIC:
			pass

		State.KNOCKED_DOWN:
			pass

	_apply_obstacle_avoidance(delta)


func _apply_obstacle_avoidance(delta: float) -> void:
	var desired_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if desired_velocity.length_squared() < 0.01:
		return

	var movement_speed := desired_velocity.length()
	var steered_direction := obstacle_avoidance.get_steered_direction(
		self,
		desired_velocity,
		delta
	)
	velocity.x = steered_direction.x * movement_speed
	velocity.z = steered_direction.z * movement_speed
	look_at(global_position + steered_direction, Vector3.UP)


func _on_damage_received(damage_info) -> void:
	var damage_source: Node3D = damage_info.source as Node3D
	if is_instance_valid(damage_source):
		start_flee(damage_source)
	else:
		_start_flee_from_impact(damage_info.impact_origin)


func _on_died() -> void:
	current_state = State.DEAD


func start_flee(target: Node3D) -> void:
	if is_dead or not is_instance_valid(target):
		return

	flee_target = target
	current_state = State.FLEE
	flee_direction_change_cooldown_remaining = flee_direction_change_cooldown
	_set_flee_direction_away_from_target()


func _start_flee_from_impact(impact_origin: Vector3) -> void:
	flee_target = null
	flee_direction = global_position - impact_origin
	flee_direction.y = 0.0
	if flee_direction.length_squared() < 0.01:
		flee_direction = global_transform.basis.z
		flee_direction.y = 0.0
	flee_direction = flee_direction.normalized()
	current_state = State.FLEE
	flee_direction_change_cooldown_remaining = flee_direction_change_cooldown


func handle_flee(delta: float) -> void:
	flee_direction_change_cooldown_remaining = maxf(
		flee_direction_change_cooldown_remaining - delta,
		0.0
	)
	if (
		is_instance_valid(flee_target)
		and
		flee_direction_change_cooldown_remaining <= 0.0
		and _is_flee_target_in_vision_cone()
	):
		_set_flee_direction_away_from_target()
		flee_direction_change_cooldown_remaining = flee_direction_change_cooldown

	velocity.x = flee_direction.x * flee_speed
	velocity.z = flee_direction.z * flee_speed
	if flee_direction.length_squared() > 0.01:
		look_at(global_position + flee_direction, Vector3.UP)
	animation_controller.call("set_is_fleeing")


func _set_flee_direction_away_from_target() -> void:
	if not is_instance_valid(flee_target):
		return

	flee_direction = global_position - flee_target.global_position
	flee_direction.y = 0.0
	if flee_direction.length_squared() < 0.01:
		flee_direction = global_transform.basis.z
		flee_direction.y = 0.0
	flee_direction = flee_direction.normalized()


func _is_flee_target_in_vision_cone() -> bool:
	var direction_to_target := flee_target.global_position - global_position
	direction_to_target.y = 0.0
	if direction_to_target.length_squared() < 0.01:
		return true

	var forward := -global_transform.basis.z.normalized()
	var vision_threshold := cos(deg_to_rad(flee_vision_angle_degrees * 0.5))
	return forward.dot(direction_to_target.normalized()) >= vision_threshold


func handle_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	animation_controller.call("set_is_walking", false)


func handle_wander(delta: float) -> void:
	animation_controller.call("set_is_walking", true)
	wander_timer -= delta
	
	if wander_timer <- 0:
		pick_new_wander_direction()
	
	velocity.x = wander_direction.x * walk_speed
	velocity.z = wander_direction.z * walk_speed

	# Turn the NPC toward the direction she's walking.
	if wander_direction.length_squared() > 0.01:
		look_at(global_position + wander_direction, Vector3.UP)
		
func pick_new_wander_direction() -> void:
	var random_angle := randf_range(0.0, TAU)

	wander_direction = Vector3(
		sin(random_angle),
		0.0,
		cos(random_angle)
	).normalized()

	wander_timer = randf_range(min_wander_time, max_wander_time)
		

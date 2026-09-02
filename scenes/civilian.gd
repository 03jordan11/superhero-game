extends CharacterBody3D

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
@export var max_health: float = 100.0
@export var knockback_speed: float = 8.0
@export var knockback_deceleration: float = 8.0
@export var chest_hit_stun_duration: float = 0.75
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
var health: float = 100.0
var is_dead: bool = false

var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var is_hit_reacting: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var chest_hit_stun_remaining: float = 0.0
var is_waiting_for_chest_hit_stun: bool = false
var knockback_stun_remaining: float = 0.0
var is_waiting_for_knockback_stun: bool = false
var flee_target: Node3D
var flee_direction: Vector3 = Vector3.ZERO
var flee_direction_change_cooldown_remaining: float = 0.0
var obstacle_avoidance := CharacterObstacleAvoidance.new()

@onready var animation_controller: CivilianAnimationController = $CivilianAnimationController
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	health = max_health
	obstacle_avoidance.configure(
		obstacle_look_ahead_distance,
		obstacle_emergency_distance,
		obstacle_probe_radius,
		obstacle_probe_height,
		obstacle_turn_angle_degrees,
		obstacle_turn_commit_duration,
		obstacle_collision_mask
	)
	_update_health_label()

func _physics_process(delta: float) -> void:
	# Keep the civilian grounded regardless of their current behavior state.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_health_label()
		return

	if is_hit_reacting:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(
			Vector3.ZERO,
			knockback_deceleration * delta
		)
		move_and_slide()
		_update_health_label()
		if is_waiting_for_chest_hit_stun:
			if animation_controller.is_chest_hit_animation_playing():
				return

			chest_hit_stun_remaining = maxf(chest_hit_stun_remaining - delta, 0.0)
			if chest_hit_stun_remaining > 0.0:
				return

			is_waiting_for_chest_hit_stun = false
			is_hit_reacting = false
			return

		if is_waiting_for_knockback_stun:
			if animation_controller.call("is_hit_playing"):
				return

			knockback_stun_remaining = maxf(knockback_stun_remaining - delta, 0.0)
			if knockback_stun_remaining > 0.0:
				return

			is_waiting_for_knockback_stun = false
			is_hit_reacting = false
			return

		if not animation_controller.call("is_hit_playing"):
			is_hit_reacting = false
		return

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
	move_and_slide()
	_update_health_label()


func _update_health_label() -> void:
	health_label.text = str(roundi(health))


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


func take_hit(
	damage: float = 1.0,
	hit_reaction: StringName = &"chest",
	impact_origin: Vector3 = Vector3.ZERO,
	impact_direction: Vector3 = Vector3.ZERO
) -> void:
	if is_dead:
		return

	health = maxf(health - damage, 0.0)
	if health <= 0.0:
		_die()
		return
	_start_flee_from_impact(impact_origin)

	is_hit_reacting = true
	is_waiting_for_chest_hit_stun = false
	is_waiting_for_knockback_stun = false
	knockback_velocity = Vector3.ZERO
	match hit_reaction:
		&"knockback":
			is_waiting_for_knockback_stun = true
			knockback_stun_remaining = chest_hit_stun_duration * 2.0
			_apply_knockback_from(impact_origin, impact_direction)
			animation_controller.call("play_knockback")
		&"ground_slam":
			is_waiting_for_knockback_stun = true
			knockback_stun_remaining = chest_hit_stun_duration * 2.0
			_apply_knockback_from(impact_origin)
			animation_controller.call("play_ground_slam_knockback")
		_:
			is_waiting_for_chest_hit_stun = true
			chest_hit_stun_remaining = chest_hit_stun_duration
			animation_controller.call("play_hit")


func _die() -> void:
	is_dead = true
	current_state = State.DEAD
	is_hit_reacting = false
	is_waiting_for_chest_hit_stun = false
	is_waiting_for_knockback_stun = false
	knockback_velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	animation_controller.play_death()
	_update_health_label()


func start_flee(target: Node3D) -> void:
	if not is_instance_valid(target):
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


func _apply_knockback_from(
	impact_origin: Vector3,
	impact_direction: Vector3 = Vector3.ZERO
) -> void:
	var face_impact_direction := impact_origin - global_position
	face_impact_direction.y = 0.0
	if impact_direction.length_squared() > 0.01:
		# A directed hit (the combo finisher) always throws exactly along the
		# player's punch direction, so the civilian's back is aligned to it.
		face_impact_direction = -impact_direction
		face_impact_direction.y = 0.0
	elif face_impact_direction.length_squared() < 0.01:
		face_impact_direction = -global_transform.basis.z
		face_impact_direction.y = 0.0

	# First face the attacker, then throw the civilian through the direction
	# their back is facing. This keeps the visual reaction and movement aligned.
	face_impact_direction = face_impact_direction.normalized()
	look_at(global_position + face_impact_direction, Vector3.UP)
	var back_direction := global_transform.basis.z.normalized()
	knockback_velocity = back_direction * knockback_speed


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
		

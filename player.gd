extends PlayerCharacter

const HARD_LANDING_EFFECT_SCENE: PackedScene = preload("res://effects/hard_landing_effect.tscn")
const DAMAGE_INFO_SCRIPT = preload("res://scripts/damage_info.gd")
const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/health_component.gd")

signal health_depleted(damage_info)

@export_category("Power Jump")
@export var min_jump_velocity: float = 8.0
@export var max_jump_velocity: float = 35.0
@export var max_jump_charge_time: float = 1.5
@export var max_forward_jump_boost: float = 30.0
@export_range(0.0, 1.0, 0.05) var power_jump_charge_threshold: float = 0.2

var jump_charge: float = 0.0
var jump_hold_time: float = 0.0
var is_charging_jump: bool = false
var is_jump_active: bool = false

@export_category("Landing Impact")
@export var heavy_landing_speed: float = 20.0
@export var super_landing_speed: float = 35.0
@export var landing_impact_radius: float = 5.0
@export var heavy_landing_damage: float = 10.0
@export var super_landing_damage: float = 50.0
@export var heavy_landing_vehicle_damage: float = 50.0
@export var super_landing_vehicle_damage: float = 100.0

var max_downward_speed: float = 0.0
var was_airborne: bool = false
var max_downward_speed_for_camera_effects: float = 0.0
var was_on_floor_for_camera_effects: bool = false

@export_category("Movement")
@export var minimum_run_speed: float = 20.0
@export var run_speed_per_attribute_point: float = 5.0
@export_range(0.1, 1.0, 0.05) var walk_speed_ratio: float = 0.5
@export var acceleration: float = 40.0
@export var sprint_acceleration: float = 5.0
@export var sprint_deceleration: float = 20.0
@export_range(0.0, 1.0, 0.05) var air_control_strength: float = 0.35
@export var gravity: float = 24.0

@export_category("Flight")
@export var flight_acceleration: float = 5.0
@export var flight_deceleration: float = 20.0
@export var flight_stop_deceleration: float = 25.0
@export var flight_hover_speed_threshold: float = 0.1
@export var flight_turn_speed: float = 10.0
@export var ground_slam_speed: float = 80.0
@export var ground_slam_minimum_height: float = 4.0
@export_range(0.8, 1.0, 0.01) var flight_knockout_speed_percent: float = 0.98
@export var flight_knockout_rebound_speed: float = 8.0
@export var flight_knockout_rebound_upward_speed: float = 3.0
@export var flight_knockout_rebound_deceleration: float = 8.0

@export_category("Wall Run")
@export var wall_run_speed: float = 12.0
@export var wall_run_stick_speed: float = 1.0
@export var wall_run_side_speed: float = 8.0
@export_range(0.0, 1.0, 0.05) var wall_run_corner_normal_threshold: float = 0.9
@export var wall_jump_velocity: float = 10.0
@export var wall_jump_push: float = 12.0

@export_category("Attributes")
@export var stats: PlayerStats = PlayerStats.new()
@export var strength: int = 1:
	get:
		return stats.strength
	set(value):
		stats.strength = value
@export var speed: int = 1:
	get:
		return stats.speed
	set(value):
		stats.speed = value
@export var resilience: int = 1:
	get:
		return stats.resilience
	set(value):
		stats.resilience = value
@export var health_per_resilience: float = 100.0

@export_category("Abilities")
@export var abilities: PlayerAbilities = PlayerAbilities.new()

@export_category("Damage Reaction")
@export var hit_slowdown_duration: float = 0.5
@export_range(0.0, 1.0, 0.05) var hit_slowdown_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.05) var resilience_one_knockdown_chance: float = 0.9
@export_range(2, 999, 1) var knockdown_immunity_resilience: int = 10
@export var knockdown_stun_duration: float = 0.75

var is_flying: bool = false
var current_flight_speed: float = 0.0
var current_ground_speed: float = 0.0
var is_ground_slamming: bool = false
var ground_slam_target: Vector3
var ground_slam_impact_pending: bool = false
var is_knocked_out: bool = false
var is_dead: bool = false
var is_wall_running: bool = false
var wall_run_normal: Vector3
var wall_run_has_left_ground: bool = false
var hit_slowdown_remaining: float = 0.0
var has_knockout_landed: bool = false
var knockout_stun_remaining: float = 0.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_camera_angle: float = -70.0
@export var max_camera_angle: float = 50.0

@export_category("Vehicle Pickup")
@export var vehicle_pickup_range: float = 12.0
@export var held_vehicle_offset: Vector3 = Vector3(0.0, 1.5, -2.0)
@export var vehicle_throw_charge_time: float = 1.2
@export var vehicle_throw_min_hold_time: float = 0.2
@export var vehicle_throw_min_speed: float = 20.0
@export var vehicle_throw_max_speed: float = 75.0
@export var vehicle_throw_spin_speed: float = 10.0
@export var vehicle_throw_release_distance: float = 5.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var player_hud: PlayerHud = $ChargeUI
@onready var superhero_character: Node3D = $SuperheroCharacter
@onready var character_animation_player: AnimationPlayer = $SuperheroCharacter/CharacterAnimationPlayer
@onready var state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var grounded_state: PlayerGroundedState = $PlayerStateMachine/GroundedState
@onready var movement_motor: PlayerMovementMotor = $PlayerMovementMotor
@onready var animation_controller: PlayerAnimationController = $PlayerAnimationController
@onready var combat_controller: PlayerCombatController = $PlayerCombatController
@onready var landing_target: Node = $LandingTarget
@onready var camera_effects: Node = $PlayerCameraEffects
@onready var explosion_controller: Node = $"../ExplosionController"

var superhero_character_default_rotation: Vector3
var held_vehicle: RigidBody3D
var held_vehicle_parent: Node
var held_vehicle_collision_layer: int
var held_vehicle_collision_mask: int
var vehicle_throw_hold_time: float = 0.0
var is_charging_vehicle_throw: bool = false
var armed_thrown_vehicles: Array[Dictionary] = []
var health_component


func _ready() -> void:
	add_to_group(&"player")
	if not state_machine.initialize(self, grounded_state):
		push_error("Player state machine failed to initialize.")
	stats.stat_changed.connect(_on_stat_changed)
	health_component = HEALTH_COMPONENT_SCRIPT.new(_calculate_max_health())
	health_component.health_changed.connect(_on_health_changed)
	health_component.depleted.connect(_on_health_depleted)
	current_ground_speed = _get_walk_speed()
	_update_health_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	superhero_character_default_rotation = superhero_character.rotation
	_update_jump_charge_ui()
	_update_vehicle_throw_ui()
	_update_sprint_speed_ui()
	animation_controller.setup(character_animation_player, is_on_floor())
	combat_controller.setup(animation_controller)
	camera_effects.call("setup", spring_arm)
	was_on_floor_for_camera_effects = is_on_floor()


func apply_damage(damage_info) -> bool:
	var was_flying := is_flying
	if not health_component.apply_damage(damage_info):
		return false
	if is_dead:
		return true

	_start_hit_slowdown()
	var knockdown_chance := _get_flight_hit_knockdown_chance()
	if was_flying and knockdown_chance > 0.0 and randf() < knockdown_chance:
		_start_damage_flight_knockout()
	elif not animation_controller.is_fighting and not is_knocked_out:
		animation_controller.play_hit_reaction()
	return true


func get_current_health() -> float:
	return health_component.current_health


func get_max_health() -> float:
	return health_component.max_health


func get_stats() -> PlayerStats:
	return stats


func _calculate_max_health() -> float:
	return stats.get_max_health(health_per_resilience)


func _update_health_hud() -> void:
	player_hud.set_health(
		health_component.current_health,
		health_component.max_health
	)


func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_update_health_hud()


func _on_stat_changed(stat_id: StringName, _value: int) -> void:
	if stat_id == PlayerStats.RESILIENCE and health_component != null:
		health_component.set_max_health(_calculate_max_health())


func _on_health_depleted(damage_info) -> void:
	_die()
	health_depleted.emit(damage_info)


func _die() -> void:
	if is_dead:
		return
	if not state_machine.transition_to(&"DeadState"):
		push_error("Player could not enter DeadState.")


func _enter_dead_state() -> void:
	if is_dead:
		return

	is_dead = true
	is_flying = false
	is_ground_slamming = false
	is_knocked_out = true
	is_wall_running = false
	has_knockout_landed = false
	knockout_stun_remaining = 0.0
	current_flight_speed = 0.0
	is_charging_jump = false
	is_jump_active = false
	jump_charge = 0.0
	jump_hold_time = 0.0
	velocity.y = minf(velocity.y, 0.0)
	if held_vehicle != null:
		_drop_held_vehicle()
	animation_controller.play_death()


func _start_hit_slowdown() -> void:
	hit_slowdown_remaining = maxf(hit_slowdown_duration, 0.0)
	var speed_multiplier := clampf(hit_slowdown_multiplier, 0.0, 1.0)
	velocity.x *= speed_multiplier
	velocity.z *= speed_multiplier
	if is_flying:
		velocity.y *= speed_multiplier
		current_flight_speed *= speed_multiplier


func _update_hit_slowdown(delta: float) -> void:
	hit_slowdown_remaining = maxf(hit_slowdown_remaining - delta, 0.0)


func _get_movement_speed_multiplier() -> float:
	if hit_slowdown_remaining <= 0.0:
		return 1.0
	return clampf(hit_slowdown_multiplier, 0.0, 1.0)


func _get_flight_hit_knockdown_chance() -> float:
	return stats.get_flight_knockdown_chance(
		resilience_one_knockdown_chance,
		knockdown_immunity_resilience
	)


func _start_damage_flight_knockout() -> void:
	if not state_machine.transition_to(&"KnockedDownState", {"cause": &"damage"}):
		push_error("Player could not enter KnockedDownState from damage.")


func _enter_knocked_down_state(context: Dictionary) -> void:
	is_flying = false
	is_ground_slamming = false
	is_knocked_out = true
	has_knockout_landed = false
	knockout_stun_remaining = 0.0
	current_flight_speed = 0.0

	if context.get("cause") == &"flight_collision":
		var collision_normal: Vector3 = context.get("collision_normal", Vector3.ZERO)
		var collision_position: Vector3 = context.get("collision_position", global_position)
		var impact_speed: float = context.get("impact_speed", 0.0)
		velocity = collision_normal * flight_knockout_rebound_speed
		velocity.y += flight_knockout_rebound_upward_speed
		camera_effects.call("trigger_knockout")
		_spawn_hard_landing_effect(impact_speed, collision_position, collision_normal)
	else:
		velocity.y = minf(velocity.y, 0.0)
	animation_controller.play_knockdown()


func _input(event: InputEvent) -> void:
	if DebugManager.developer_menu_open and (
		event is InputEventMouseMotion or event is InputEventMouseButton
	):
		return

	if event is InputEventMouseMotion:
		# Keep the body fixed while a knockdown or death animation is playing.
		if not is_knocked_out and not is_dead:
			rotate_y(-event.screen_relative.x * mouse_sensitivity)

		# Aim camera up/down.
		spring_arm.rotation.x -= event.screen_relative.y * mouse_sensitivity
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x,
			deg_to_rad(min_camera_angle),
			deg_to_rad(max_camera_angle)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_flying or is_jump_active:
				_try_start_ground_slam()
			elif not is_knocked_out and not is_ground_slamming and not is_wall_running and is_on_floor():
				combat_controller.request_punch()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_snapshot := PlayerInputSnapshot.capture()
	state_machine.handle_input(input_snapshot)

	_update_hit_slowdown(delta)
	_check_thrown_vehicle_impacts()

	if not is_dead:
		if held_vehicle == null and input_snapshot.vehicle_interact_just_pressed:
			_try_pick_up_vehicle()
		elif held_vehicle != null:
			_handle_vehicle_throw(delta, input_snapshot)

	if input_snapshot.toggle_flight_just_pressed:
		_toggle_flight_state()

	var active_state := state_machine.active_state
	if (
		active_state is PlayerGroundedState
		or active_state is PlayerJumpChargingState
		or active_state is PlayerAirborneState
		or active_state is PlayerWallRunState
	):
		# Flight rotates only the visible character. Restore its normal orientation
		# before using ordinary locomotion behavior.
		superhero_character.rotation = superhero_character_default_rotation
	state_machine.physics_update(delta, input_snapshot)
		
	if not is_dead:
		combat_controller.update_punch_momentum(
			self,
			delta,
			strength,
			_get_movement_speed_multiplier()
		)

	_update_jump_charge_ui()
	_update_vehicle_throw_ui()
	_update_sprint_speed_ui()

	if not is_on_floor():
		max_downward_speed_for_camera_effects = max(
			max_downward_speed_for_camera_effects,
			-velocity.y
		)

	# Actually move the character with the same collision system in both modes.
	move_and_slide()
	_sync_grounded_airborne_state(is_on_floor())
	if is_ground_slamming and (
		is_on_floor()
		or get_slide_collision_count() > 0
		or global_position.distance_to(ground_slam_target) <= 0.1
	):
		_finish_ground_slam()
	_update_landing_camera_effects()
	if is_flying and (
		current_flight_speed >= _get_run_speed() * flight_knockout_speed_percent
		and get_slide_collision_count() > 0
	):
		var knockout_collision := get_slide_collision(0)
		_start_flight_knockout(
			knockout_collision.get_normal(),
			knockout_collision.get_position(),
			current_flight_speed
		)
	if is_wall_running:
		if not is_on_floor():
			wall_run_has_left_ground = true
		elif wall_run_has_left_ground:
			_finish_wall_run()
	else:
		var wall_collision_normal := _get_wall_collision_normal()
		if _can_start_wall_run(wall_collision_normal, input_snapshot):
			_start_wall_run(wall_collision_normal, input_snapshot)
	if is_knocked_out and not is_dead and is_on_floor():
		_begin_knockout_stun()
	_update_flight_speed_ui()
	animation_controller.update_animation(
		is_flying,
		is_knocked_out,
		is_dead,
		velocity,
		is_charging_jump,
		is_on_floor(),
		input_snapshot.sprint_pressed,
		input_snapshot.move_forward_pressed
	)


func _sync_grounded_airborne_state(is_grounded: bool) -> void:
	if not (
		state_machine.active_state is PlayerGroundedState
		or state_machine.active_state is PlayerAirborneState
	):
		return

	var destination := &"GroundedState" if is_grounded else &"AirborneState"
	if state_machine.get_active_state_id() != destination:
		state_machine.transition_to(destination)


func _try_pick_up_vehicle() -> void:
	if held_vehicle != null:
		return

	var ray_start := camera.global_position
	var ray_end := ray_start + -camera.global_transform.basis.z * vehicle_pickup_range
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")

	if not collider is RigidBody3D:
		return

	var vehicle := collider as RigidBody3D
	if vehicle.get_parent() == null or vehicle.get_parent().name != &"Vehicles":
		return

	vehicle.freeze = true
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	held_vehicle_parent = vehicle.get_parent()
	held_vehicle_collision_layer = vehicle.collision_layer
	held_vehicle_collision_mask = vehicle.collision_mask
	vehicle.collision_layer = 0
	vehicle.collision_mask = 0
	vehicle.reparent(self)
	vehicle.position = held_vehicle_offset
	held_vehicle = vehicle


func _handle_vehicle_throw(
	delta: float,
	input_snapshot: PlayerInputSnapshot
) -> void:
	if input_snapshot.vehicle_interact_just_pressed:
		is_charging_vehicle_throw = true
		vehicle_throw_hold_time = 0.0

	if is_charging_vehicle_throw and input_snapshot.vehicle_interact_pressed:
		var max_charge_time := maxf(vehicle_throw_charge_time, 0.001)
		vehicle_throw_hold_time = minf(
			vehicle_throw_hold_time + delta,
			max_charge_time
		)

	if is_charging_vehicle_throw and input_snapshot.vehicle_interact_just_released:
		if vehicle_throw_hold_time >= vehicle_throw_min_hold_time:
			_throw_held_vehicle()
		else:
			_drop_held_vehicle()


func _drop_held_vehicle() -> void:
	_release_held_vehicle(Vector3.ZERO)


func _throw_held_vehicle() -> void:
	var throw_percent := vehicle_throw_hold_time / maxf(vehicle_throw_charge_time, 0.001)
	var throw_speed := lerpf(vehicle_throw_min_speed, vehicle_throw_max_speed, throw_percent)
	var throw_direction := -camera.global_transform.basis.z.normalized()
	var spin_axis := (
		camera.global_transform.basis.x + camera.global_transform.basis.y * 0.25
	).normalized()
	var spin_speed := vehicle_throw_spin_speed * lerpf(0.4, 1.0, throw_percent)
	var release_direction := Vector3(throw_direction.x, 0.0, throw_direction.z).normalized()
	if held_vehicle != null and release_direction.length_squared() > 0.0:
		held_vehicle.global_position = (
			global_position
			+ release_direction * vehicle_throw_release_distance
			+ Vector3.UP * held_vehicle_offset.y
		)
	_release_held_vehicle(
		throw_direction * throw_speed + velocity,
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
	if release_velocity.length() >= _get_explosion_minimum_impact_speed():
		vehicle.contact_monitor = true
		vehicle.max_contacts_reported = 8
		armed_thrown_vehicles.append({
			"body": vehicle,
			"last_speed": release_velocity.length()
		})
	held_vehicle = null
	held_vehicle_parent = null
	vehicle_throw_hold_time = 0.0
	is_charging_vehicle_throw = false


func _check_thrown_vehicle_impacts() -> void:
	for vehicle_index in range(armed_thrown_vehicles.size() - 1, -1, -1):
		var vehicle_state := armed_thrown_vehicles[vehicle_index]
		var vehicle: Vehicle = vehicle_state["body"] as Vehicle
		if not is_instance_valid(vehicle):
			armed_thrown_vehicles.remove_at(vehicle_index)
			continue

		var impact_speed: float = float(vehicle_state["last_speed"])
		if vehicle.get_contact_count() > 0 and impact_speed >= _get_explosion_minimum_impact_speed():
			var damage_info = DAMAGE_INFO_SCRIPT.new(
				vehicle.get_current_health(),
				vehicle.global_position,
				Vector3.ZERO,
				&"none",
				self,
				impact_speed
			)
			vehicle.apply_damage(damage_info)
			armed_thrown_vehicles.remove_at(vehicle_index)
			continue

		vehicle_state["last_speed"] = vehicle.linear_velocity.length()


func _get_explosion_minimum_impact_speed() -> float:
	return float(explosion_controller.get("minimum_impact_speed"))


func _toggle_flight_state() -> void:
	if is_ground_slamming or is_knocked_out or is_dead:
		return

	if is_flying:
		var destination := &"GroundedState" if is_on_floor() else &"AirborneState"
		state_machine.transition_to(destination)
	else:
		state_machine.transition_to(&"FlyingState")


func _can_enter_flying_state() -> bool:
	return (
		abilities != null
		and abilities.is_unlocked(PlayerAbilities.FLIGHT)
		and not is_ground_slamming
		and not is_knocked_out
		and not is_dead
	)


func _enter_flying_state() -> void:
	is_flying = true
	# Start flight from a neutral vertical state instead of carrying a fall.
	velocity.y = 0.0
	current_flight_speed = _get_walk_speed()
	jump_charge = 0.0
	jump_hold_time = 0.0
	is_charging_jump = false
	is_jump_active = false
	max_downward_speed = 0.0
	was_airborne = false


func _exit_flying_state() -> void:
	is_flying = false
	current_ground_speed = _get_walk_speed()


func _handle_flight(
	delta: float,
	input_snapshot: PlayerInputSnapshot
) -> void:
	var vertical_input := 0.0
	if input_snapshot.jump_pressed:
		vertical_input += 1.0
	if input_snapshot.descend_pressed:
		vertical_input -= 1.0

	var flight_direction := movement_motor.get_flight_direction(
		input_snapshot.movement,
		vertical_input,
		camera.global_transform.basis
	)
	var has_flight_input := flight_direction.length_squared() > 0.0
	var speed_multiplier := _get_movement_speed_multiplier()
	var attribute_speed_multiplier := _get_speed_attribute_multiplier()
	var current_base_flight_speed := _get_walk_speed() * speed_multiplier
	var current_max_flight_speed := _get_run_speed() * speed_multiplier

	if has_flight_input:
		current_flight_speed = movement_motor.approach_flight_speed(
			current_flight_speed,
			current_base_flight_speed,
			current_max_flight_speed,
			input_snapshot.sprint_pressed,
			flight_acceleration,
			flight_deceleration,
			attribute_speed_multiplier,
			delta
		)
		velocity = flight_direction * current_flight_speed
	else:
		# Releasing all flight controls preserves momentum, then slows the
		# character into a true hover instead of stopping instantly.
		velocity = movement_motor.approach_hover_velocity(
			velocity,
			flight_stop_deceleration,
			attribute_speed_multiplier,
			delta
		)
		if velocity.length() <= flight_hover_speed_threshold:
			velocity = Vector3.ZERO
		current_flight_speed = velocity.length()

	_update_flight_visual_rotation(delta)


func _try_start_ground_slam() -> void:
	if not is_flying and not is_jump_active:
		return

	var landing_hit: Dictionary = landing_target.call("get_landing_hit")
	if landing_hit.is_empty():
		return

	var target_position: Vector3 = landing_hit.position
	var height_above_target := global_position.y - target_position.y
	if height_above_target <= 0.0:
		return
	if height_above_target < ground_slam_minimum_height:
		return
	if not state_machine.transition_to(
		&"GroundSlamState",
		{"target_position": target_position}
	):
		return


func _can_enter_ground_slam_state(context: Dictionary) -> bool:
	if (
		abilities == null
		or not abilities.is_unlocked(PlayerAbilities.GROUND_SLAM)
		or is_ground_slamming
		or is_knocked_out
		or is_dead
		or (not is_flying and not is_jump_active)
		or not context.has("target_position")
	):
		return false

	var target_position: Vector3 = context["target_position"]
	return global_position.y - target_position.y >= ground_slam_minimum_height


func _enter_ground_slam_state(context: Dictionary) -> void:
	is_jump_active = false
	is_ground_slamming = true
	ground_slam_target = context["target_position"]
	current_flight_speed = 0.0
	jump_charge = 0.0
	jump_hold_time = 0.0
	is_charging_jump = false


func _exit_ground_slam_state() -> void:
	is_ground_slamming = false


func _handle_ground_slam() -> void:
	velocity = movement_motor.get_ground_slam_velocity(
		global_position,
		ground_slam_target,
		ground_slam_speed,
		_get_speed_attribute_multiplier()
	)


func _finish_ground_slam() -> void:
	ground_slam_impact_pending = true
	velocity = Vector3.ZERO
	var destination := &"GroundedState" if is_on_floor() else &"AirborneState"
	if not state_machine.transition_to(destination):
		push_error("Player could not leave GroundSlamState.")


func _start_flight_knockout(
	collision_normal: Vector3,
	collision_position: Vector3,
	impact_speed: float
) -> void:
	var context := {
		"cause": &"flight_collision",
		"collision_normal": collision_normal,
		"collision_position": collision_position,
		"impact_speed": impact_speed,
	}
	if not state_machine.transition_to(&"KnockedDownState", context):
		push_error("Player could not enter KnockedDownState from a flight collision.")


func _handle_knockout(delta: float) -> void:
	if has_knockout_landed:
		velocity = Vector3.ZERO
		knockout_stun_remaining = maxf(knockout_stun_remaining - delta, 0.0)
		if knockout_stun_remaining <= 0.0:
			_finish_knockout()
		return

	# Knockout intentionally ignores movement and flight input until landing.
	velocity.x = move_toward(
		velocity.x,
		0.0,
		flight_knockout_rebound_deceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		0.0,
		flight_knockout_rebound_deceleration * delta
	)
	velocity = movement_motor.apply_gravity(velocity, gravity, delta)


func _handle_death(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		flight_knockout_rebound_deceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		0.0,
		flight_knockout_rebound_deceleration * delta
	)
	if not is_on_floor():
		velocity = movement_motor.apply_gravity(velocity, gravity, delta)
	else:
		velocity = Vector3.ZERO


func _begin_knockout_stun() -> void:
	if has_knockout_landed:
		return
	has_knockout_landed = true
	knockout_stun_remaining = maxf(knockdown_stun_duration, 0.0)
	velocity = Vector3.ZERO
	if knockout_stun_remaining <= 0.0:
		_finish_knockout()


func _finish_knockout() -> void:
	if not state_machine.transition_to(&"GroundedState"):
		push_error("Player could not leave KnockedDownState.")


func _exit_knocked_down_state() -> void:
	is_knocked_out = false
	has_knockout_landed = false
	knockout_stun_remaining = 0.0
	velocity = Vector3.ZERO


func _update_flight_visual_rotation(delta: float) -> void:
	var flight_direction := velocity.normalized()
	var target_rotation: Quaternion
	if flight_direction.length_squared() == 0.0:
		# Hovering is upright and follows the player's usual camera-facing yaw,
		# rather than keeping the tilted orientation from the last movement input.
		target_rotation = global_transform.basis.get_rotation_quaternion() * (
			Basis.from_euler(superhero_character_default_rotation).get_rotation_quaternion()
		)
	else:
		# The imported character's visible forward axis is its local +Z axis.
		# Build a stable orientation that points that axis along the flight direction.
		var reference_up := Vector3.UP
		if abs(flight_direction.dot(reference_up)) > 0.98:
			reference_up = Vector3.FORWARD
		var right := reference_up.cross(flight_direction).normalized()
		var up := flight_direction.cross(right).normalized()
		target_rotation = Basis(right, up, flight_direction).get_rotation_quaternion()

	var current_rotation := superhero_character.global_transform.basis.get_rotation_quaternion()
	var rotation_weight: float = min(flight_turn_speed * delta, 1.0)

	var character_transform := superhero_character.global_transform
	character_transform.basis = Basis(current_rotation.slerp(target_rotation, rotation_weight))
	superhero_character.global_transform = character_transform


func _update_normal_vertical_movement(delta: float) -> void:
	if not is_on_floor():
		was_airborne = true
		velocity = movement_motor.apply_gravity(velocity, gravity, delta)
		max_downward_speed = max(max_downward_speed, -velocity.y)
	elif was_airborne:
		_handle_landing()


func _stop_horizontal_movement_if_fighting() -> bool:
	if animation_controller.is_fighting:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	return false


func _update_normal_jump_input(
	delta: float,
	input_snapshot: PlayerInputSnapshot
) -> void:
	if is_on_floor():
		if input_snapshot.jump_pressed:
			jump_hold_time += delta
			if is_charging_jump:
				jump_charge += delta
				jump_charge = min(jump_charge, max_jump_charge_time)
			elif jump_hold_time >= power_jump_charge_threshold:
				state_machine.transition_to(
					&"JumpChargingState",
					{"initial_charge_delta": delta}
				)

		if input_snapshot.jump_just_released:
			_release_jump()
	else:
		if input_snapshot.jump_just_released:
			_reset_jump_charge()


func _apply_normal_horizontal_movement(
	delta: float,
	input_snapshot: PlayerInputSnapshot
) -> void:
	var direction := movement_motor.get_horizontal_direction(
		input_snapshot.movement,
		transform.basis
	)

	var walk_speed := _get_walk_speed()
	var run_speed := _get_run_speed()
	var is_sprinting := input_snapshot.sprint_pressed and direction.length_squared() > 0.0
	current_ground_speed = movement_motor.approach_ground_speed(
		current_ground_speed,
		walk_speed,
		run_speed,
		is_sprinting,
		sprint_acceleration,
		sprint_deceleration,
		_get_speed_attribute_multiplier(),
		delta
	)
	var target_speed := current_ground_speed
	target_speed *= _get_movement_speed_multiplier()

	if is_charging_jump:
		# Stay planted while building power for a jump.
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var horizontal_acceleration := movement_motor.get_horizontal_acceleration(
			acceleration,
			_get_speed_attribute_multiplier(),
			air_control_strength,
			is_on_floor()
		)
		velocity = movement_motor.approach_horizontal_velocity(
			velocity,
			direction,
			target_speed,
			horizontal_acceleration,
			delta
		)


func _can_enter_jump_charging_state() -> bool:
	return (
		abilities != null
		and abilities.is_unlocked(PlayerAbilities.POWER_JUMP)
		and not animation_controller.is_fighting
		and not is_flying
		and not is_ground_slamming
		and not is_wall_running
		and not is_knocked_out
		and not is_dead
	)


func _enter_jump_charging_state(context: Dictionary) -> void:
	is_charging_jump = true
	jump_charge = minf(
		jump_charge + float(context.get("initial_charge_delta", 0.0)),
		max_jump_charge_time
	)


func _release_jump() -> void:
	var was_charging := is_charging_jump
	if was_charging:
		var charge_percent := jump_charge / max_jump_charge_time
		velocity = movement_motor.get_charged_jump_velocity(
			velocity,
			-transform.basis.z,
			charge_percent,
			min_jump_velocity,
			max_jump_velocity,
			max_forward_jump_boost,
			_get_movement_speed_multiplier()
		)
	else:
		# A quick tap performs a regular jump without interrupting movement.
		velocity = movement_motor.get_quick_jump_velocity(
			velocity,
			min_jump_velocity
		)

	is_jump_active = true
	_reset_jump_charge()
	if was_charging and not state_machine.transition_to(&"AirborneState"):
		push_error("Player could not leave JumpChargingState.")


func _reset_jump_charge() -> void:
	jump_hold_time = 0.0
	jump_charge = 0.0
	is_charging_jump = false


func _can_start_wall_run(
	collision_normal: Vector3,
	input_snapshot: PlayerInputSnapshot
) -> bool:
	return _can_enter_wall_run_state({
		"collision_normal": collision_normal,
		"input_snapshot": input_snapshot,
	})


func _can_enter_wall_run_state(context: Dictionary) -> bool:
	var input_snapshot := context.get("input_snapshot") as PlayerInputSnapshot
	if (
		abilities == null
		or not abilities.is_unlocked(PlayerAbilities.WALL_RUN)
		or is_flying
		or is_ground_slamming
		or is_knocked_out
		or is_dead
		or is_wall_running
		or input_snapshot == null
		or not input_snapshot.sprint_pressed
		or input_snapshot.movement.length_squared() == 0.0
		or not context.has("collision_normal")
	):
		return false

	var collision_normal: Vector3 = context["collision_normal"]
	return collision_normal != Vector3.ZERO and abs(collision_normal.y) < 0.7


func _get_wall_collision_normal() -> Vector3:
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		var collision_normal := collision.get_normal()
		if abs(collision_normal.y) < 0.7:
			return collision_normal
	return Vector3.ZERO


func _start_wall_run(
	collision_normal: Vector3,
	input_snapshot: PlayerInputSnapshot
) -> void:
	if not state_machine.transition_to(
		&"WallRunState",
		{
			"collision_normal": collision_normal,
			"input_snapshot": input_snapshot,
		}
	):
		return


func _enter_wall_run_state(context: Dictionary) -> void:
	is_wall_running = true
	wall_run_normal = context["collision_normal"]
	wall_run_has_left_ground = false
	velocity = _get_wall_run_velocity(context["input_snapshot"])


func _handle_wall_run(
	delta: float,
	input_snapshot: PlayerInputSnapshot
) -> void:
	if input_snapshot.movement.length_squared() == 0.0:
		_finish_wall_run()
		velocity = movement_motor.apply_gravity(velocity, gravity, delta)
		return

	if input_snapshot.jump_just_pressed:
		velocity = wall_run_normal * wall_jump_push + Vector3.UP * wall_jump_velocity
		is_jump_active = true
		_finish_wall_run()
		return

	var current_wall_normal := _get_wall_collision_normal()
	if (
		current_wall_normal == Vector3.ZERO
		or current_wall_normal.dot(wall_run_normal) < wall_run_corner_normal_threshold
	):
		_finish_wall_run()
		velocity = movement_motor.apply_gravity(velocity, gravity, delta)
		return

	wall_run_normal = current_wall_normal
	velocity = _get_wall_run_velocity(input_snapshot)


func _get_wall_run_velocity(input_snapshot: PlayerInputSnapshot) -> Vector3:
	var lateral_input := input_snapshot.lateral_movement
	if not input_snapshot.sprint_pressed:
		lateral_input = 0.0

	return movement_motor.get_wall_run_velocity(
		wall_run_normal,
		transform.basis.x,
		lateral_input,
		wall_run_speed,
		wall_run_stick_speed,
		wall_run_side_speed,
		_get_speed_attribute_multiplier(),
		_get_movement_speed_multiplier()
	)


func _finish_wall_run() -> void:
	var destination := &"GroundedState" if is_on_floor() else &"AirborneState"
	if not state_machine.transition_to(destination):
		push_error("Player could not leave WallRunState.")


func _exit_wall_run_state() -> void:
	is_wall_running = false
	wall_run_has_left_ground = false


func _get_run_speed() -> float:
	return stats.get_run_speed(
		minimum_run_speed,
		run_speed_per_attribute_point
	)


func _get_walk_speed() -> float:
	return stats.get_walk_speed(
		minimum_run_speed,
		run_speed_per_attribute_point,
		walk_speed_ratio
	)


func _get_speed_attribute_multiplier() -> float:
	return stats.get_speed_multiplier(
		minimum_run_speed,
		run_speed_per_attribute_point
	)

func _update_jump_charge_ui() -> void:
	player_hud.set_jump_charge(jump_charge / max_jump_charge_time)


func _update_vehicle_throw_ui() -> void:
	var charge_percent := 0.0
	if is_charging_vehicle_throw:
		charge_percent = vehicle_throw_hold_time / maxf(vehicle_throw_charge_time, 0.001)
	player_hud.set_vehicle_throw_charge(is_charging_vehicle_throw, charge_percent)


func _update_sprint_speed_ui() -> void:
	var walk_speed := _get_walk_speed()
	var run_speed := _get_run_speed()
	var sprint_percent := 0.0
	if run_speed > walk_speed:
		sprint_percent = inverse_lerp(walk_speed, run_speed, current_ground_speed)
	player_hud.set_sprint_speed(sprint_percent)


func _update_flight_speed_ui() -> void:
	var speed_percent := 0.0
	var run_speed := _get_run_speed()
	if is_flying and run_speed > 0.0:
		speed_percent = velocity.length() / run_speed
	player_hud.set_flight_speed(speed_percent)


func _update_landing_camera_effects() -> void:
	var is_grounded := is_on_floor()
	if is_grounded and not was_on_floor_for_camera_effects:
		var landing_speed := max_downward_speed_for_camera_effects
		# Flight slams are intentional high-impact dives, even if the camera ray
		# reaches the target at a shallow angle.
		if ground_slam_impact_pending:
			landing_speed = maxf(
				landing_speed,
				ground_slam_speed * _get_speed_attribute_multiplier()
			)

		camera_effects.call("trigger_landing", landing_speed)
		if landing_speed >= heavy_landing_speed:
			var ground_contact := _get_ground_contact()
			_spawn_hard_landing_effect(
				landing_speed,
				ground_contact.position,
				ground_contact.normal,
				&"ground_slam" if ground_slam_impact_pending else &"knockback"
			)
		ground_slam_impact_pending = false
		max_downward_speed_for_camera_effects = 0.0
	elif is_grounded:
		max_downward_speed_for_camera_effects = 0.0

	was_on_floor_for_camera_effects = is_grounded


func _handle_landing() -> void:
	var landing_category := "Normal"
	if max_downward_speed >= super_landing_speed:
		landing_category = "Super"
	elif max_downward_speed >= heavy_landing_speed:
		landing_category = "Heavy"

	player_hud.show_landing_category(landing_category)
	print("Landing impact: %s" % landing_category)

	max_downward_speed = 0.0
	was_airborne = false
	is_jump_active = false


func _spawn_hard_landing_effect(
	impact_speed: float,
	spawn_position: Vector3,
	surface_normal: Vector3,
	hit_reaction: StringName = &"knockback"
) -> void:
	_apply_landing_impact_damage(spawn_position, impact_speed, hit_reaction)
	var effect := HARD_LANDING_EFFECT_SCENE.instantiate()
	effect.call(
		"configure_impact",
		impact_speed,
		heavy_landing_speed,
		super_landing_speed,
		surface_normal
	)
	get_tree().current_scene.add_child(effect)
	effect.global_position = spawn_position


func _apply_landing_impact_damage(
	impact_position: Vector3,
	impact_speed: float,
	hit_reaction: StringName
) -> void:
	var impact_shape := SphereShape3D.new()
	impact_shape.radius = landing_impact_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = impact_shape
	query.transform = Transform3D(Basis.IDENTITY, impact_position)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit_results: Array[Dictionary] = (
		get_world_3d().direct_space_state.intersect_shape(query)
	)
	var hit_instance_ids: Dictionary = {}
	var damage_percent := clampf(
		inverse_lerp(heavy_landing_speed, super_landing_speed, impact_speed),
		0.0,
		1.0
	)
	var damage := lerpf(heavy_landing_damage, super_landing_damage, damage_percent)
	var vehicle_damage: float = (
		super_landing_vehicle_damage
		if impact_speed >= super_landing_speed or hit_reaction == &"ground_slam"
		else heavy_landing_vehicle_damage
	)
	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if collider == null or not collider.has_method("apply_damage"):
			continue
		var collider_id := collider.get_instance_id()
		if hit_instance_ids.has(collider_id):
			continue
		hit_instance_ids[collider_id] = true
		var is_explodable: bool = (
			collider is Node and (collider as Node).is_in_group(&"explodable")
		)
		var damage_amount: float = vehicle_damage if is_explodable else damage
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			damage_amount,
			impact_position,
			Vector3.ZERO,
			hit_reaction,
			self,
			impact_speed
		)
		collider.call("apply_damage", damage_info)


func _get_ground_contact() -> Dictionary:
	var ray_origin := global_position + Vector3.UP
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + Vector3.DOWN * 5.0
	)
	ray_query.exclude = [get_rid()]
	var ground_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
	if not ground_hit.is_empty():
		return ground_hit
	return {
		"position": global_position,
		"normal": Vector3.UP,
	}

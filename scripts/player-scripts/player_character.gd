class_name PlayerCharacter
extends CharacterBody3D

signal health_depleted(damage_info)
signal jump_charge_changed(current_charge: float, max_charge: float)
signal ground_speed_changed(current_speed: float, walk_speed: float, run_speed: float)
signal flight_speed_changed(current_speed: float, max_speed: float, is_active: bool)

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
var has_knockout_landed: bool = false
var knockout_stun_remaining: float = 0.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_camera_angle: float = -70.0
@export var max_camera_angle: float = 50.0

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
@onready var status_effects: PlayerStatusEffects = $PlayerStatusEffects
@onready var damage_receiver: PlayerDamageReceiver = $PlayerDamageReceiver
@onready var vehicle_interactor: PlayerVehicleInteractor = $PlayerVehicleInteractor
@onready var landing_impact_controller: PlayerLandingImpactController = (
	$PlayerLandingImpactController
)
@onready var landing_target: Node = $LandingTarget
@onready var camera_effects: Node = $PlayerCameraEffects

var superhero_character_default_rotation: Vector3


func _ready() -> void:
	add_to_group(&"player")
	if not state_machine.initialize(self, grounded_state):
		push_error("Player state machine failed to initialize.")
	stats.stat_changed.connect(_on_stat_changed)
	current_ground_speed = _get_walk_speed()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	superhero_character_default_rotation = superhero_character.rotation
	animation_controller.setup(character_animation_player, is_on_floor())
	combat_controller.setup(animation_controller)
	damage_receiver.setup(
		_calculate_max_health(),
		status_effects,
		combat_controller,
		animation_controller
	)
	damage_receiver.death_requested.connect(_on_damage_death_requested)
	damage_receiver.hit_slowdown_requested.connect(_on_damage_hit_slowdown_requested)
	damage_receiver.flight_knockdown_requested.connect(_on_damage_flight_knockdown_requested)
	vehicle_interactor.setup(self, camera)
	vehicle_interactor.vehicle_released.connect(_on_vehicle_released)
	camera_effects.call("setup", spring_arm)
	landing_impact_controller.initialize(self, camera_effects)
	player_hud.setup(
		self,
		damage_receiver,
		vehicle_interactor,
		landing_impact_controller
	)


func apply_damage(damage_info) -> bool:
	return damage_receiver.apply_damage(
		damage_info,
		is_flying,
		_get_flight_hit_knockdown_chance(),
		is_knocked_out
	)


func _on_damage_hit_slowdown_requested(speed_multiplier: float) -> void:
	velocity.x *= speed_multiplier
	velocity.z *= speed_multiplier
	if is_flying:
		velocity.y *= speed_multiplier
		current_flight_speed *= speed_multiplier


func _on_damage_flight_knockdown_requested() -> void:
	if not state_machine.transition_to(&"KnockedDownState", {"cause": &"damage"}):
		push_error("Player could not enter KnockedDownState from damage.")


func get_current_health() -> float:
	return damage_receiver.get_current_health()


func get_max_health() -> float:
	return damage_receiver.get_max_health()


func get_stats() -> PlayerStats:
	return stats


func _calculate_max_health() -> float:
	return stats.get_max_health(health_per_resilience)


func _on_stat_changed(stat_id: StringName, _value: int) -> void:
	if stat_id == PlayerStats.RESILIENCE and damage_receiver != null:
		damage_receiver.set_max_health(_calculate_max_health())


func _on_damage_death_requested(damage_info) -> void:
	_die()
	health_depleted.emit(damage_info)


func _die() -> void:
	if is_dead:
		return
	if not state_machine.transition_to(&"DeadState"):
		push_error("Player could not enter DeadState.")


func _get_flight_hit_knockdown_chance() -> float:
	return stats.get_flight_knockdown_chance(
		resilience_one_knockdown_chance,
		knockdown_immunity_resilience
	)


func _input(event: InputEvent) -> void:
	var debug_manager := get_node_or_null("/root/DebugManager")
	if debug_manager != null and debug_manager.developer_menu_open and (
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

	status_effects.update(delta)

	if not is_dead:
		if not vehicle_interactor.has_held_vehicle() and input_snapshot.vehicle_interact_just_pressed:
			vehicle_interactor.try_pick_up_vehicle()
		elif vehicle_interactor.has_held_vehicle():
			vehicle_interactor.update_throw(delta, input_snapshot)

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
			status_effects.get_movement_speed_multiplier()
		)

	landing_impact_controller.observe_before_move(is_on_floor(), velocity.y)

	# Actually move the character with the same collision system in both modes.
	move_and_slide()
	state_machine.post_physics_update(delta, input_snapshot)
	ground_slam_impact_pending = landing_impact_controller.update_after_move(
		is_on_floor(),
		ground_slam_impact_pending,
		ground_slam_speed,
		_get_speed_attribute_multiplier()
	)
	animation_controller.update_animation(
		is_flying,
		is_knocked_out,
		is_dead,
		combat_controller.is_action_locked(),
		velocity,
		is_charging_jump,
		is_on_floor(),
		input_snapshot.sprint_pressed,
		input_snapshot.move_forward_pressed
	)


func _on_vehicle_released(vehicle: RigidBody3D, release_speed: float) -> void:
	var thrown_vehicle := vehicle as Vehicle
	if thrown_vehicle != null:
		thrown_vehicle.arm_thrown_impact(release_speed, self)


func _toggle_flight_state() -> void:
	if is_ground_slamming or is_knocked_out or is_dead:
		return

	if is_flying:
		var destination := &"GroundedState" if is_on_floor() else &"AirborneState"
		state_machine.transition_to(destination)
	else:
		state_machine.transition_to(&"FlyingState")


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

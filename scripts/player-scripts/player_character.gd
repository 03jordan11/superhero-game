class_name PlayerCharacter
extends CharacterBody3D

const PLAYER_PERF = preload("res://scripts/ui-scripts/player_performance_monitor.gd")

signal jump_charge_changed(current_charge: float, max_charge: float)
signal ground_speed_changed(current_speed: float, walk_speed: float, run_speed: float)
signal flight_speed_changed(current_speed: float, max_speed: float, is_active: bool)
signal flight_charge_changed(active: bool, ratio: float, eligible: bool)

@export_category("Power Jump")
@export var min_jump_velocity: float = 8.0
@export var max_jump_velocity: float = 35.0
@export var max_jump_charge_time: float = 1.5
@export var max_forward_jump_boost: float = 30.0
@export_range(0.0, 1.0, 0.05) var power_jump_charge_threshold: float = 0.2
## Fraction of a fully charged jump's launch velocity and added forward boost.
@export_range(0.1, 1.0, 0.05) var air_jump_power_ratio: float = 0.5

var jump_charge: float = 0.0
var jump_hold_time: float = 0.0
var is_charging_jump: bool = false
var is_jump_active: bool = false
var air_jump_used: bool = false
var charged_jump_output_multiplier: float = 1.0

@export_category("Movement")
@export var minimum_run_speed: float = 20.0
@export var run_speed_per_attribute_point: float = 5.0
@export_range(0.1, 1.0, 0.05) var walk_speed_ratio: float = 0.5
@export var acceleration: float = 40.0
@export var sprint_acceleration: float = 5.0
@export var sprint_deceleration: float = 20.0
@export_range(0.0, 1.0, 0.05) var air_control_strength: float = 0.35
@export var gravity: float = 24.0
@export_range(0.1, 30.0, 0.1) var movement_turn_speed: float = 10.0

@export_category("Flight")
@export var flight_acceleration: float = 5.0
@export var flight_deceleration: float = 20.0
@export var flight_stop_deceleration: float = 25.0
@export var flight_hover_speed_threshold: float = 0.1
@export var flight_turn_speed: float = 10.0
@export_range(0.1, 0.5, 0.01) var flight_charge_hold_threshold: float = 0.2
@export_range(0.2, 5.0, 0.1) var flight_charge_time: float = 1.5
@export var flight_surge_min_speed: float = 45.0
@export var flight_surge_max_speed: float = 120.0
@export_range(0.1, 2.0, 0.05) var flight_surge_duration: float = 0.45
var is_charging_flight: bool = false
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
@onready var superhero_character: Node3D = $SuperheroCharacter
@onready var character_animation_player: AnimationPlayer = $SuperheroCharacter/CharacterAnimationPlayer
@onready var state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var input_controller: Node = $PlayerInputController
@onready var stamina: PlayerStamina = $PlayerStamina
@onready var laser_eyes: PlayerLaserEyes = $PlayerLaserEyes
@onready var bounding_controller: PlayerBoundingController = $PlayerBoundingController
@onready var grounded_state: PlayerGroundedState = $PlayerStateMachine/GroundedState
@onready var flying_state: PlayerFlyingState = $PlayerStateMachine/FlyingState
@onready var movement_motor: PlayerMovementMotor = $PlayerMovementMotor
@onready var animation_controller: PlayerAnimationController = $PlayerAnimationController
@onready var combat_controller: PlayerCombatController = $PlayerCombatController
@onready var status_effects: PlayerStatusEffects = $PlayerStatusEffects
@onready var damage_receiver: PlayerDamageReceiver = $PlayerDamageReceiver
@onready var vehicle_interactor: PlayerVehicleInteractor = $PlayerVehicleInteractor
@onready var rescue_carrier: PlayerRescueCarrier = $PlayerRescueCarrier
@onready var ship_interaction: Node = $PlayerShipInteraction
@onready var target_lock: Node = $PlayerTargetLock
@onready var hostile_grab: PlayerHostileGrab = $PlayerHostileGrab
@onready var landing_impact_controller: PlayerLandingImpactController = (
	$PlayerLandingImpactController
)
@onready var landing_target: Node = $LandingTarget
@onready var camera_effects: Node = $PlayerCameraEffects

var superhero_character_default_rotation: Vector3
var movement_visual_yaw: float = 0.0
# World heading is independent of the camera/root yaw while walking or idle.
var ground_facing_yaw: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	if not state_machine.initialize(self, grounded_state):
		push_error("Player state machine failed to initialize.")
	stats.stat_changed.connect(_on_stat_changed)
	current_ground_speed = _get_walk_speed()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	superhero_character_default_rotation = superhero_character.rotation
	ground_facing_yaw = global_rotation.y
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


func apply_damage(damage_info) -> bool:
	var perf_started := PLAYER_PERF.begin(self)
	var result: bool = _profiled_apply_damage(damage_info)
	PLAYER_PERF.finish(&"player_damage", perf_started)
	return result


func _profiled_apply_damage(damage_info) -> bool:
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


func _calculate_max_health() -> float:
	return stats.get_max_health(health_per_resilience)


func _on_stat_changed(stat_id: StringName, _value: int) -> void:
	if stat_id == PlayerStats.RESILIENCE and damage_receiver != null:
		damage_receiver.set_max_health(_calculate_max_health())


func _on_damage_death_requested(_damage_info) -> void:
	_die()


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


func revive_for_respawn() -> void:
	# Explicit restart of the terminal life state; ordinary healing cannot revive.
	drop_everything()
	ship_interaction.release()
	target_lock.release()
	combat_controller.cancel_punch()
	input_controller.reset()
	bounding_controller.reset()
	flying_state.cancel_charge()
	flying_state.surge_remaining = 0.0
	flying_state.is_boosting = false
	laser_eyes.cancel_input()
	laser_eyes.heat = 0.0
	laser_eyes.overheated = false
	laser_eyes.heat_changed.emit(0.0, false)
	for field in ["is_dead", "is_knocked_out", "is_flying", "is_ground_slamming", "is_wall_running", "wall_run_has_left_ground", "has_knockout_landed", "is_charging_jump", "is_jump_active", "air_jump_used", "ground_slam_impact_pending"]:
		set(field, false)
	velocity = Vector3.ZERO
	current_flight_speed = 0.0
	current_ground_speed = _get_walk_speed()
	jump_charge = 0.0
	jump_hold_time = 0.0
	knockout_stun_remaining = 0.0
	status_effects.hit_slowdown_remaining = 0.0
	stamina.restore_full()
	var health = damage_receiver.health_component
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	animation_controller.is_playing_death = false
	animation_controller.is_knocked_down = false
	animation_controller.is_hit_reacting = false
	animation_controller.is_playing_landing_animation = false
	character_animation_player.stop()
	superhero_character.rotation = superhero_character_default_rotation
	ground_facing_yaw = global_rotation.y
	landing_impact_controller.reset_normal_landing_tracking()
	landing_impact_controller.max_effect_downward_speed = 0.0
	camera_effects.shake_time_remaining = 0.0
	camera_effects.impact_kick_offset = 0.0
	state_machine.initialize(self, grounded_state)
	animation_controller._play_animation("Idle")
	flight_speed_changed.emit(0.0, stats.get_run_speed(minimum_run_speed, run_speed_per_attribute_point), false)
	reset_physics_interpolation()


func _input(event: InputEvent) -> void:
	var perf_started := PLAYER_PERF.begin(self)
	_profiled_input(event)
	PLAYER_PERF.finish(&"player_input", perf_started)


func _profiled_input(event: InputEvent) -> void:
	if get_node("PlayerPowerController").is_selector_open(): return
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	if bindings.is_capturing: return
	var debug_manager := get_node_or_null("/root/DebugManager")
	if debug_manager != null and debug_manager.developer_menu_open:
		return

	if bindings.is_action_press(event, "aim_power") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		# Release before subsequent mouse-motion events in this same frame.
		target_lock.release_for_aim()
		combat_controller.cancel_charge_input()
	if event is InputEventMouseMotion:
		input_controller.apply_look(event.screen_relative * mouse_sensitivity)
	if ship_interaction.is_attached(): return
	if event.is_action_released("attack"):
		combat_controller.release_attack()

	if bindings.is_action_press(event, "attack"):
		if hostile_grab.owns_animation():
			hostile_grab.request_slam()
			return
		# Reserve aimed attacks for the selected power before the next physics snapshot.
		if input_controller.is_power_aim_requested():
			return
		# Continue an existing combo (including its airborne uppercut), and let
		# actual floor contact win over the previous frame's jump flag.
		if not is_dead and not is_knocked_out and combat_controller.is_action_locked():
			combat_controller.begin_attack()
		elif is_flying or (is_jump_active and not is_on_floor()):
			_try_start_ground_slam()
		elif not is_dead and not is_charging_jump and not is_charging_flight and not is_knocked_out and not is_ground_slamming and not is_wall_running and is_on_floor():
			combat_controller.begin_attack()

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var perf_started := PLAYER_PERF.begin(self)
	_profiled_physics_process(delta)
	PLAYER_PERF.finish(&"player_physics", perf_started)


func _profiled_physics_process(delta: float) -> void:
	var input_snapshot: PlayerInputSnapshot = input_controller.capture()
	stamina.begin_tick(input_snapshot.sprint_pressed)

	status_effects.update(delta)
	target_lock.update_lock(delta, input_snapshot)
	if input_snapshot.vehicle_interact_just_pressed:
		for ring_access in get_tree().get_nodes_in_group(&"boxing_ring_access"):
			if ring_access.try_interact(self):
				stamina.finish_tick(delta, Vector3.ZERO, is_on_floor())
				return
		for door in get_tree().get_nodes_in_group(&"hideout_doors"):
			if door.try_interact(self):
				stamina.finish_tick(delta, Vector3.ZERO, is_on_floor())
				return
		for machine in get_tree().get_nodes_in_group(&"power_machines"):
			if machine.try_interact(self):
				stamina.finish_tick(delta, Vector3.ZERO, is_on_floor())
				return
		for bed in get_tree().get_nodes_in_group(&"hideout_beds"):
			if bed.try_interact(self):
				stamina.finish_tick(delta, Vector3.ZERO, is_on_floor())
				return
	if ship_interaction.handle_input(delta, input_snapshot):
		target_lock.release()
		stamina.finish_tick(delta, Vector3.ZERO, is_on_floor())
		return
	laser_eyes.update_power(delta, input_snapshot)

	if not is_dead:
		if rescue_carrier.has_patient():
			if input_snapshot.vehicle_interact_just_pressed: rescue_carrier.drop_patient()
		elif vehicle_interactor.has_held_vehicle():
			vehicle_interactor.update_throw(delta, input_snapshot)
		elif hostile_grab.owns_animation():
			pass # E belongs to the grab controller until its sequence finishes.
		elif input_snapshot.vehicle_interact_just_pressed:
			if not rescue_carrier.try_pick_up() and not hostile_grab.try_grab(): vehicle_interactor.try_pick_up_vehicle()
	hostile_grab.update(delta,input_snapshot)

	flying_state.handle_flight_input(delta, input_snapshot)

	_update_movement_facing(delta, input_snapshot)
	bounding_controller.begin_tick(delta)
	state_machine.physics_update(delta, input_snapshot)

	if not is_dead:
		combat_controller.update_punch_momentum(
			self,
			delta,
			stats.get_effective_strength(),
			status_effects.get_movement_speed_multiplier()
		)

	landing_impact_controller.observe_before_move(is_on_floor(), velocity.y)

	# Actually move the character with the same collision system in both modes.
	var move_started := PLAYER_PERF.begin(self)
	var position_before_move := global_position
	var was_grounded := is_on_floor()
	var incoming_velocity := velocity
	var bounding_excluded := is_flying or is_ground_slamming or ground_slam_impact_pending or is_wall_running or is_dead or is_knocked_out
	move_and_slide()
	if is_on_floor():
		air_jump_used = false
	stamina.finish_tick(delta, global_position - position_before_move, was_grounded and is_on_floor())
	PLAYER_PERF.finish(&"player_move_and_slide", move_started)
	state_machine.post_physics_update(delta, input_snapshot)
	ground_slam_impact_pending = landing_impact_controller.update_after_move(
		is_on_floor(),
		ground_slam_impact_pending,
		ground_slam_speed,
		_get_speed_attribute_multiplier()
	)
	bounding_controller.after_move(was_grounded, incoming_velocity, bounding_excluded)
	var animation_started := PLAYER_PERF.begin(self)
	animation_controller.update_animation(
		is_flying,
		is_knocked_out,
		is_dead,
		combat_controller.is_action_locked(),
		velocity,
		is_charging_jump,
		is_on_floor(),
		input_snapshot.sprint_pressed and stamina.can_boost(),
		velocity.length() > flight_hover_speed_threshold,
		flying_state.is_boosting or flying_state.surge_remaining > 0.0
	)
	PLAYER_PERF.finish(&"player_animation_logic", animation_started)
	hostile_grab.pose_after_move()


func is_carrying() -> bool:
	return vehicle_interactor.has_held_vehicle() or (rescue_carrier != null and rescue_carrier.has_patient()) or (hostile_grab != null and hostile_grab.has_hostile())

func drop_everything() -> void:
	vehicle_interactor.drop_held_vehicle()
	rescue_carrier.drop_patient()
	hostile_grab.drop()


func _update_movement_facing(delta: float, input: PlayerInputSnapshot) -> void:
	var active_state := state_machine.active_state
	if target_lock.has_target() and active_state is PlayerNormalMovementState:
		ground_facing_yaw=global_rotation.y
		_apply_ground_facing_visual()
		return
	if active_state is PlayerGroundedState and not combat_controller.is_action_locked() and not is_charging_flight:
		if input.aim_power_pressed:
			# Aim locks facing to camera yaw, including while standing still.
			ground_facing_yaw = global_rotation.y
		elif input.movement.length_squared() > 0.0001:
			# Keyboard diagonals yield 45-degree headings; sticks stay continuous.
			var target_yaw := global_rotation.y + atan2(-input.movement.x, -input.movement.y)
			ground_facing_yaw = lerp_angle(ground_facing_yaw, target_yaw,
				1.0 - exp(-movement_turn_speed * delta))
		_apply_ground_facing_visual()
	elif active_state is PlayerNormalMovementState or active_state is PlayerWallRunState:
		# Preserve camera-forward jumping, wall running and combat behavior.
		movement_visual_yaw = 0.0 if input.aim_power_pressed else lerp_angle(
			movement_visual_yaw, 0.0, 1.0 - exp(-movement_turn_speed * delta))
		ground_facing_yaw = global_rotation.y + movement_visual_yaw
		superhero_character.rotation = superhero_character_default_rotation
		superhero_character.rotation.y += movement_visual_yaw
	else:
		movement_visual_yaw = 0.0
		ground_facing_yaw = global_rotation.y


func _apply_ground_facing_visual() -> void:
	movement_visual_yaw = wrapf(ground_facing_yaw - global_rotation.y, -PI, PI)
	superhero_character.rotation = superhero_character_default_rotation
	superhero_character.rotation.y += movement_visual_yaw


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
	if is_charging_flight: return
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

extends CharacterBody3D

const HARD_LANDING_EFFECT_SCENE: PackedScene = preload("res://effects/hard_landing_effect.tscn")
const VEHICLE_EXPLOSION_EFFECT_SCENE: PackedScene = preload("res://effects/vehicle_explosion_effect.tscn")

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
@export var walk_speed: float = 10.0
@export var sprint_speed: float = 20.0
@export var acceleration: float = 40.0
@export_range(0.0, 1.0, 0.05) var air_control_strength: float = 0.35
@export var gravity: float = 24.0

@export_category("Flight")
@export var flight_speed: float = 10.0
@export var flight_max_speed: float = 60.0
@export var flight_acceleration: float = 15.0
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
@export_range(1, 999, 1) var strength: int = 1
@export_range(1, 999, 1) var speed: int = 1
@export_range(1, 999, 1) var resilience: int = 1

var is_flying: bool = false
var current_flight_speed: float = 0.0
var is_ground_slamming: bool = false
var ground_slam_target: Vector3
var ground_slam_impact_pending: bool = false
var is_knocked_out: bool = false
var is_wall_running: bool = false
var wall_run_normal: Vector3
var wall_run_has_left_ground: bool = false

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
@export var vehicle_explosion_min_impact_speed: float = 18.0
@export var vehicle_explosion_radius: float = 5.0
@export var vehicle_npc_min_damage: float = 50.0
@export var vehicle_npc_max_damage: float = 100.0
@export var vehicle_explosion_vehicle_damage: float = 100.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var player_hud: PlayerHud = $ChargeUI
@onready var superhero_character: Node3D = $SuperheroCharacter
@onready var character_animation_player: AnimationPlayer = $SuperheroCharacter/CharacterAnimationPlayer
@onready var animation_controller: PlayerAnimationController = $PlayerAnimationController
@onready var combat_controller: PlayerCombatController = $PlayerCombatController
@onready var landing_target: Node = $LandingTarget
@onready var camera_effects: Node = $PlayerCameraEffects

var superhero_character_default_rotation: Vector3
var held_vehicle: RigidBody3D
var held_vehicle_parent: Node
var held_vehicle_collision_layer: int
var held_vehicle_collision_mask: int
var vehicle_throw_hold_time: float = 0.0
var is_charging_vehicle_throw: bool = false
var armed_thrown_vehicles: Array[Dictionary] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	superhero_character_default_rotation = superhero_character.rotation
	_update_jump_charge_ui()
	_update_vehicle_throw_ui()
	animation_controller.setup(character_animation_player, is_on_floor())
	combat_controller.setup(animation_controller)
	_connect_vehicle_destruction_signals()
	camera_effects.call("setup", spring_arm)
	was_on_floor_for_camera_effects = is_on_floor()


func _input(event: InputEvent) -> void:
	if DebugManager.developer_menu_open and (
		event is InputEventMouseMotion or event is InputEventMouseButton
	):
		return

	if event is InputEventMouseMotion:
		# Turn player left/right.
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
	_check_thrown_vehicle_impacts()

	if held_vehicle == null and Input.is_action_just_pressed("pick_up_vehicle"):
		_try_pick_up_vehicle()
	elif held_vehicle != null:
		_handle_vehicle_throw(delta)

	if Input.is_action_just_pressed("toggle_flight") and not is_ground_slamming and not is_knocked_out:
		is_flying = not is_flying
		if is_flying:
			# Start flight from a neutral vertical state instead of carrying a fall.
			velocity.y = 0.0
			current_flight_speed = flight_speed
			jump_charge = 0.0
			jump_hold_time = 0.0
			is_charging_jump = false
			is_jump_active = false
			max_downward_speed = 0.0
			was_airborne = false

	if is_ground_slamming:
		_handle_ground_slam()
	elif is_knocked_out:
		_handle_knockout(delta)
	elif is_flying:
		_handle_flight(delta)
	else:
		# Flight rotates only the visible character. Restore its normal orientation
		# before using the existing grounded movement and camera-facing behavior.
		superhero_character.rotation = superhero_character_default_rotation
		_handle_normal_movement(delta)
		
	combat_controller.update_punch_momentum(self, delta, strength)

	_update_jump_charge_ui()
	_update_vehicle_throw_ui()

	if not is_on_floor():
		max_downward_speed_for_camera_effects = max(
			max_downward_speed_for_camera_effects,
			-velocity.y
		)

	# Actually move the character with the same collision system in both modes.
	move_and_slide()
	if is_ground_slamming and (
		is_on_floor()
		or get_slide_collision_count() > 0
		or global_position.distance_to(ground_slam_target) <= 0.1
	):
		_finish_ground_slam()
	_update_landing_camera_effects()
	if is_flying and (
		current_flight_speed >= flight_max_speed * flight_knockout_speed_percent
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
	elif _can_start_wall_run():
		_start_wall_run(_get_wall_collision_normal())
	if is_knocked_out and is_on_floor():
		_finish_knockout()
	_update_flight_speed_ui()
	animation_controller.update_animation(
		is_flying,
		velocity,
		is_charging_jump,
		is_on_floor(),
		Input.is_action_pressed("sprint"),
		Input.is_action_pressed("move_forward")
	)


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


func _handle_vehicle_throw(delta: float) -> void:
	if Input.is_action_just_pressed("pick_up_vehicle"):
		is_charging_vehicle_throw = true
		vehicle_throw_hold_time = 0.0

	if is_charging_vehicle_throw and Input.is_action_pressed("pick_up_vehicle"):
		var max_charge_time := maxf(vehicle_throw_charge_time, 0.001)
		vehicle_throw_hold_time = minf(
			vehicle_throw_hold_time + delta,
			max_charge_time
		)

	if is_charging_vehicle_throw and Input.is_action_just_released("pick_up_vehicle"):
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
	if release_velocity.length() >= vehicle_explosion_min_impact_speed:
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
		if vehicle.get_contact_count() > 0 and impact_speed >= vehicle_explosion_min_impact_speed:
			vehicle.take_damage(vehicle.health, impact_speed)
			armed_thrown_vehicles.remove_at(vehicle_index)
			continue

		vehicle_state["last_speed"] = vehicle.linear_velocity.length()


func _connect_vehicle_destruction_signals() -> void:
	var vehicle_container: Node = get_node_or_null("../Vehicles")
	if vehicle_container == null:
		return

	for child in vehicle_container.get_children():
		if child is Vehicle:
			var vehicle: Vehicle = child as Vehicle
			vehicle.destroyed.connect(_on_vehicle_destroyed.bind(vehicle))


func _on_vehicle_destroyed(vehicle: Vehicle) -> void:
	if not is_instance_valid(vehicle):
		return

	var impact_speed: float = maxf(
		maxf(vehicle.destruction_impact_speed, vehicle.linear_velocity.length()),
		vehicle_explosion_min_impact_speed
	)
	var explosion_position := vehicle.global_position
	_apply_vehicle_explosion_damage(explosion_position, vehicle, impact_speed)
	_damage_vehicles_in_explosion(explosion_position, vehicle, impact_speed)
	_spawn_vehicle_explosion(explosion_position, impact_speed)
	vehicle.queue_free()


func _apply_vehicle_explosion_damage(
	explosion_position: Vector3,
	vehicle: Vehicle,
	impact_speed: float
) -> void:
	var explosion_shape := SphereShape3D.new()
	explosion_shape.radius = vehicle_explosion_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = explosion_shape
	query.transform = Transform3D(Basis.IDENTITY, explosion_position)
	query.exclude = [get_rid(), vehicle.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit_results: Array[Dictionary] = (
		get_world_3d().direct_space_state.intersect_shape(query)
	)
	var hit_instance_ids: Dictionary = {}
	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if collider == null or not collider.has_method("take_hit"):
			continue
		var collider_id := collider.get_instance_id()
		if hit_instance_ids.has(collider_id):
			continue
		hit_instance_ids[collider_id] = true

		var damage_percent := inverse_lerp(
			vehicle_explosion_min_impact_speed,
			vehicle_throw_max_speed,
			impact_speed
		)
		var damage := lerpf(
			vehicle_npc_min_damage,
			vehicle_npc_max_damage,
			clampf(damage_percent, 0.0, 1.0)
		)
		collider.call(
			"take_hit",
			damage,
			&"knockback",
			explosion_position,
			Vector3.ZERO
		)


func _damage_vehicles_in_explosion(
	explosion_position: Vector3,
	source_vehicle: Vehicle,
	impact_speed: float
) -> void:
	var explosion_shape := SphereShape3D.new()
	explosion_shape.radius = vehicle_explosion_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = explosion_shape
	query.transform = Transform3D(Basis.IDENTITY, explosion_position)
	query.exclude = [source_vehicle.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit_results: Array[Dictionary] = (
		get_world_3d().direct_space_state.intersect_shape(query)
	)
	var hit_instance_ids: Dictionary = {}
	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if not collider is Vehicle:
			continue
		var nearby_vehicle := collider as Vehicle
		var vehicle_id := nearby_vehicle.get_instance_id()
		if hit_instance_ids.has(vehicle_id):
			continue
		hit_instance_ids[vehicle_id] = true
		nearby_vehicle.take_damage(vehicle_explosion_vehicle_damage, impact_speed)


func _spawn_vehicle_explosion(explosion_position: Vector3, impact_speed: float) -> void:
	var effect := VEHICLE_EXPLOSION_EFFECT_SCENE.instantiate()
	effect.call("configure_impact", impact_speed, vehicle_explosion_min_impact_speed)
	get_tree().current_scene.add_child(effect)
	effect.global_position = explosion_position


func _handle_flight(delta: float) -> void:
	var input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var camera_right := camera.global_transform.basis.x
	var camera_forward := -camera.global_transform.basis.z
	var direction := camera_right * input.x - camera_forward * input.y

	var vertical_input := 0.0
	if Input.is_action_pressed("jump"):
		vertical_input += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		vertical_input -= 1.0

	var flight_direction := direction + Vector3.UP * vertical_input
	var has_flight_input := flight_direction.length_squared() > 0.0
	if has_flight_input:
		flight_direction = flight_direction.normalized()

	if has_flight_input:
		if Input.is_action_pressed("sprint"):
			current_flight_speed = move_toward(
				current_flight_speed,
				flight_max_speed,
				flight_acceleration * delta
			)
		else:
			current_flight_speed = maxf(
				flight_speed,
				move_toward(
					current_flight_speed,
					flight_speed,
					flight_deceleration * delta
				)
			)
		velocity = flight_direction * current_flight_speed
	else:
		# Releasing all flight controls preserves momentum, then slows the
		# character into a true hover instead of stopping instantly.
		velocity = velocity.move_toward(Vector3.ZERO, flight_stop_deceleration * delta)
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

	is_flying = false
	is_jump_active = false
	is_ground_slamming = true
	ground_slam_target = target_position
	current_flight_speed = 0.0
	jump_charge = 0.0
	jump_hold_time = 0.0
	is_charging_jump = false


func _handle_ground_slam() -> void:
	var slam_direction := global_position.direction_to(ground_slam_target)
	velocity = slam_direction * ground_slam_speed


func _finish_ground_slam() -> void:
	is_ground_slamming = false
	ground_slam_impact_pending = true
	velocity = Vector3.ZERO


func _start_flight_knockout(
	collision_normal: Vector3,
	collision_position: Vector3,
	impact_speed: float
) -> void:
	is_flying = false
	is_ground_slamming = false
	is_knocked_out = true
	current_flight_speed = 0.0
	velocity = collision_normal * flight_knockout_rebound_speed
	velocity.y += flight_knockout_rebound_upward_speed
	camera_effects.call("trigger_knockout")
	_spawn_hard_landing_effect(impact_speed, collision_position, collision_normal)


func _handle_knockout(delta: float) -> void:
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
	velocity.y -= gravity * delta


func _finish_knockout() -> void:
	is_knocked_out = false
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


func _handle_normal_movement(delta: float) -> void:
	if is_wall_running:
		_handle_wall_run(delta)
		return

	var is_grounded := is_on_floor()

	# Gravity
	if not is_grounded:
		was_airborne = true
		velocity.y -= gravity * delta
		max_downward_speed = max(max_downward_speed, -velocity.y)
	elif was_airborne:
		_handle_landing()
		
	if animation_controller.is_fighting:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Charge power jump
	if is_on_floor():
		if Input.is_action_pressed("jump"):
			jump_hold_time += delta
			if jump_hold_time >= power_jump_charge_threshold:
				is_charging_jump = true
				jump_charge += delta
				jump_charge = min(jump_charge, max_jump_charge_time)

		if Input.is_action_just_released("jump"):
			if is_charging_jump:
				var charge_percent := jump_charge / max_jump_charge_time

				# Vertical launch
				velocity.y = lerp(
					min_jump_velocity,
					max_jump_velocity,
					charge_percent
				)

				# Forward launch
				var forward := -transform.basis.z.normalized()
				var forward_boost := max_forward_jump_boost * charge_percent

				velocity.x += forward.x * forward_boost
				velocity.z += forward.z * forward_boost
			else:
				# A quick tap performs a regular jump without interrupting movement.
				velocity.y = min_jump_velocity

			is_jump_active = true

			jump_hold_time = 0.0
			jump_charge = 0.0
			is_charging_jump = false
	else:
		if Input.is_action_just_released("jump"):
			jump_hold_time = 0.0
			jump_charge = 0.0
			is_charging_jump = false

	# WASD input
	var input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var direction := (
		transform.basis * Vector3(input.x, 0.0, input.y)
	).normalized()

	# Walk / sprint
	var target_speed := walk_speed

	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed

	# Horizontal movement
	if is_charging_jump:
		# Stay planted while building power for a jump.
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var horizontal_acceleration := acceleration
		if not is_on_floor():
			horizontal_acceleration *= air_control_strength

		if direction:
			velocity.x = move_toward(
				velocity.x,
				direction.x * target_speed,
				horizontal_acceleration * delta
			)
			velocity.z = move_toward(
				velocity.z,
				direction.z * target_speed,
				horizontal_acceleration * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				horizontal_acceleration * delta
			)
			velocity.z = move_toward(
				velocity.z,
				0.0,
				horizontal_acceleration * delta
			)


func _can_start_wall_run() -> bool:
	if is_flying or is_ground_slamming or is_knocked_out:
		return false
	if not Input.is_action_pressed("sprint"):
		return false
	if Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length_squared() == 0.0:
		return false
	return _get_wall_collision_normal() != Vector3.ZERO


func _get_wall_collision_normal() -> Vector3:
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		var collision_normal := collision.get_normal()
		if abs(collision_normal.y) < 0.7:
			return collision_normal
	return Vector3.ZERO


func _start_wall_run(collision_normal: Vector3) -> void:
	is_wall_running = true
	wall_run_normal = collision_normal
	wall_run_has_left_ground = false
	velocity = _get_wall_run_velocity()


func _handle_wall_run(delta: float) -> void:
	var movement_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	if movement_input.length_squared() == 0.0:
		_finish_wall_run()
		velocity.y -= gravity * delta
		return

	if Input.is_action_just_pressed("jump"):
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
		velocity.y -= gravity * delta
		return

	wall_run_normal = current_wall_normal
	velocity = _get_wall_run_velocity()


func _get_wall_run_velocity() -> Vector3:
	var lateral_velocity := Vector3.ZERO
	var side_input := Input.get_axis("move_left", "move_right")
	if Input.is_action_pressed("sprint") and abs(side_input) > 0.0:
		# Project the player's left/right input onto the current wall plane.
		var desired_side_direction := transform.basis.x * side_input
		var wall_tangent := desired_side_direction - (
			wall_run_normal * desired_side_direction.dot(wall_run_normal)
		)
		if wall_tangent.length_squared() > 0.0:
			lateral_velocity = wall_tangent.normalized() * wall_run_side_speed

	return Vector3.UP * wall_run_speed - wall_run_normal * wall_run_stick_speed + lateral_velocity


func _finish_wall_run() -> void:
	is_wall_running = false
	wall_run_has_left_ground = false

func _update_jump_charge_ui() -> void:
	player_hud.set_jump_charge(jump_charge / max_jump_charge_time)


func _update_vehicle_throw_ui() -> void:
	var charge_percent := 0.0
	if is_charging_vehicle_throw:
		charge_percent = vehicle_throw_hold_time / maxf(vehicle_throw_charge_time, 0.001)
	player_hud.set_vehicle_throw_charge(is_charging_vehicle_throw, charge_percent)


func _update_flight_speed_ui() -> void:
	var speed_percent := 0.0
	if is_flying and flight_max_speed > 0.0:
		speed_percent = velocity.length() / flight_max_speed
	player_hud.set_flight_speed(speed_percent)


func _update_landing_camera_effects() -> void:
	var is_grounded := is_on_floor()
	if is_grounded and not was_on_floor_for_camera_effects:
		var landing_speed := max_downward_speed_for_camera_effects
		# Flight slams are intentional high-impact dives, even if the camera ray
		# reaches the target at a shallow angle.
		if ground_slam_impact_pending:
			landing_speed = maxf(landing_speed, ground_slam_speed)

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
		if collider is Vehicle:
			var vehicle: Vehicle = collider as Vehicle
			vehicle.take_damage(vehicle_damage, impact_speed)
			continue
		if collider == null or not collider.has_method("take_hit"):
			continue
		var collider_id := collider.get_instance_id()
		if hit_instance_ids.has(collider_id):
			continue
		hit_instance_ids[collider_id] = true
		collider.call("take_hit", damage, hit_reaction, impact_position)


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

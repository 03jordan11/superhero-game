class_name PlayerInputSnapshot
extends RefCounted

## Per-physics-frame Player input values. Create a new snapshot each frame and
## treat it as read-only after construction.

var movement: Vector2
var lateral_movement: float
var sprint_pressed: bool
var move_forward_pressed: bool
var jump_pressed: bool
var jump_just_pressed: bool
var jump_just_released: bool
var descend_pressed: bool
var toggle_flight_just_pressed: bool
var flight_pressed: bool
var flight_just_released: bool
var aim_power_pressed: bool
var activate_power_pressed: bool
var activate_power_just_pressed: bool
var activate_power_just_released: bool
var secondary_power_pressed: bool
var vehicle_interact_pressed: bool
var vehicle_interact_just_pressed: bool
var vehicle_interact_just_released: bool
var lock_target_pressed: bool
var lock_target_just_pressed: bool
var lock_target_just_released: bool


func _init(
	p_movement: Vector2 = Vector2.ZERO,
	p_lateral_movement: float = 0.0,
	p_sprint_pressed: bool = false,
	p_move_forward_pressed: bool = false,
	p_jump_pressed: bool = false,
	p_jump_just_pressed: bool = false,
	p_jump_just_released: bool = false,
	p_descend_pressed: bool = false,
	p_toggle_flight_just_pressed: bool = false,
	p_vehicle_interact_pressed: bool = false,
	p_vehicle_interact_just_pressed: bool = false,
	p_vehicle_interact_just_released: bool = false,
	p_flight_pressed: bool = false,
	p_flight_just_released: bool = false
) -> void:
	movement = p_movement
	lateral_movement = p_lateral_movement
	sprint_pressed = p_sprint_pressed
	move_forward_pressed = p_move_forward_pressed
	jump_pressed = p_jump_pressed
	jump_just_pressed = p_jump_just_pressed
	jump_just_released = p_jump_just_released
	descend_pressed = p_descend_pressed
	toggle_flight_just_pressed = p_toggle_flight_just_pressed
	flight_pressed = p_flight_pressed
	flight_just_released = p_flight_just_released
	vehicle_interact_pressed = p_vehicle_interact_pressed
	vehicle_interact_just_pressed = p_vehicle_interact_just_pressed
	vehicle_interact_just_released = p_vehicle_interact_just_released


static func capture() -> PlayerInputSnapshot:
	var snapshot := PlayerInputSnapshot.new(
		Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward"
		),
		Input.get_axis("move_left", "move_right"),
		Input.is_action_pressed("sprint"),
		Input.is_action_pressed("move_forward"),
		Input.is_action_pressed("jump"),
		Input.is_action_just_pressed("jump"),
		Input.is_action_just_released("jump"),
		Input.is_action_pressed("flight_descend"),
		Input.is_action_just_pressed("toggle_flight"),
		Input.is_action_pressed("pick_up_vehicle"),
		Input.is_action_just_pressed("pick_up_vehicle"),
		Input.is_action_just_released("pick_up_vehicle"),
		Input.is_action_pressed("toggle_flight"),
		Input.is_action_just_released("toggle_flight")
	)
	snapshot.aim_power_pressed = Input.is_action_pressed("aim_power")
	snapshot.activate_power_pressed = Input.is_action_pressed("attack")
	snapshot.activate_power_just_pressed = Input.is_action_just_pressed("attack")
	snapshot.activate_power_just_released = Input.is_action_just_released("attack")
	snapshot.secondary_power_pressed = Input.is_action_pressed("secondary_power")
	snapshot.lock_target_pressed = Input.is_action_pressed("lock_target")
	snapshot.lock_target_just_pressed = Input.is_action_just_pressed("lock_target")
	snapshot.lock_target_just_released = Input.is_action_just_released("lock_target")
	return snapshot

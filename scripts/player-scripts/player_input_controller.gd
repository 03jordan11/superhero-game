extends Node
## Stateful accessibility input; snapshots and movement states stay independent.
@export_range(30.0, 360.0, 5.0) var controller_look_degrees_per_second := 150.0
@export_range(0.05, 0.5, 0.01) var controller_look_deadzone := 0.2
var sprint_toggled := false
@onready var player: PlayerCharacter = get_parent()
@onready var settings: Node = get_node("/root/GameSettings")

func _ready() -> void:
	settings.accessibility_settings_changed.connect(reset)
	settings.input_bindings.changed.connect(reset)
	settings.input_bindings.controller_disconnected.connect(reset)
	player.get_node("PlayerStateMachine/DeadState").death_started.connect(reset)

func _unhandled_input(event: InputEvent) -> void:
	if settings.input_bindings.is_capturing: return
	if settings.toggle_sprint and settings.input_bindings.is_action_press(event, "sprint"):
		if not player.is_dead and not player.is_knocked_out and not DebugManager.developer_menu_open:
			sprint_toggled = not sprint_toggled

func _process(delta: float) -> void:
	if DebugManager.developer_menu_open or settings.input_bindings.is_capturing or not get_window().has_focus(): return
	update_controller_look(delta)

func update_controller_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", controller_look_deadzone)
	apply_look(look * deg_to_rad(controller_look_degrees_per_second) * delta)

func apply_look(radians: Vector2) -> void:
	if not player.is_knocked_out and not player.is_dead:
		player.rotate_y(-radians.x)
	player.spring_arm.rotation.x = clampf(player.spring_arm.rotation.x - radians.y,
		deg_to_rad(player.min_camera_angle), deg_to_rad(player.max_camera_angle))

func is_sprint_requested() -> bool:
	# Keep intent separate from ability/stamina eligibility, including toggle mode.
	return sprint_toggled if settings.toggle_sprint else Input.is_action_pressed("sprint")

func capture() -> PlayerInputSnapshot:
	var snapshot := PlayerInputSnapshot.capture()
	if player.is_dead or player.is_knocked_out or DebugManager.developer_menu_open or settings.input_bindings.is_capturing:
		reset()
		return PlayerInputSnapshot.new()
	snapshot.sprint_pressed = is_sprint_requested()
	var boost_ability := PlayerAbilities.FLIGHT_BOOST if player.is_flying else PlayerAbilities.SUPER_SPEED
	snapshot.sprint_pressed = snapshot.sprint_pressed and player.abilities.is_unlocked(boost_ability)
	return snapshot

func reset() -> void:
	sprint_toggled = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()

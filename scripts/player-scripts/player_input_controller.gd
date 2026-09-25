extends Node
## Stateful accessibility input; snapshots and movement states stay independent.
@export_range(30.0, 360.0, 5.0) var controller_look_degrees_per_second := 150.0
@export_range(0.05, 0.5, 0.01) var controller_look_deadzone := 0.2
var sprint_toggled := false
var aim_toggled := false
@onready var player: PlayerCharacter = get_parent()
@onready var settings: Node = get_node("/root/GameSettings")

func _ready() -> void:
	settings.accessibility_settings_changed.connect(reset)
	settings.input_bindings.changed.connect(reset)
	settings.input_bindings.controller_disconnected.connect(reset)
	player.get_node("PlayerStateMachine/DeadState").death_started.connect(reset)

func _unhandled_input(event: InputEvent) -> void:
	if player.get_node("PlayerPowerController").is_selector_open(): return
	if settings.input_bindings.is_capturing: return
	if settings.toggle_power_activation and settings.input_bindings.is_action_press(event, "aim_power"):
		if not player.is_dead and not player.is_knocked_out and not DebugManager.developer_menu_open:
			aim_toggled = not aim_toggled
	if settings.toggle_sprint and settings.input_bindings.is_action_press(event, "sprint"):
		if not player.is_dead and not player.is_knocked_out and not DebugManager.developer_menu_open:
			sprint_toggled = not sprint_toggled

func _process(delta: float) -> void:
	if DebugManager.developer_menu_open or settings.input_bindings.is_capturing or not get_window().has_focus(): return
	# Aiming slow motion affects the world, not right-stick camera responsiveness.
	var lightning := player.get_node_or_null("PlayerLightningStrike")
	var wall := player.get_node_or_null("PlayerFrostWall")
	var slowed_aim: bool = (lightning != null and lightning.casting) or (wall != null and wall.casting)
	var look_delta := delta / maxf(Engine.time_scale, 0.001) if slowed_aim else delta
	update_controller_look(look_delta)

func update_controller_look(delta: float) -> void:
	if player.get_node("PlayerPowerController").is_selector_open(): return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", controller_look_deadzone)
	apply_look(look * deg_to_rad(controller_look_degrees_per_second) * delta)

func apply_look(radians: Vector2) -> void:
	if player.get_node("PlayerPowerController").is_selector_open(): return
	if player.target_lock.has_target(): return
	# Both mouse motion and controller look pass through here.
	radians *= settings.look_sensitivity
	if not player.is_knocked_out and not player.is_dead:
		player.rotate_y(-radians.x)
		if player.state_machine.active_state is PlayerGroundedState and not player.combat_controller.is_action_locked() and not player.is_charging_flight:
			if is_power_aim_requested():
				player.ground_facing_yaw = player.global_rotation.y
			player._apply_ground_facing_visual()
	player.spring_arm.rotation.x = clampf(player.spring_arm.rotation.x - radians.y,
		deg_to_rad(player.min_camera_angle), deg_to_rad(player.max_camera_angle))

func is_sprint_requested() -> bool:
	# Keep intent separate from ability/stamina eligibility, including toggle mode.
	if settings.toggle_sprint: return sprint_toggled
	# Hold mode requires a control that is actually down, even if the action is
	# stale. Keeping the action check also honors reset() while a key is held.
	return Input.is_action_pressed("sprint") and settings.input_bindings.is_bound_control_held(&"sprint")

func is_power_aim_requested() -> bool:
	return aim_toggled if settings.toggle_power_activation else Input.is_action_pressed("aim_power")

func capture() -> PlayerInputSnapshot:
	if player.get_node("PlayerPowerController").is_selector_open(): return PlayerInputSnapshot.new()
	var snapshot := PlayerInputSnapshot.capture()
	if player.is_dead or player.is_knocked_out or DebugManager.developer_menu_open or settings.input_bindings.is_capturing:
		reset()
		return PlayerInputSnapshot.new()
	snapshot.sprint_pressed = is_sprint_requested()
	snapshot.aim_power_pressed = is_power_aim_requested()
	var boost_ability := PlayerAbilities.FLIGHT_BOOST if player.is_flying else PlayerAbilities.SUPER_SPEED
	snapshot.sprint_pressed = snapshot.sprint_pressed and player.abilities.is_unlocked(boost_ability)
	return snapshot

func reset() -> void:
	var combat := player.get_node_or_null("PlayerCombatController") as PlayerCombatController
	if combat != null: combat.cancel_charge_input()
	var target_lock:=player.get_node_or_null("PlayerTargetLock")
	if target_lock != null: target_lock.cancel_press()
	Input.action_release("lock_target")
	sprint_toggled = false
	# Release may occur outside the app or while a menu owns input. Clear the
	# raw hold as well as the accessibility latch; sprint needs a fresh press.
	Input.action_release("sprint")
	aim_toggled = false
	var flight := player.get_node_or_null("PlayerStateMachine/FlyingState") as PlayerFlyingState
	if flight != null: flight.cancel_charge()
	var laser := player.get_node_or_null("PlayerLaserEyes")
	if laser != null: laser.cancel_input()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()

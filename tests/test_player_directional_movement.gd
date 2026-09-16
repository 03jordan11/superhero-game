extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func same_angle(a: float, b: float) -> bool:
	return absf(wrapf(a - b, -PI, PI)) < 0.001

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	world.add_child(player)
	player.set_physics_process(false)
	player.input_controller.set_process(false)
	var settings := root.get_node("GameSettings")
	settings.input_bindings.load_config(ConfigFile.new())
	settings.set_accessibility(false, false, false)
	player.rotation.y = 0.7
	var headings := [Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1)]
	for heading in headings:
		var input := PlayerInputSnapshot.new(heading.normalized())
		var camera_before := player.camera.global_transform.basis
		player._update_movement_facing(2.0, input)
		var expected := player.rotation.y + atan2(-heading.x, -heading.y)
		check(same_angle(player.ground_facing_yaw, expected), "Character faces keyboard direction %s" % heading)
		check(player.camera.global_transform.basis.is_equal_approx(camera_before), "Character turning does not rotate camera")
		player.velocity = Vector3.ZERO
		player.grounded_state._apply_horizontal_movement(1.0, input)
		var expected_direction := player.transform.basis * Vector3(input.movement.x, 0, input.movement.y)
		check(Vector3(player.velocity.x, 0, player.velocity.z).normalized().is_equal_approx(expected_direction), "Movement uses camera direction, independent of visual turning")
	var analog := PlayerInputSnapshot.new(Vector2(0.23, -0.4))
	player._update_movement_facing(2.0, analog)
	check(same_angle(player.ground_facing_yaw, player.rotation.y + atan2(-0.23, 0.4)), "Analog heading is not snapped to eight directions")
	var before_idle := player.ground_facing_yaw
	player.input_controller.apply_look(Vector2(0.5, 0.0))
	player._update_movement_facing(0.1, PlayerInputSnapshot.new())
	check(same_angle(player.ground_facing_yaw, before_idle) and same_angle(player.global_rotation.y + player.movement_visual_yaw, before_idle), "Idle character keeps world heading as camera orbits")
	var aiming := PlayerInputSnapshot.new(Vector2.LEFT)
	aiming.aim_power_pressed = true
	player._update_movement_facing(0.016, aiming)
	check(is_zero_approx(player.movement_visual_yaw), "Aim immediately faces camera while moving sideways")
	Input.action_press("aim_power")
	player.input_controller.apply_look(Vector2(-0.3, 0.1))
	check(is_zero_approx(player.movement_visual_yaw), "Aimed body follows mouse yaw immediately")
	Input.action_release("aim_power")
	var heading_before_release := player.ground_facing_yaw
	player._update_movement_facing(0.016, PlayerInputSnapshot.new(Vector2.RIGHT))
	check(not same_angle(player.ground_facing_yaw, heading_before_release) and absf(player.movement_visual_yaw) < PI / 2, "Releasing aim smoothly restores movement facing")
	player._update_movement_facing(2.0, PlayerInputSnapshot.new(Vector2.RIGHT))
	check(same_angle(player.movement_visual_yaw, -PI / 2), "Right movement settles at 90 degrees")
	settings.set_accessibility(false, true, false)
	player.input_controller.aim_toggled = true
	player._update_movement_facing(0.016, player.input_controller.capture())
	check(is_zero_approx(player.movement_visual_yaw), "Aim toggle uses the same strafe mode")
	settings.set_accessibility(false, false, false)
	player.state_machine.transition_to(&"AirborneState")
	player._update_movement_facing(2.0, PlayerInputSnapshot.new(Vector2.LEFT))
	check(is_zero_approx(player.movement_visual_yaw), "Ordinary airborne facing remains camera-forward")
	world.free()
	print("Directional movement: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

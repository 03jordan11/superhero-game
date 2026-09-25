extends SceneTree
const STEP := 1.0 / 60.0
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0
class TestInput extends Node:
	var snapshot := PlayerInputSnapshot.new()
	func capture() -> PlayerInputSnapshot: return snapshot
	func is_power_aim_requested() -> bool: return snapshot.aim_power_pressed
	func is_sprint_requested() -> bool: return snapshot.sprint_pressed
	func reset() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle(player: PlayerCharacter) -> void:
	player.position = Vector3(0, 1.05, 0)
	player.velocity = Vector3.ZERO
	for tick in 30:
		player.velocity.y -= player.gravity * STEP
		player.move_and_slide()
	player.state_machine.transition_to(&"GroundedState")
	player.velocity = Vector3.ZERO
	player.stamina.restore_full()

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	player.position.y = 1.05
	world.add_child(player)
	player.set_physics_process(false)
	player.input_controller.set_process(false)
	var input := TestInput.new()
	player.add_child(input)
	player.input_controller = input
	var animator := player.character_animation_player
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await physics_frame
	await physics_frame
	settle(player)
	var roll = player.state_machine.get_state(&"DodgeRollState")
	check(animator.has_animation("Dodge_Roll"), "Existing UAL1 Roll is loaded")
	root.get_node("GameSettings").input_bindings.load_config(ConfigFile.new())
	var ctrl := InputEventKey.new()
	ctrl.physical_keycode = KEY_CTRL
	ctrl.location = KEY_LOCATION_LEFT
	ctrl.ctrl_pressed = true
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	Input.flush_buffered_events()
	var captured := PlayerInputSnapshot.capture()
	# Events injected from the physics_frame signal become just-pressed in the
	# next physics tick. Held state can be checked immediately here.
	check(Input.is_action_pressed("dodge_roll") and captured.descend_pressed, "Actual Left Ctrl reaches both contextual actions")
	ctrl = ctrl.duplicate()
	ctrl.pressed = false
	ctrl.ctrl_pressed = false
	Input.parse_input_event(ctrl)
	Input.flush_buffered_events()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("dodge_roll") and PlayerInputSnapshot.capture().descend_pressed, "Actual B reaches both contextual actions")
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	input.snapshot.dodge_just_pressed = true
	player._profiled_physics_process(STEP)
	check(not player.is_dodging and player.stamina.is_full(), "Stationary dodge does nothing and costs nothing")
	input.snapshot = PlayerInputSnapshot.new()
	# The visual faces forward; moving sideways/backwards determines each roll.
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3(1,0,-1).normalized()]:
		settle(player)
		player.ground_facing_yaw = 0.0
		player._apply_ground_facing_visual()
		player.velocity = direction * 3.0
		input.snapshot = PlayerInputSnapshot.new(Vector2(direction.x, direction.z))
		input.snapshot.aim_power_pressed = true
		input.snapshot.dodge_just_pressed = true
		input.snapshot.sprint_pressed = true
		var origin := player.position
		player._profiled_physics_process(STEP)
		check(player.is_dodging and animator.current_animation == "Dodge_Roll", "Moving input starts roll animation")
		var previous_speed := Vector2(player.velocity.x, player.velocity.z).length()
		check(previous_speed > player._get_walk_speed() and previous_speed > roll.distance / roll.duration, "Roll starts with a burst above walking and average roll speed")
		check(roll.direction.is_equal_approx(direction), "Roll direction follows motion, independently of facing")
		check(is_equal_approx(player.stamina.current, player.stamina.maximum * 0.9), "One roll costs exactly ten percent of capacity")
		check(player.superhero_character.global_basis.z.normalized().dot(direction) > 0.99, "Roll visual faces travel direction")
		player.rotation.y += 0.4
		input.snapshot.dodge_just_pressed = false
		var health := player.get_current_health()
		for kind in [&"bullet", &"melee", &"explosion", &"fire", &"electricity"]:
			var hit = DAMAGE.new(10000, player.position, Vector3.RIGHT, &"knockback")
			hit.damage_type = kind
			check(not player.apply_damage(hit), "Dodge rejects " + kind + " damage")
		check(player.get_current_health() == health and not player.is_dead, "Even lethal damage is ignored")
		check(player.status_effects.apply_hit_slowdown() == 1.0 and player.status_effects.hit_slowdown_remaining == 0.0, "Direct slowdown is blocked")
		check(not player.state_machine.transition_to(&"KnockedDownState"), "Direct knockdown is blocked")
		check(not player.animation_controller.play_hit_reaction() and not player.animation_controller.play_knockdown(), "Disabling animations cannot replace the roll")
		# Conflicting inputs cannot spend stamina again, fire or toggle flight.
		input.snapshot.toggle_flight_just_pressed = true
		input.snapshot.vehicle_interact_just_pressed = true
		input.snapshot.activate_power_pressed = true
		for tick in 70:
			if not player.is_dodging: break
			animator.advance(STEP)
			player._profiled_physics_process(STEP)
			if player.is_dodging:
				var speed := Vector2(player.velocity.x, player.velocity.z).length()
				check(speed < previous_speed, "Roll burst tapers each step")
				previous_speed = speed
				check(player.superhero_character.global_basis.z.normalized().dot(direction) > 0.99, "Camera orbit cannot redirect the committed roll")
		check(not player.is_dodging and not player.is_flying, "Roll ends and ignores simultaneous flight toggle")
		check(Vector2(player.velocity.x, player.velocity.z).is_zero_approx(), "Roll speed does not carry into normal movement")
		check(absf(player.position.distance_to(origin) - roll.distance) < 0.06, "Roll covers configured distance")
		check(is_equal_approx(player.stamina.current, player.stamina.maximum * 0.9), "Holding sprint does not add roll stamina drain")
		var hit = DAMAGE.new(1)
		check(player.apply_damage(hit) and player.get_current_health() < health, "Damage protection ends with the roll")
		player.animation_controller.is_hit_reacting = false
		player.status_effects.hit_slowdown_remaining = 0.0
	settle(player)
	player.velocity = Vector3.RIGHT * 3
	player.stamina.current = player.stamina.maximum * 0.09
	check(not player.state_machine.transition_to(&"DodgeRollState"), "Insufficient stamina rejects the roll")
	player.stamina.current = player.stamina.maximum * 0.1
	check(player.state_machine.transition_to(&"DodgeRollState") and is_zero_approx(player.stamina.current), "Exactly ten percent is sufficient")
	player.state_machine.transition_to(&"GroundedState")
	settle(player)
	player.abilities.set_unlocked(PlayerAbilities.FLIGHT, true)
	player.state_machine.transition_to(&"FlyingState")
	player.position.y = 5.0
	input.snapshot = PlayerInputSnapshot.new(Vector2.RIGHT)
	input.snapshot.descend_pressed = true
	input.snapshot.dodge_just_pressed = true
	player._profiled_physics_process(STEP)
	check(player.is_flying and not player.is_dodging and player.velocity.y < 0.0 and player.stamina.is_full(), "Shared Ctrl descends in flight without rolling or spending stamina")
	player.state_machine.transition_to(&"GroundedState")
	settle(player)
	# Physics collisions stay enabled throughout immunity.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.5, 5, 10)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(2, 2, 0)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	player.velocity = Vector3.RIGHT * 3
	check(player.state_machine.transition_to(&"DodgeRollState"), "Roll starts toward wall")
	input.snapshot = PlayerInputSnapshot.new()
	for tick in 60:
		if not player.is_dodging: break
		player._profiled_physics_process(STEP)
	check(player.position.x < 1.5 and not player.is_dodging, "Wall blocks roll; timer still ends immunity")
	# Leaving a ledge must not leave permanent immunity.
	settle(player)
	player.velocity = Vector3.RIGHT * 3
	player.state_machine.transition_to(&"DodgeRollState")
	player.position.y = 6
	player._profiled_physics_process(STEP)
	check(not player.is_dodging and player.state_machine.get_active_state_id() == &"AirborneState", "Leaving the floor ends roll protection")
	world.free()
	print("DODGE_ROLL: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

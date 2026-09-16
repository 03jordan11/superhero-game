extends SceneTree

const STEP := 1.0 / 60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("GameSettings").set_accessibility(false, false, false)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500, 1, 500)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	player.position.y = 1.1
	world.add_child(player)
	player.set_physics_process(false)
	for ability in [PlayerAbilities.SUPER_SPEED, PlayerAbilities.FLIGHT, PlayerAbilities.FLIGHT_BOOST]:
		player.abilities.set_unlocked(ability, true)
	await physics_frame
	await physics_frame
	for tick in 30:
		player._profiled_physics_process(STEP)
	check(player.is_on_floor(), "Fixture is grounded")
	Input.action_press("move_forward")
	preload("res://tests/player_test_support.gd").set_sprint_held(true)
	for tick in 30:
		player._profiled_physics_process(STEP)
	var stamina := player.stamina
	check(stamina.current < stamina.maximum, "Ground sprint consumes stamina")
	var before_air := stamina.current
	var delay_before := stamina._recovery_delay
	player.position.y = 100
	player.velocity.y = 20
	player.state_machine.transition_to(&"AirborneState")
	for tick in 15:
		player._profiled_physics_process(STEP)
	check(stamina.current == before_air and not player.is_on_floor(), "Rising without flight freezes stamina even with sprint held")
	player.velocity.y = -15
	for tick in 15:
		player._profiled_physics_process(STEP)
	check(stamina.current == before_air, "Falling with sprint held does not drain stamina")
	preload("res://tests/player_test_support.gd").set_sprint_held(false)
	for tick in 90:
		player._profiled_physics_process(STEP)
	check(stamina.current == before_air and stamina._recovery_delay == delay_before, "Release in freefall cannot regenerate or advance recovery delay")
	player.position.y = 1.1
	player.velocity.y = -1
	for tick in 30:
		player._profiled_physics_process(STEP)
	check(player.is_on_floor() and stamina.current == before_air, "Landing resumes the existing recovery delay")
	for tick in 90:
		player._profiled_physics_process(STEP)
	check(stamina.current > before_air, "Grounded movement without Shift regenerates stamina")
	# Repeat with no available stamina, then switch between flight and falling.
	stamina.current = 0
	stamina.exhausted = true
	player.position.y = 100
	player.velocity = Vector3.DOWN * 10
	player.state_machine.transition_to(&"AirborneState")
	for tick in 30:
		player._profiled_physics_process(STEP)
	check(stamina.current == 0 and stamina.exhausted, "Falling cannot recover exhaustion")
	check(player.state_machine.transition_to(&"FlyingState"), "Flight can begin for regression checks")
	for tick in 120:
		player._profiled_physics_process(STEP)
	check(stamina.current > 0, "Ordinary flight still regenerates")
	stamina.restore_full()
	preload("res://tests/player_test_support.gd").set_sprint_held(true)
	for tick in 30:
		player._profiled_physics_process(STEP)
	check(stamina.current < stamina.maximum, "Flight boost still drains")
	preload("res://tests/player_test_support.gd").set_sprint_held(false)
	player.state_machine.transition_to(&"AirborneState")
	var flight_remainder := stamina.current
	for tick in 30:
		player._profiled_physics_process(STEP)
	check(stamina.current == flight_remainder, "Turning flight off freezes stamina immediately")
	Input.action_release("move_forward")
	world.free()
	print("Airborne stamina: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

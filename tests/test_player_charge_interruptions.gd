extends SceneTree

var player: PlayerCharacter
var floor_body: StaticBody3D
const STEP := 1.0 / 60.0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	floor_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	await settle_on_floor()
	var machine := player.state_machine
	assert(machine.transition_to(&"JumpChargingState", {"initial_charge_delta": 0.5}))
	var held := PlayerInputSnapshot.new()
	held.jump_pressed = true
	held.movement = Vector2.UP
	machine.physics_update(STEP, held)
	assert(player.is_charging_jump and player.jump_charge > 0.5)
	assert(player.get_node("PlayerSoundManager/JumpCharge").playing)
	assert(player.velocity.x == 0.0 and player.velocity.z == 0.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._profiled_input(click)
	assert(not player.combat_controller.is_action_locked())
	player.combat_controller.request_punch()
	assert(not player.combat_controller.is_action_locked())
	var release := PlayerInputSnapshot.new()
	release.jump_just_released = true
	machine.physics_update(STEP, release)
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.is_charging_jump and player.velocity.y > player.min_jump_velocity)
	assert(not player.get_node("PlayerSoundManager/JumpCharge").playing)
	assert(player.jump_charge == 0.0)

	await settle_on_floor()
	assert(machine.transition_to(&"JumpChargingState", {"initial_charge_delta": 0.8}))
	assert(player.get_node("PlayerSoundManager/JumpCharge").playing)
	# Remove support without releasing Space, then resolve the actual move contact.
	floor_body.collision_layer = 0
	await physics_frame
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	assert(not player.is_on_floor())
	machine.post_physics_update(STEP, held)
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.is_charging_jump)
	assert(not player.get_node("PlayerSoundManager/JumpCharge").playing)
	assert(player.jump_charge == 0.0 and player.jump_hold_time == 0.0)

	await settle_on_floor()
	assert(machine.transition_to(&"JumpChargingState", {"initial_charge_delta": 0.3}))
	floor_body.collision_layer = 0
	await physics_frame
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	# The pre-move path must also cancel when support is already gone.
	machine.physics_update(STEP, release)
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.is_charging_jump and player.jump_charge == 0.0)
	await settle_on_floor()
	assert(machine.transition_to(&"JumpChargingState"))
	machine.physics_update(STEP, held)
	assert(player.is_charging_jump and player.jump_charge > 0.0)
	machine.transition_to(&"GroundedState")
	player.combat_controller.request_punch()
	assert(player.combat_controller.is_action_locked())
	world.free()
	print("PASS: real floor contact cancels charging, charging blocks punches, and charging/punching recover")
	quit()


func settle_on_floor() -> void:
	floor_body.collision_layer = 1
	player.global_position = Vector3(0.0, 1.1, 0.0)
	player.velocity = Vector3.ZERO
	player.state_machine.transition_to(&"GroundedState")
	for frame in 30:
		await physics_frame
		player.velocity.y -= player.gravity * STEP
		player.move_and_slide()
		if player.is_on_floor():
			player.velocity = Vector3.ZERO
			return
	assert(false, "Player fixture did not contact the floor")

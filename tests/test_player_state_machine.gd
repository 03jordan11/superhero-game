extends SceneTree


class TrackingState:
	extends PlayerState

	var event_log: Array[String]
	var input_call_count: int = 0
	var physics_call_count: int = 0
	var post_physics_call_count: int = 0
	var last_input: PlayerInputSnapshot
	var last_context: Dictionary = {}


	func _init(target_event_log: Array[String]) -> void:
		event_log = target_event_log


	func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
		event_log.append("enter:%s" % name)
		last_context = context


	func exit(next_state: PlayerState) -> void:
		event_log.append("exit:%s->%s" % [name, next_state.name])


	func handle_input(input: PlayerInputSnapshot) -> void:
		input_call_count += 1
		last_input = input


	func physics_update(_delta: float, input: PlayerInputSnapshot) -> void:
		physics_call_count += 1
		last_input = input


	func post_physics_update(_delta: float, input: PlayerInputSnapshot) -> void:
		post_physics_call_count += 1
		last_input = input


func _initialize() -> void:
	var event_log: Array[String] = []
	var transition_log: Array[String] = []
	var player := PlayerCharacter.new()
	var machine := PlayerStateMachine.new()
	var grounded := TrackingState.new(event_log)
	var flying := TrackingState.new(event_log)

	player.name = "TestPlayer"
	machine.name = "StateMachine"
	grounded.name = "Grounded"
	flying.name = "Flying"
	player.add_child(machine)
	machine.add_child(grounded)
	machine.add_child(flying)
	machine.state_changed.connect(
		func(previous_state: PlayerState, next_state: PlayerState) -> void:
			var previous_id := &"<none>"
			if previous_state != null:
				previous_id = previous_state.get_state_id()
			transition_log.append("%s->%s" % [previous_id, next_state.get_state_id()])
	)

	assert(machine.initialize(player, grounded))
	assert(machine.active_state == grounded)
	assert(machine.get_active_state_id() == &"Grounded")
	assert(grounded.player == player)
	assert(grounded.state_machine == machine)
	assert(event_log == ["enter:Grounded"])
	assert(transition_log == ["<none>->Grounded"])

	var input := PlayerInputSnapshot.new()
	machine.handle_input(input)
	machine.physics_update(0.25, input)
	machine.post_physics_update(0.25, input)
	assert(grounded.input_call_count == 1)
	assert(grounded.physics_call_count == 1)
	assert(grounded.post_physics_call_count == 1)
	assert(grounded.last_input == input)
	assert(flying.input_call_count == 0)
	assert(flying.physics_call_count == 0)
	assert(flying.post_physics_call_count == 0)

	assert(machine.transition_to(&"Flying", {"reason": &"test"}))
	assert(machine.active_state == flying)
	assert(machine.get_active_state_id() == &"Flying")
	assert(flying.last_context.get("reason") == &"test")
	assert(event_log == [
		"enter:Grounded",
		"exit:Grounded->Flying",
		"enter:Flying",
	])
	assert(transition_log == ["<none>->Grounded", "Grounded->Flying"])

	assert(not machine.transition_to(&"Flying"))
	assert(event_log.size() == 3)

	player.free()
	print("PASS: PlayerStateMachine transition core")
	quit()

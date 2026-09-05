class_name PlayerStateMachine
extends Node

## Single owner of the Player's locomotion and life-state transitions.
## The machine is driven explicitly by the Player coordinator; it does not
## process input or physics automatically.

signal state_changed(previous_state: PlayerState, next_state: PlayerState)

@export var initial_state: PlayerState

var player: PlayerCharacter
var active_state: PlayerState
var states: Dictionary[StringName, PlayerState] = {}
var is_initialized: bool = false

var _transition_in_progress: bool = false


func initialize(
	target_player: PlayerCharacter,
	starting_state: PlayerState = null
) -> bool:
	if target_player == null:
		push_error("PlayerStateMachine requires a Player body.")
		return false

	player = target_player
	active_state = null
	states.clear()
	is_initialized = false

	var first_registered_state: PlayerState
	for child in get_children():
		var state := child as PlayerState
		if state == null:
			continue
		if not register_state(state):
			return false
		if first_registered_state == null:
			first_registered_state = state

	if states.is_empty():
		push_error("PlayerStateMachine has no PlayerState children.")
		return false

	var resolved_starting_state := starting_state
	if resolved_starting_state == null:
		resolved_starting_state = initial_state
	if resolved_starting_state == null:
		resolved_starting_state = first_registered_state
	if not _is_registered_state(resolved_starting_state):
		push_error("PlayerStateMachine's initial state is not registered.")
		return false

	active_state = resolved_starting_state
	is_initialized = true
	active_state.enter(null)
	state_changed.emit(null, active_state)
	return true


func register_state(state: PlayerState) -> bool:
	if state == null:
		return false

	var id := state.get_state_id()
	if id == &"":
		push_error("PlayerStateMachine cannot register a state without an ID.")
		return false
	if states.has(id):
		push_error("PlayerStateMachine has duplicate state ID '%s'." % id)
		return false

	states[id] = state
	if player != null:
		state.setup(player, self)
	return true


func transition_to(state_id: StringName, context: Dictionary = {}) -> bool:
	return transition_to_state(get_state(state_id), context)


func transition_to_state(next_state: PlayerState, context: Dictionary = {}) -> bool:
	if not is_initialized or next_state == null:
		return false
	if _transition_in_progress or next_state == active_state:
		return false
	if not _is_registered_state(next_state):
		return false
	if not active_state.can_exit(next_state):
		return false
	if not next_state.can_enter(active_state, context):
		return false

	_transition_in_progress = true
	var previous_state := active_state
	previous_state.exit(next_state)
	active_state = next_state
	active_state.enter(previous_state, context)
	_transition_in_progress = false
	state_changed.emit(previous_state, active_state)
	return true


func handle_input(input: PlayerInputSnapshot) -> void:
	if is_initialized:
		active_state.handle_input(input)


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	if is_initialized:
		active_state.physics_update(delta, input)


func post_physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	if is_initialized:
		active_state.post_physics_update(delta, input)


func get_state(state_id: StringName) -> PlayerState:
	return states.get(state_id) as PlayerState


func get_active_state_id() -> StringName:
	if active_state == null:
		return &""
	return active_state.get_state_id()


func _is_registered_state(state: PlayerState) -> bool:
	if state == null:
		return false
	return get_state(state.get_state_id()) == state

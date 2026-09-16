extends RefCounted
## Existing traversal/combat regression fixtures exercise already-unlocked moves.
## Fresh-game locks and real purchases are tested separately in test_gameplay_menu.
static func unlock_current_powers(player: PlayerCharacter) -> void:
	for ability in player.get_node("PlayerPowerController").REQUIREMENTS:
		player.abilities.set_unlocked(ability, true)

## Exercise both the bound control and Godot's action state.
static func set_sprint_held(pressed: bool) -> void:
	var event: InputEvent = InputMap.action_get_events("sprint")[0].duplicate()
	event.device = 0
	event.pressed = pressed
	if event is InputEventKey:
		event.keycode = event.physical_keycode
		event.shift_pressed = pressed and event.physical_keycode == KEY_SHIFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()

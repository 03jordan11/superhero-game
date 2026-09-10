extends RefCounted
## Existing traversal/combat regression fixtures exercise already-unlocked moves.
## Fresh-game locks and real purchases are tested separately in test_gameplay_menu.
static func unlock_current_powers(player: PlayerCharacter) -> void:
	for ability in player.get_node("PlayerPowerController").REQUIREMENTS:
		player.abilities.set_unlocked(ability, true)

extends Node

## Owns the game's single, versioned save file and applies its persistent data
## to the active Player.

const SAVE_PATH := "user://savegame.json"
const SAVE_FILE_NAME := "savegame.json"
const SAVE_VERSION := 1


func save_game() -> bool:
	var player := _get_player()
	if player == null:
		push_warning("SaveManager could not save because no PlayerCharacter was found.")
		return false

	var save_data := {
		"save_version": SAVE_VERSION,
		"save_name": _get_default_save_name(),
		"player": _get_player_save_data(player),
		"progress": {},
		"world": {},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager could not open %s for writing." % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		push_warning("SaveManager could not load because no save file exists.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager could not open %s for reading." % SAVE_PATH)
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("SaveManager could not parse %s as a save file." % SAVE_PATH)
		return false

	var player := _get_player()
	if player == null:
		push_warning("SaveManager could not load because no PlayerCharacter was found.")
		return false

	var save_data: Dictionary = json.data
	_apply_player_save_data(player, _get_dictionary(save_data, "player"))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not has_save():
		return true

	var save_directory := DirAccess.open("user://")
	if save_directory == null:
		push_error("SaveManager could not open user:// for save deletion.")
		return false

	var error := save_directory.remove(SAVE_FILE_NAME)
	if error != OK:
		push_error("SaveManager could not delete %s (error %d)." % [SAVE_PATH, error])
		return false
	return true


func _get_player() -> PlayerCharacter:
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as PlayerCharacter
		if player != null:
			return player
	return null


func _get_player_save_data(player: PlayerCharacter) -> Dictionary:
	return {
		"stats": {
			"level": player.stats.level,
			"strength": player.stats.strength,
			"speed": player.stats.speed,
			"resilience": player.stats.resilience,
			"experience": player.stats.experience,
			"money": player.stats.money,
		},
		"powers": _get_power_save_data(player),
		"gear": {},
	}


func _get_power_save_data(player: PlayerCharacter) -> Dictionary:
	var power_data: Dictionary[String, bool] = {}
	for ability_id_variant in player.abilities.unlocked_abilities:
		var ability_id := StringName(ability_id_variant)
		power_data[String(ability_id)] = player.abilities.is_unlocked(ability_id)
	return power_data


func _get_default_save_name() -> String:
	return "Save %s" % Time.get_datetime_string_from_system(false, true)


func _apply_player_save_data(player: PlayerCharacter, player_data: Dictionary) -> void:
	var stats_data := _get_dictionary(player_data, "stats")
	player.stats.level = _get_int(stats_data, "level", player.stats.level)
	player.stats.strength = _get_int(stats_data, "strength", player.stats.strength)
	player.stats.speed = _get_int(stats_data, "speed", player.stats.speed)
	player.stats.resilience = _get_int(stats_data, "resilience", player.stats.resilience)
	player.stats.experience = _get_int(stats_data, "experience", player.stats.experience)
	player.stats.money = _get_int(stats_data, "money", player.stats.money)

	var powers_data := _get_dictionary(player_data, "powers")
	for ability_id_variant in player.abilities.unlocked_abilities:
		var ability_id := StringName(ability_id_variant)
		var power_key := String(ability_id)
		if powers_data.get(power_key) is bool:
			player.abilities.set_unlocked(ability_id, powers_data[power_key])


func _get_dictionary(data: Dictionary, key: String) -> Dictionary:
	var value = data.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_int(data: Dictionary, key: String, default_value: int) -> int:
	var value = data.get(key, default_value)
	if value is int or value is float:
		return int(value)
	return default_value

extends Node

## Owns the game's single, versioned save file and applies its persistent data
## to the active Player.

const SAVE_PATH := "user://savegame.json"
const SAVE_FILE_NAME := "savegame.json"
const SAVE_VERSION := 2
# Tests override this path to keep the real save untouched.
var _save_path := SAVE_PATH

func _ready() -> void:
	# Restore the seed before the city enters the tree, without loading player data.
	if has_save():
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(_save_path)) == OK and json.data is Dictionary:
			get_node("/root/CityWindows").restore_data(_get_dictionary(_get_dictionary(json.data, "world"), "window_lighting"))
			return
	get_node("/root/CityWindows").start_new_game()

func begin_new_game(seed_override: int = -1) -> void:
	get_node("/root/CityWindows").start_new_game(seed_override)


func save_game() -> bool:
	var player := _get_player()
	if player == null:
		push_warning("SaveManager could not save because no PlayerCharacter was found.")
		return false

	var save_data := {
		"save_version": SAVE_VERSION,
		"save_name": _get_default_save_name(),
		"player": _get_player_save_data(player),
		"power_menu": _get_power_menu_save_data(),
		"progress": {},
		"world": {"window_lighting": get_node("/root/CityWindows").save_data()},
	}
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager could not open %s for writing." % _save_path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("SaveManager could not finish writing %s." % _save_path)
		return false
	return true


func load_game() -> bool:
	var save_data := _read_save_data()
	if save_data.is_empty():
		push_warning("SaveManager could not read a supported save from %s." % _save_path)
		return false

	var player := _get_player()
	if player == null:
		push_warning("SaveManager could not load because no PlayerCharacter was found.")
		return false

	_apply_game_save_data(player, save_data)
	return true


func can_load_game() -> bool:
	return not _read_save_data().is_empty()


## Launch from the main menu through the normal hideout travel path, preserving
## the placed gas station's exit location and all gameplay menus.
func start_saved_game() -> bool:
	var save_data := _read_save_data()
	if save_data.is_empty():
		return false
	return _start_game_in_hideout(save_data)


func start_new_game() -> bool:
	return _start_game_in_hideout({})


func _start_game_in_hideout(save_data: Dictionary) -> bool:
	if _get_player() != null:
		return false
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null: return false
	var city := packed.instantiate()
	var player := city.get_node_or_null("Player") as PlayerCharacter
	if player == null:
		city.free()
		return false
	var menu := get_tree().current_scene
	# Restore the seed before the city initializes its window materials.
	if save_data.is_empty():
		begin_new_game()
	else:
		get_node("/root/CityWindows").restore_data(_get_dictionary(_get_dictionary(save_data, "world"), "window_lighting"))
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	if not save_data.is_empty():
		_apply_game_save_data(player, save_data)
	var travel := get_tree().get_first_node_in_group(&"hideout_travel")
	var new_travel := travel == null
	if new_travel:
		travel = preload("res://scripts/hideout_travel.gd").new()
		travel.name = "HideoutTravel"
		get_tree().root.add_child(travel)
	if not travel.start_in_hideout(player):
		get_tree().current_scene = menu
		city.free()
		if new_travel: travel.free()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return false
	get_tree().paused = false
	if menu != null: menu.queue_free()
	return true


func _read_save_data() -> Dictionary:
	if not has_save(): return {}
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null: return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary: return {}
	var data: Dictionary = json.data
	if not data.get("player") is Dictionary: return {}
	# Version 1 (including unversioned legacy saves) remains supported.
	var version: Variant = data.get("save_version", 1)
	if not (version is int or version is float): return {}
	if float(version) not in [1.0, float(SAVE_VERSION)]: return {}
	return data


func _apply_game_save_data(player: PlayerCharacter, save_data: Dictionary) -> void:
	get_node("/root/CityWindows").restore_data(_get_dictionary(_get_dictionary(save_data, "world"), "window_lighting"))
	_apply_player_save_data(player, _get_dictionary(save_data, "player"))
	player.get_node("PlayerPowerController").progression.apply_save_data(_get_dictionary(save_data, "power_menu"))
	var selected: Variant = _get_dictionary(save_data, "player").get("active_power", "laser_eyes")
	var powers := player.get_node("PlayerPowerController")
	if not selected is String or not powers.select_active_power(StringName(selected)):
		powers.select_active_power(&"laser_eyes")


func has_save() -> bool:
	return FileAccess.file_exists(_save_path)


func delete_save() -> bool:
	if not has_save():
		return true

	var save_directory := DirAccess.open(_save_path.get_base_dir())
	if save_directory == null:
		push_error("SaveManager could not open user:// for save deletion.")
		return false

	var error := save_directory.remove(_save_path.get_file())
	if error != OK:
		push_error("SaveManager could not delete %s (error %d)." % [_save_path, error])
		return false
	return true


func _get_power_menu_save_data() -> Dictionary:
	var player := _get_player()
	if player == null: return {}
	return player.get_node("PlayerPowerController").progression.to_save_data()


func _get_player() -> PlayerCharacter:
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as PlayerCharacter
		if player != null:
			return player
	return null


func _get_player_save_data(player: PlayerCharacter) -> Dictionary:
	return {
		"active_power": String(player.get_node("PlayerPowerController").active_power),
		"stats": {
			"level": player.stats.level,
			"strength": player.stats.strength,
			"speed": player.stats.speed,
			"resilience": player.stats.resilience,
			"experience": player.stats.experience,
			"money": player.stats.money,
			"good_will": player.stats.good_will,
			"attribute_points": player.stats.attribute_points,
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
	player.stats.good_will = _get_int(stats_data, "good_will", 0)
	# Old test saves start with zero points, regardless of their saved level.
	player.stats.attribute_points = _get_int(stats_data, "attribute_points", 0)

	var powers_data := _get_dictionary(player_data, "powers")
	for ability_id_variant in player.abilities.unlocked_abilities:
		var ability_id := StringName(ability_id_variant)
		var power_key := String(ability_id)
		if not player.get_node("PlayerPowerController").REQUIREMENTS.has(ability_id) and powers_data.get(power_key) is bool:
			player.abilities.set_unlocked(ability_id, powers_data[power_key])


func _get_dictionary(data: Dictionary, key: String) -> Dictionary:
	var value = data.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_int(data: Dictionary, key: String, default_value: int) -> int:
	var value = data.get(key, default_value)
	if value is int:
		return value
	if value is float and is_finite(value):
		# JSON numbers may be doubles rounded beyond the signed integer boundary.
		if value >= float(PlayerStats.MAX_PROGRESSION_VALUE):
			return PlayerStats.MAX_PROGRESSION_VALUE
		if value <= float(-PlayerStats.MAX_PROGRESSION_VALUE - 1):
			return -PlayerStats.MAX_PROGRESSION_VALUE - 1
		return int(value)
	return default_value

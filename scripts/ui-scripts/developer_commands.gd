extends RefCounted
## Explicit game commands only; no shell, eval, or arbitrary property execution.
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const COMMANDS := ["help", "set", "add", "reset", "spawn", "debug", "save", "load", "status", "clear", "time", "weather"]
const WEATHER_HELP := "weather [thunderstorm | clear | lightning] - manual weather; weather alone shows conditions. Storms continue until cleared."
const TIME_HELP := "time [0-24 | dawn | day | sunset | night | pause | resume | speed 0-60] - preview the sky; time alone shows the clock."
const ATTRIBUTES := ["strength", "speed", "resilience"]
const COMPLETIONS := ["help", "set strength ", "set speed ", "set resilience ", "add xp ", "add attr ", "add pp ", "reset", "reset cooldowns", "spawn civilian", "spawn pistol_thug ", "spawn rifle_thug ", "spawn melee_thug ", "spawn super_thug ", "spawn hostile", "spawn gang_activity", "spawn rescue", "spawn helicopter_chase", "spawn ship_docking", "spawn pirates", "debug landing on", "debug landing off", "debug hud on", "debug hud off", "debug enemy_names on", "debug enemy_names off", "debug enemy_tints on", "debug enemy_tints off", "save", "load", "status", "clear", "time night", "time sunset", "time dawn", "time day", "time pause", "time resume", "time speed ", "weather thunderstorm", "weather clear", "weather lightning"]
const CIVILIAN_SCENE = preload("res://scenes/npcs/civilian.tscn")
const PISTOL_THUG_SCENE = preload("res://scenes/npcs/pistol_thug.tscn")
const RIFLE_THUG_SCENE = preload("res://scenes/npcs/rifle_thug.tscn")
const SUPER_THUG_SCENE = preload("res://scenes/npcs/super_thug.tscn")
const MELEE_THUG_SCENE = preload("res://scenes/npcs/melee_thug.tscn")
const DEBUG_OPTIONS := {"landing": "show_landing_target", "hud": "show_performance_hud", "enemy_names": "show_enemy_names", "enemy_tints": "show_enemy_tints"}
const SPAWN_SCENES := {
	"civilian": CIVILIAN_SCENE,
	"pistol_thug": PISTOL_THUG_SCENE,
	"rifle_thug": RIFLE_THUG_SCENE,
	"melee_thug": MELEE_THUG_SCENE,
	"super_thug": SUPER_THUG_SCENE,
	"hostile": PISTOL_THUG_SCENE,
}
const MAX_SPAWN_AMOUNT := 50
const ENCOUNTER_SCENES := {
	"pirates": preload("res://scenes/encounters/pirates.tscn"),
	"ship_docking": preload("res://scenes/encounters/ship_docking.tscn"),
	"gang_activity": preload("res://scenes/encounters/gang-activity/gang_activity.tscn"),
	"rescue": preload("res://scenes/encounters/rescue.tscn"),
	"helicopter_chase": preload("res://scenes/encounters/helicopter-chase/helicopter_chase.tscn"),
}
var player: PlayerCharacter
var spawned_npc_count := 0

func _init(target: PlayerCharacter) -> void:
	player = target

func execute(line: String) -> String:
	if not OS.is_debug_build(): return ""
	var words := line.strip_edges().to_lower().replace("\t", " ").split(" ", false)
	if words.is_empty(): return ""
	var command := words[0]
	if command not in COMMANDS: return COPY.text("console.unknown", {"command": command})
	if command == "help":
		if words.size() == 1: return help_text()
		if words.size() == 2 and words[1] == "time": return TIME_HELP
		if words.size() == 2 and words[1] == "weather": return WEATHER_HELP
		if words.size() == 2 and words[1] in COMMANDS: return COPY.text("console.help." + words[1])
		return COPY.text("console.help.help")
	if command == "time": return _time_command(words)
	if command == "weather": return _weather_command(words)
	if command == "reset" and words.size() == 2 and words[1] == "cooldowns":
		var cooldowns := player.get_node("/root/Weather")
		for field in ["thunderstorm_cooldown_remaining", "lightning_strike_cooldown_remaining", "external_combustion_cooldown_remaining", "frost_wall_cooldown_remaining"]:
			cooldowns.set(field, 0.0)
		return COPY.text("console.reset_cooldowns")
	if command == "set" or command == "add": return _change_value(command, words)
	if command == "spawn":
		if words.size() >= 2 and ENCOUNTER_SCENES.has(words[1]):
			if words.size() != 2:
				return COPY.text("console.help.spawn")
			return _spawn_encounter(words[1])
		if words.size() < 2 or words.size() > 3 or not SPAWN_SCENES.has(words[1]):
			return COPY.text("console.help.spawn")
		var amount := 1 if words.size() == 2 else _positive_integer(words[2])
		if amount < 1 or amount > MAX_SPAWN_AMOUNT:
			return COPY.text("console.help.spawn")
		return _spawn(words[1], amount)
	if command == "debug":
		if words.size() != 3 or not DEBUG_OPTIONS.has(words[1]) or words[2] not in ["on", "off"]: return COPY.text("console.help.debug")
		var manager := player.get_node("/root/DebugManager")
		manager.set(DEBUG_OPTIONS[words[1]], words[2] == "on")
		return COPY.text("console.debug", {"tool": words[1], "state": words[2]})
	if words.size() != 1: return COPY.text("console.help." + command)
	match command:
		"reset":
			_reset_player()
			return COPY.text("console.reset")
		"save":
			return COPY.text("console.saved" if player.get_node("/root/SaveManager").save_game() else "console.save_failed")
		"load":
			var saves := player.get_node("/root/SaveManager")
			if not saves.has_save(): return COPY.text("console.no_save")
			return COPY.text("console.loaded" if saves.load_game() else "console.load_failed")
		"status": return status_text()
		"clear": return ""
	return ""

func help_text() -> String:
	var lines: PackedStringArray = []
	for command in COMMANDS:
		if command == "weather": lines.append(WEATHER_HELP)
		else: lines.append(TIME_HELP if command == "time" else COPY.text("console.help." + command))
	return "\n".join(lines)

func _weather_command(words: PackedStringArray) -> String:
	var weather := player.get_node("/root/Weather")
	if words.size() == 1: return weather.status_text()
	if words.size() != 2: return WEATHER_HELP
	if words[1] == "lightning":
		return "Lightning queued; thunder follows after the distance delay. Resume play to see it." if weather.trigger_lightning() else "Start a thunderstorm first."
	if not weather.set_weather(StringName(words[1])): return WEATHER_HELP
	return weather.status_text()

func _time_command(words: PackedStringArray) -> String:
	var cycle := player.get_tree().get_first_node_in_group(&"day_night_cycle")
	if cycle == null: return "No day/night cycle in this scene."
	if words.size() == 3 and words[1] == "speed":
		if not words[2].is_valid_float(): return TIME_HELP
		var speed := words[2].to_float()
		if not is_finite(speed) or speed < 0.0 or speed > 60.0: return TIME_HELP
		cycle.time_scale = speed
	elif words.size() == 2:
		var presets := {"dawn": 6.0, "day": 12.0, "sunset": 18.0, "night": 0.0}
		if words[1] in presets: cycle.set_time(presets[words[1]])
		elif words[1] == "pause": cycle.cycle_running = false
		elif words[1] == "resume": cycle.cycle_running = true
		elif words[1].is_valid_float():
			var hours := words[1].to_float()
			if not is_finite(hours) or hours < 0.0 or hours > 24.0: return TIME_HELP
			cycle.set_time(hours)
		else: return TIME_HELP
	elif words.size() != 1: return TIME_HELP
	var minutes := int(cycle.time_of_day * 60.0) % 1440
	return "Sky: %02d:%02d | %s | speed %.1fx" % [minutes / 60, minutes % 60, "running" if cycle.cycle_running else "paused", cycle.time_scale]

func _change_value(command: String, words: PackedStringArray) -> String:
	if words.size() != 3: return COPY.text("console.help." + command)
	var target := words[1]
	if (command == "set" and target not in ATTRIBUTES) or (command == "add" and target not in ["xp", "attr", "pp"]):
		return COPY.text("console.help." + command)
	var number := _positive_integer(words[2])
	if number < 1: return COPY.text("console.invalid_number")
	var stats := player.stats
	if command == "set":
		stats.set(target, number)
		return COPY.text("console.set", {"attribute": COPY.text("gameplay.attribute." + target), "base": stats.get(target), "bonus": stats.get_power_bonus(StringName(target))})
	match target:
		"xp": stats.add_experience(number)
		"attr": stats.attribute_points += mini(number, PlayerStats.MAX_PROGRESSION_VALUE - stats.attribute_points)
		"pp": player.get_node("PlayerPowerController").progression.add_tokens(number)
	return COPY.text("console.updated") + "\n" + status_text()

func _positive_integer(value: String) -> int:
	# Validate before conversion, so huge integer text cannot wrap or round.
	if value.is_empty(): return -1
	for character in value:
		if character < "0" or character > "9": return -1
	var normalized := value.lstrip("0")
	var limit := str(PlayerStats.MAX_PROGRESSION_VALUE)
	if normalized.is_empty() or normalized.length() > limit.length(): return -1
	if normalized.length() == limit.length() and normalized > limit: return -1
	return normalized.to_int()

func status_text() -> String:
	var stats := player.stats
	return COPY.text("console.status", {"level": stats.level, "xp": stats.experience, "required": stats.get_experience_to_next_level(), "attr": stats.attribute_points, "pp": player.get_node("PlayerPowerController").progression.tokens,
		"strength": stats.strength, "strength_bonus": stats.get_power_bonus(PlayerStats.STRENGTH), "speed": stats.speed, "speed_bonus": stats.get_power_bonus(PlayerStats.SPEED), "resilience": stats.resilience}) + "\nMoney: $%d | Good Will: %d" % [stats.money, stats.good_will]

func _reset_player() -> void:
	player.rescue_carrier.drop_patient()
	player.vehicle_interactor.drop_held_vehicle()
	player.combat_controller.cancel_punch()
	# Reset is an explicit developer restart, including the terminal death state.
	if player.state_machine.active_state != null:
		player.state_machine.active_state.exit(player.grounded_state)
	for field in ["is_dead", "is_flying", "is_ground_slamming", "is_knocked_out", "is_wall_running", "has_knockout_landed", "is_charging_jump", "is_jump_active", "ground_slam_impact_pending"]:
		player.set(field, false)
	player.jump_charge = 0
	player.air_jump_used = false
	player.bounding_controller.reset()
	player.jump_hold_time = 0
	player.knockout_stun_remaining = 0
	player.velocity = Vector3.ZERO
	player.current_flight_speed = 0
	player.stats.level = 1
	player.stats.experience = 0
	player.stats.attribute_points = 0
	for attribute in ATTRIBUTES: player.stats.set(attribute, 1)
	for ability in player.abilities.unlocked_abilities: player.abilities.set_unlocked(ability, false)
	player.get_node("PlayerPowerController").progression.apply_save_data({})
	player.current_ground_speed = player._get_walk_speed()
	player.status_effects.hit_slowdown_remaining = 0
	player.stamina.restore_full()
	var health = player.damage_receiver.health_component
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	var animation := player.animation_controller
	animation.is_playing_death = false
	animation.is_knocked_down = false
	animation.is_hit_reacting = false
	animation.is_playing_landing_animation = false
	player.character_animation_player.stop()
	player.superhero_character.rotation = player.superhero_character_default_rotation
	player.landing_impact_controller.reset_normal_landing_tracking()
	player.landing_impact_controller.max_effect_downward_speed = 0
	player.state_machine.initialize(player, player.grounded_state)
	player.flight_speed_changed.emit(0, player.stats.get_run_speed(player.minimum_run_speed, player.run_speed_per_attribute_point), false)
	player.input_controller.reset()

func _spawn_encounter(kind: String) -> String:
	var encounter := ENCOUNTER_SCENES[kind].instantiate() as BaseEncounter
	encounter.position = player.position
	encounter.debug_waypoint = true
	player.get_parent().add_child(encounter, true)
	if not encounter.start_encounter(player):
		var reason := encounter.spawn_error
		encounter.free()
		return "Encounter spawn failed: " + reason
	return "Spawned %s for hero level %d: %d completion XP, $%d, %d Good Will (enemy defeat XP is separate). Follow the waypoint; close the console to resume." % [encounter.display_name, encounter.hero_level_at_start, encounter.xp_reward, encounter.money_reward, encounter.good_will_reward]

func _spawn(kind: String, amount: int = 1) -> String:
	var canonical_kind := "pistol_thug" if kind == "hostile" else kind
	var packed: PackedScene = SPAWN_SCENES[canonical_kind]
	var spawned := 0
	# Exclude characters when finding ground, so groups don't spawn on heads.
	var exclusions: Array[RID] = [player.get_rid()]
	for group_name in [&"hostile", &"civilian"]:
		for existing in player.get_tree().get_nodes_in_group(group_name):
			if existing is CollisionObject3D:
				exclusions.append(existing.get_rid())
	for index in amount:
		# Each batch stays near the player's current location.
		var angle := index * 2.399963 + fmod(float(spawned_npc_count), TAU)
		var radius := 6.0 + sqrt(float(index)) * 2.5
		var position := player.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 50, position + Vector3.DOWN * 200)
		query.exclude = exclusions
		query.collision_mask = 1
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		position = hit.position + Vector3.UP * 0.05
		var npc := packed.instantiate() as CharacterBody3D
		npc.name = "Dev" + canonical_kind.to_pascal_case()
		npc.position = (player.get_parent() as Node3D).to_local(position)
		player.get_parent().add_child(npc, true)
		exclusions.append(npc.get_rid())
		spawned += 1
	spawned_npc_count += spawned
	return COPY.text("console.spawned", {"kind": canonical_kind, "amount": spawned, "requested": amount})

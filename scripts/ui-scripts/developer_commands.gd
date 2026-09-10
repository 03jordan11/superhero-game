extends RefCounted
## Explicit game commands only; no shell, eval, or arbitrary property execution.
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const COMMANDS := ["help", "set", "add", "reset", "spawn", "debug", "save", "load", "status", "clear"]
const ATTRIBUTES := ["strength", "speed", "resilience"]
const COMPLETIONS := ["help", "set strength ", "set speed ", "set resilience ", "add xp ", "add attr ", "add pp ", "reset", "spawn civilian", "spawn hostile", "debug landing on", "debug landing off", "debug hud on", "debug hud off", "save", "load", "status", "clear"]
const CIVILIAN_SCENE = preload("res://scenes/npcs/civilian.tscn")
const HOSTILE_SCENE = preload("res://scenes/npcs/hostile.tscn")
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
		if words.size() == 2 and words[1] in COMMANDS: return COPY.text("console.help." + words[1])
		return COPY.text("console.help.help")
	if command == "set" or command == "add": return _change_value(command, words)
	if command == "spawn":
		if words.size() != 2 or words[1] not in ["civilian", "hostile"]: return COPY.text("console.help.spawn")
		return _spawn(words[1])
	if command == "debug":
		if words.size() != 3 or words[1] not in ["landing", "hud"] or words[2] not in ["on", "off"]: return COPY.text("console.help.debug")
		var manager := player.get_node("/root/DebugManager")
		manager.set("show_landing_target" if words[1] == "landing" else "show_performance_hud", words[2] == "on")
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
	for command in COMMANDS: lines.append(COPY.text("console.help." + command))
	return "\n".join(lines)

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
		"strength": stats.strength, "strength_bonus": stats.get_power_bonus(PlayerStats.STRENGTH), "speed": stats.speed, "speed_bonus": stats.get_power_bonus(PlayerStats.SPEED), "resilience": stats.resilience})

func _reset_player() -> void:
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

func _spawn(kind: String) -> String:
	var npc := (CIVILIAN_SCENE if kind == "civilian" else HOSTILE_SCENE).instantiate() as CharacterBody3D
	var angle := spawned_npc_count * 2.399963
	var radius := 6.0 + sqrt(float(spawned_npc_count)) * 2.5
	var position := player.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 50, position + Vector3.DOWN * 200)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): position = hit.position + Vector3.UP * 0.05
	npc.name = "DevCivilian" if kind == "civilian" else "DevHostile"
	player.get_parent().add_child(npc, true)
	npc.global_position = position
	spawned_npc_count += 1
	return COPY.text("console.spawned", {"kind": kind})

class_name BaseEncounter
extends Node3D

## Base configuration and lifecycle contract for city encounters.

enum Difficulty { EASY, MID, HARD }

enum EncounterState {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

@export_category("Identity")
@export var encounter_id: StringName
@export var display_name: String
@export_multiline var description: String

@export_category("Requirements and Rewards")
@export var level_requirement: int = 1
@export var xp_reward: int = 0
@export var money_reward: int = 0
@export var reputation_reward: int = 0
@export var good_will_reward: int = 0

@export_category("Encounter Settings")
@export var encounter_radius: float = 30.0
@export var time_limit: float = 0.0
@export var cleanup_delay: float = 0.0

var state: EncounterState = EncounterState.INACTIVE
var difficulty: Difficulty = Difficulty.EASY
var hero_level_at_start: int = 1
var debug_waypoint: bool = false
var spawn_error: String = ""
var reward_player: PlayerCharacter

# Shared lifecycle signals.
signal encounter_started
signal encounter_completed
signal encounter_failed


func _ready() -> void:
	add_to_group(&"encounter")


static func difficulty_for_level(level: int) -> Difficulty:
	if level <= 3:
		return Difficulty.EASY
	if level <= 6:
		return Difficulty.MID
	return Difficulty.HARD


func start_encounter(hero: PlayerCharacter = null) -> bool:
	if state != EncounterState.INACTIVE:
		return false
	reward_player = hero if hero != null else get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if not is_instance_valid(reward_player):
		spawn_error = "No hero found."
		fail_encounter()
		return false
	hero_level_at_start = maxi(reward_player.stats.level, 1)
	difficulty = difficulty_for_level(hero_level_at_start)
	if not _prepare_encounter():
		fail_encounter()
		return false
	state = EncounterState.ACTIVE
	_activate_encounter()
	encounter_started.emit()
	return true


func _prepare_encounter() -> bool:
	# Subclasses validate and prepare everything before becoming active.
	return false


func _activate_encounter() -> void:
	pass


func get_waypoint_position() -> Vector3:
	return global_position


func get_waypoint_label() -> String:
	return display_name


func get_waypoint_priority() -> int:
	return 0


func complete_encounter() -> void:
	if state != EncounterState.ACTIVE:
		return
	state = EncounterState.COMPLETED
	if is_instance_valid(reward_player) and xp_reward > 0:
		reward_player.stats.add_experience(xp_reward)
	if is_instance_valid(reward_player):
		var stats := reward_player.stats
		stats.money += mini(maxi(money_reward, 0), PlayerStats.MAX_PROGRESSION_VALUE - stats.money)
		stats.good_will += mini(maxi(good_will_reward, 0), PlayerStats.MAX_PROGRESSION_VALUE - stats.good_will)
	encounter_completed.emit()
	_schedule_cleanup()


func fail_encounter() -> void:
	if state in [EncounterState.COMPLETED, EncounterState.FAILED]:
		return
	state = EncounterState.FAILED
	encounter_failed.emit()
	_schedule_cleanup()


func _schedule_cleanup() -> void:
	if cleanup_delay > 0.0:
		get_tree().create_timer(cleanup_delay, false).timeout.connect(_cleanup)


func _cleanup() -> void:
	queue_free()

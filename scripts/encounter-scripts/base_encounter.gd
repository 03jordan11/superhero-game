class_name BaseEncounter
extends Node3D

## Base configuration and lifecycle contract for city encounters.

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

@export_category("Encounter Settings")
@export var encounter_radius: float = 30.0
@export var time_limit: float = 0.0
@export var cleanup_delay: float = 0.0

var state: EncounterState = EncounterState.INACTIVE

signal encounter_started
signal encounter_completed
signal encounter_failed


func _ready() -> void:
	add_to_group(&"encounter")


func start_encounter() -> void:
	pass


func complete_encounter() -> void:
	pass


func fail_encounter() -> void:
	pass

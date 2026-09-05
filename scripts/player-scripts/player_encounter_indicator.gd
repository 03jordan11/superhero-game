class_name PlayerEncounterIndicator
extends Node3D

## Keeps a world-space marker in front of the player aimed at the nearest
## active encounter.

@export var forward_distance: float = 3.5
@export var height_above_player: float = 1.4

@onready var distance_label: Label3D = $DistanceLabel

var player: PlayerCharacter


func _ready() -> void:
	player = get_parent() as PlayerCharacter
	if player == null:
		push_error("PlayerEncounterIndicator requires a PlayerCharacter parent.")
		return
	visible = false


func _process(_delta: float) -> void:
	if player == null:
		return

	var encounter := _get_nearest_active_encounter()
	if encounter == null:
		visible = false
		return

	visible = true
	_update_marker(encounter)


func _get_nearest_active_encounter() -> BaseEncounter:
	var nearest_encounter: BaseEncounter
	var nearest_distance_squared := INF
	for node in get_tree().get_nodes_in_group(&"encounter"):
		var encounter := node as BaseEncounter
		if encounter == null or encounter.state != BaseEncounter.EncounterState.ACTIVE:
			continue

		var distance_squared := player.global_position.distance_squared_to(
			encounter.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_encounter = encounter
			nearest_distance_squared = distance_squared
	return nearest_encounter


func _update_marker(encounter: BaseEncounter) -> void:
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() == 0.0:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	global_position = (
		player.global_position
		+ forward * forward_distance
		+ Vector3.UP * height_above_player
	)
	var target_position := encounter.global_position
	target_position.y = global_position.y
	if target_position.distance_squared_to(global_position) > 0.001:
		look_at(target_position, Vector3.UP)

	var distance_meters := roundi(player.global_position.distance_to(
		encounter.global_position
	))
	distance_label.text = "%s\n%d m" % [encounter.display_name, distance_meters]

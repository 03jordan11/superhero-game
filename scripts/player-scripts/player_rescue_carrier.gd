class_name PlayerRescueCarrier
extends Node
## Person pickup/drop; PlayerCharacter.is_carrying() arbitrates all pickup paths.

@export var pickup_range := 4.0
@export var carry_offset := Vector3(0, 0.45, -0.9)
@export var drop_distance := 1.8
var held_patient: RescuePatient
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	player.get_node("PlayerStateMachine/DeadState").death_started.connect(drop_patient)

func has_patient() -> bool:
	return is_instance_valid(held_patient)

func try_pick_up() -> bool:
	if player.is_carrying() or player.is_dead or player.is_knocked_out: return false
	var nearest: RescuePatient
	var distance := pickup_range * pickup_range
	for node in get_tree().get_nodes_in_group(&"rescue_patient"):
		var patient := node as RescuePatient
		if patient == null or is_instance_valid(patient.carrier): continue
		if not is_instance_valid(patient.encounter) or patient.encounter.state != BaseEncounter.EncounterState.ACTIVE: continue
		var candidate := player.global_position.distance_squared_to(patient.global_position)
		if candidate > distance: continue
		var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP,
			patient.global_position + Vector3.UP * 0.4, 1, [player.get_rid(), patient.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		nearest = patient
		distance = candidate
	if nearest == null: return false
	held_patient = nearest
	nearest.carrier = player
	nearest.velocity = Vector3.ZERO
	nearest.set_physics_process(false)
	nearest.reparent(player)
	nearest.position = carry_offset
	nearest.rotation = Vector3(0, PI / 2.0, 0)
	# Death animations translate the skeleton away from its scene origin.
	# Center the posed body at chest height rather than carrying that empty origin.
	nearest.global_position += player.to_global(carry_offset) - nearest.get_carry_anchor_position()
	return true

func drop_patient() -> void:
	if not has_patient(): return
	var patient := held_patient
	held_patient = null
	patient.carrier = null
	if not is_instance_valid(patient.encounter) or patient.encounter.is_queued_for_deletion():
		patient.queue_free()
		return
	var forward := -player.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var origin := player.global_position + Vector3.UP * 0.6
	var destination := origin + forward * drop_distance
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, [player.get_rid(), patient.get_rid()])
	var obstruction := space.intersect_ray(query)
	if not obstruction.is_empty(): destination = obstruction.position - forward * 1.0
	query.from = destination + Vector3.UP
	query.to = destination + Vector3.DOWN * 2.0
	var ground := space.intersect_ray(query)
	if not ground.is_empty() and ground.normal.y > 0.7:
		destination = ground.position + Vector3.UP * 0.05
	patient.reparent(patient.encounter)
	patient.global_position = destination
	patient.global_rotation = Vector3(0, player.global_rotation.y, 0)
	patient.velocity = Vector3.ZERO
	patient.set_physics_process(true)

class_name GangActivityEncounter
extends BaseEncounter

## Spawns a group of hostiles at a random ground position. The encounter ends
## when its final hostile dies.

const HOSTILE_SCENE: PackedScene = preload("res://scenes/npcs/hostile.tscn")

@export_category("Gang Activity")
@export_range(1, 20, 1) var hostile_count: int = 3
@export var random_location_radius: float = 150.0
@export var hostile_spawn_radius: float = 12.0
@export var ground_ray_start_height: float = 100.0
@export var ground_ray_depth: float = 250.0
@export_range(1, 100, 1) var ground_search_attempts: int = 16
@export_flags_3d_physics var ground_collision_mask: int = 1

var active_hostiles: Array[NPCBase] = []
var random_number_generator := RandomNumberGenerator.new()


func start_encounter() -> void:
	if state != EncounterState.INACTIVE:
		return

	random_number_generator.randomize()
	var ground_position: Variant = _find_random_ground_position(
		global_position,
		random_location_radius
	)
	if ground_position == null:
		fail_encounter()
		return

	global_position = ground_position
	state = EncounterState.ACTIVE
	encounter_started.emit()
	_spawn_hostiles()
	if active_hostiles.is_empty():
		fail_encounter()


func complete_encounter() -> void:
	if state != EncounterState.ACTIVE:
		return

	state = EncounterState.COMPLETED
	_award_experience()
	encounter_completed.emit()
	_schedule_cleanup()


func fail_encounter() -> void:
	if state == EncounterState.COMPLETED or state == EncounterState.FAILED:
		return

	state = EncounterState.FAILED
	encounter_failed.emit()
	_schedule_cleanup()


func _spawn_hostiles() -> void:
	for hostile_index in hostile_count:
		var hostile := HOSTILE_SCENE.instantiate() as NPCBase
		if hostile == null:
			push_error("GangActivityEncounter could not instantiate a hostile.")
			continue

		var spawn_position: Variant = _find_random_ground_position(
			global_position,
			hostile_spawn_radius
		)
		if spawn_position == null:
			spawn_position = global_position

		hostile.name = "GangHostile_%d" % (hostile_index + 1)
		add_child(hostile)
		hostile.global_position = spawn_position
		hostile.died.connect(_on_hostile_died)
		active_hostiles.append(hostile)


func _on_hostile_died(hostile: NPCBase) -> void:
	active_hostiles.erase(hostile)
	if active_hostiles.is_empty():
		complete_encounter()


func _find_random_ground_position(
	center: Vector3,
	radius: float
) -> Variant:
	if get_world_3d() == null:
		return null

	for _attempt in ground_search_attempts:
		var random_angle := random_number_generator.randf_range(0.0, TAU)
		var random_distance := sqrt(random_number_generator.randf()) * maxf(radius, 0.0)
		var horizontal_offset := Vector3(
			cos(random_angle) * random_distance,
			0.0,
			sin(random_angle) * random_distance
		)
		var ray_start := center + horizontal_offset + Vector3.UP * ground_ray_start_height
		var ray_end := ray_start + Vector3.DOWN * ground_ray_depth
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = ground_collision_mask
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"] as Vector3

	return null


func _award_experience() -> void:
	if xp_reward <= 0:
		return

	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player != null:
		player.stats.add_experience(xp_reward)


func _schedule_cleanup() -> void:
	if cleanup_delay <= 0.0:
		return

	var cleanup_timer := get_tree().create_timer(cleanup_delay)
	cleanup_timer.timeout.connect(queue_free)

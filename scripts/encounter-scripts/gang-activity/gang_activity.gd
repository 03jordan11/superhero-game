class_name GangActivityEncounter
extends BaseEncounter
## Level-scaled elimination rules; lifecycle/rewards belong to BaseEncounter.

const ENEMIES := {
	&"pistol_thug": preload("res://scenes/npcs/pistol_thug.tscn"),
	&"rifle_thug": preload("res://scenes/npcs/rifle_thug.tscn"),
	&"melee_thug": preload("res://scenes/npcs/melee_thug.tscn"),
	&"super_thug": preload("res://scenes/npcs/super_thug.tscn"),
}
@export_category("Gang Difficulty")
@export var easy_xp: int = 100
@export var mid_xp: int = 500
@export var hard_xp: int = 1000
@export_range(0.0, 1.0, 0.01) var easy_rifle_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var mid_super_chance: float = 0.02
@export_category("Random Placement")
@export var random_location_min_radius: float = 60.0
@export var random_location_radius: float = 200.0
@export var hostile_spawn_radius: float = 10.0
@export var minimum_hostile_spacing: float = 2.2
@export var ground_ray_start_height: float = 150.0
@export var ground_ray_depth: float = 500.0
@export var maximum_group_height_difference: float = 1.25
## Current city dry ground extends down to -0.12; reject river/ocean beds.
@export var minimum_ground_height: float = -0.15
@export_range(1, 100, 1) var ground_search_attempts: int = 32
@export_flags_3d_physics var ground_collision_mask: int = 1

var active_hostiles: Array[NPCBase] = []
var roster: Array[StringName] = []
var random_number_generator := RandomNumberGenerator.new()
var _spawn_positions: Array[Vector3] = []
var _exclusions: Array[RID] = []

func _init() -> void:
	encounter_id = &"gang_activity"
	display_name = "Gang Activity"
	cleanup_delay = 15.0
	random_number_generator.randomize()

func build_roster(tier: Difficulty) -> Array[StringName]:
	var result: Array[StringName] = []
	var total := 4
	match tier:
		Difficulty.EASY:
			if random_number_generator.randf() < easy_rifle_chance:
				result.append(&"rifle_thug")
			else:
				for index in random_number_generator.randi_range(1, 3):
					result.append(&"pistol_thug")
		Difficulty.MID:
			total = 5
			result.append(&"super_thug" if random_number_generator.randf() < mid_super_chance else &"rifle_thug")
			for index in random_number_generator.randi_range(2, 3):
				result.append(&"pistol_thug")
		Difficulty.HARD:
			total = 7
			for kind in [&"rifle_thug", &"pistol_thug", &"super_thug"]:
				for index in random_number_generator.randi_range(1, 2):
					result.append(kind)
	while result.size() < total:
		result.append(&"melee_thug")
	return result

func _prepare_encounter() -> bool:
	roster = build_roster(difficulty)
	xp_reward = [easy_xp, mid_xp, hard_xp][difficulty]
	display_name = "Gang Activity (%s)" % ["Easy", "Mid", "Hard"][difficulty]
	_exclusions.clear()
	for group in [&"player", &"hostile", &"civilian", &"vehicle"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CollisionObject3D:
				_exclusions.append(node.get_rid())
	# Plan the complete group first; never stack enemies or spawn a partial roster.
	for attempt in ground_search_attempts:
		var ground := _ground_at(global_position + _random_offset(random_location_min_radius, random_location_radius))
		if ground.is_empty():
			continue
		var center: Vector3 = ground.position
		if not _plan_group(center):
			continue
		global_position = center
		return true
	spawn_error = "Could not find clear ground for the complete gang. Move to an open area and try again."
	return false

func _random_offset(minimum: float, maximum: float) -> Vector3:
	var outer := maxf(maximum, 0.0)
	var inner := clampf(minimum, 0.0, outer)
	var radius := sqrt(random_number_generator.randf_range(inner * inner, outer * outer))
	var angle := random_number_generator.randf_range(0.0, TAU)
	return Vector3(cos(angle), 0, sin(angle)) * radius

func _ground_at(position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * ground_ray_start_height,
		position + Vector3.UP * ground_ray_start_height + Vector3.DOWN * ground_ray_depth,
		ground_collision_mask, _exclusions
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.9 or hit.position.y < minimum_ground_height:
		return {}
	return hit

func _plan_group(center: Vector3) -> bool:
	_spawn_positions.clear()
	# Conservative clearance accommodates the largest current enemy.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.85
	capsule.height = 2.9
	for kind in roster:
		var found := false
		for attempt in ground_search_attempts:
			var ground := _ground_at(center + _random_offset(0, hostile_spawn_radius))
			if ground.is_empty() or absf(ground.position.y - center.y) > maximum_group_height_difference:
				continue
			var position: Vector3 = ground.position + Vector3.UP * 0.05
			var overlaps := false
			for existing in _spawn_positions:
				if existing.distance_to(position) < minimum_hostile_spacing:
					overlaps = true
					break
			if overlaps:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = position + Vector3.UP * capsule.height * 0.5
			query.collision_mask = ground_collision_mask
			# Include existing actors in clearance checks.
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			_spawn_positions.append(position)
			found = true
			break
		if not found:
			return false
	return true

func _activate_encounter() -> void:
	for index in roster.size():
		var hostile := ENEMIES[roster[index]].instantiate() as NPCBase
		hostile.name = "GangHostile_%d" % (index + 1)
		hostile.position = to_local(_spawn_positions[index])
		add_child(hostile)
		hostile.died.connect(_on_hostile_died)
		hostile.tree_exiting.connect(_on_hostile_removed.bind(hostile))
		active_hostiles.append(hostile)

func _on_hostile_died(hostile: NPCBase) -> void:
	if state != EncounterState.ACTIVE or not active_hostiles.has(hostile):
		return
	active_hostiles.erase(hostile)
	if active_hostiles.is_empty():
		complete_encounter()

func _on_hostile_removed(hostile: NPCBase) -> void:
	if state == EncounterState.ACTIVE and active_hostiles.has(hostile):
		fail_encounter()

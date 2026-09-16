extends BaseEncounter
## Stationary harbor boarding fight. Owns a separate vessel, never the dock service.
const SHIP = preload("res://assets/waterfront/cargo_ship/cargo_ship_oxide_red.tscn")
const ENEMIES = {
	&"pistol_thug": preload("res://scenes/npcs/pistol_thug.tscn"),
	&"melee_thug": preload("res://scenes/npcs/melee_thug.tscn"),
	&"rifle_thug": preload("res://scenes/npcs/rifle_thug.tscn"),
	&"super_thug": preload("res://scenes/npcs/super_thug.tscn"),
}
const ROSTER: Array[StringName] = [&"pistol_thug", &"pistol_thug", &"melee_thug", &"melee_thug", &"melee_thug", &"rifle_thug", &"super_thug"]
@export_category("Pirate Ship")
## Relative to the cargo berth: +X seaward; -Z toward the bow.
@export var harbor_offset := Vector3(220, 0, 0)
## X/Z positions on the open forecastle; Y is found from actual deck collision.
@export var deck_positions := PackedVector3Array([
	Vector3(-5,0,-56), Vector3(5,0,-56),
	Vector3(-4,0,-61), Vector3(0,0,-65), Vector3(-3,0,-68),
	Vector3(4,0,-65), Vector3(0,0,-57),
])
@export var deck_detection_radius := 40.0
@export var overboard_depth := 0.5
var ship: Node3D
var active_hostiles: Array[HostileBase] = []
var _spawn_positions: Array[Vector3] = []
var _hull := BoxShape3D.new()

func _init() -> void:
	encounter_id = &"pirates"
	display_name = "Pirates"
	description = "Board the pirate cargo ship and defeat all seven enemies."
	xp_reward = 500
	cleanup_delay = 15.0
	encounter_radius = 90.0
	_hull.size = Vector3(28,32,162)

func _prepare_encounter() -> bool:
	var schedule := get_tree().get_first_node_in_group(&"cargo_ship_schedule")
	if schedule == null:
		spawn_error = "This encounter needs the harbor cargo-ship berth."
		return false
	for other in get_tree().get_nodes_in_group(&"pirate_encounter"):
		if other != self:
			spawn_error = "A pirate ship is already in the harbor."
			return false
	if deck_positions.size() != ROSTER.size():
		spawn_error = "The pirate roster requires seven deck positions."
		return false
	var berth: Transform3D = schedule.berth_transform
	var pose := berth
	pose.origin = berth * harbor_offset
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hull
	query.transform = pose.translated_local(Vector3.UP * 10.0)
	query.collision_mask = 1
	# Include the other vessel and actors: don't spawn through an occupied harbor.
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		spawn_error = "The pirate ship's offshore position is obstructed. Try again when the water is clear."
		return false
	global_transform = pose
	ship = SHIP.instantiate()
	ship.name = "PirateShip"
	ship.navigation_mode = 1 # Anchored; no HarborSchedule on this instance.
	add_child(ship)
	ship.get_node("Collision").force_update_transform()
	if not _plan_deck_positions():
		ship.free()
		ship = null
		return false
	add_to_group(&"pirate_encounter")
	return true

func _plan_deck_positions() -> bool:
	_spawn_positions.clear()
	var space := get_world_3d().direct_space_state
	var clearance := CapsuleShape3D.new()
	clearance.radius = 0.85
	clearance.height = 2.9
	for local_point in deck_positions:
		var point := ship.to_global(local_point)
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 30, point + Vector3.DOWN * 2, 1)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.collider != ship.get_node("Collision") or hit.normal.y < 0.85:
			spawn_error = "A pirate spawn point has no safe ship deck below it."
			return false
		var feet: Vector3 = hit.position + Vector3.UP * 0.08
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = clearance
		query.transform.origin = feet + Vector3.UP * clearance.height * 0.5
		query.collision_mask = 1
		if not space.intersect_shape(query,1).is_empty():
			spawn_error = "A pirate spawn point has insufficient standing room."
			return false
		for other in _spawn_positions:
			if feet.distance_to(other) < 2.2:
				spawn_error = "Pirate spawn points are too close together."
				return false
		_spawn_positions.append(feet)
	return true

func _activate_encounter() -> void:
	for i in ROSTER.size():
		var enemy := ENEMIES[ROSTER[i]].instantiate() as HostileBase
		enemy.name = "Pirate_%d" % (i + 1)
		enemy.position = to_local(_spawn_positions[i])
		enemy.guard_detection_radius = deck_detection_radius
		enemy.alert_radius = 55.0
		enemy.required_walk_surface = ship.get_node("Collision")
		add_child(enemy)
		enemy.died.connect(_on_hostile_died)
		enemy.tree_exiting.connect(_on_hostile_removed.bind(enemy))
		active_hostiles.append(enemy)

func _physics_process(_delta: float) -> void:
	if state != EncounterState.ACTIVE: return
	if not is_instance_valid(ship) or not is_instance_valid(reward_player) or reward_player.is_dead:
		fail_encounter()
		return
	# Knockbacks/throws can knock pirates overboard. Resolve them as defeated
	# at the waterline instead of leaving an unreachable enemy on the seabed.
	for enemy in active_hostiles.duplicate():
		if is_instance_valid(enemy) and not enemy.is_grabbed and enemy.global_position.y < ship.global_position.y - overboard_depth:
			enemy.apply_damage(preload("res://scripts/combat-scripts/damage_info.gd").new(enemy.get_current_health(), enemy.global_position, Vector3.ZERO, &"none", reward_player))

func _on_hostile_died(enemy: NPCBase) -> void:
	if state != EncounterState.ACTIVE or not active_hostiles.has(enemy): return
	active_hostiles.erase(enemy)
	if active_hostiles.is_empty(): complete_encounter()

func _on_hostile_removed(enemy: NPCBase) -> void:
	if state == EncounterState.ACTIVE and active_hostiles.has(enemy): fail_encounter()

func get_waypoint_position() -> Vector3:
	if is_instance_valid(ship): return ship.to_global(Vector3(0,9,-61))
	return global_position

func get_waypoint_label() -> String:
	return "Pirates — %d enemies remaining" % active_hostiles.size()

func _cleanup() -> void:
	# Never remove the deck underneath a living player after the victory timer.
	if is_instance_valid(ship) and is_instance_valid(reward_player) and not reward_player.is_dead:
		var local := ship.to_local(reward_player.global_position)
		if absf(local.x) < 18 and absf(local.z) < 85 and local.y > -2 and local.y < 35:
			get_tree().create_timer(3.0, false).timeout.connect(_cleanup)
			return
	super()

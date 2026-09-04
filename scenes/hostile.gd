extends "res://scripts/npc_base.gd"

const DAMAGE_INFO_SCRIPT = preload("res://scripts/damage_info.gd")
const PISTOL_WEAPON_SCRIPT = preload("res://scripts/pistol_weapon.gd")

enum State {
	GUARD,
	PATROL,
	COMBAT,
	SEARCH,
	KNOCKED_DOWN,
	DEAD
}

enum WeaponType {
	PISTOL,
	RIFLE,
	MELEE
}

@export var guard_detection_radius: float = 17.0
@export var max_threat_distance: float = 40.0
@export var aggro_range: float = 60.0
@export var alert_radius: float = 25.0
@export var alert_indicator_duration: float = 1.5
@export var weapon_type: WeaponType = WeaponType.PISTOL
@export_range(1, 99, 1) var pistol_magazine_size: int = 6
@export_range(0.0, 5.0, 0.05) var min_combat_action_delay: float = 0.2
@export_range(0.0, 5.0, 0.05) var max_combat_action_delay: float = 1.5
@export_range(0.0, 2.0, 0.05) var min_shot_pause: float = 0.1
@export_range(0.0, 2.0, 0.05) var max_shot_pause: float = 0.35
@export var target_horizontal_movement_threshold: float = 0.25
@export var pistol_shot_origin_height: float = 1.4
@export var pistol_target_height: float = 0.0
@export_range(0.0, 1.0, 0.05) var base_relocation_chance: float = 0.2
@export_range(0.0, 1.0, 0.05) var min_relocation_chance_growth: float = 0.05
@export_range(0.0, 1.0, 0.05) var max_relocation_chance_growth: float = 0.2
@export_range(0.0, 1.0, 0.05) var max_relocation_chance: float = 0.8
@export var relocation_dead_zone_half_width: float = 2.0
@export var relocation_speed: float = 6.0
@export var min_relocation_distance: float = 5.0
@export var max_relocation_distance: float = 10.0
@export_range(0.0, 90.0, 1.0) var min_relocation_angle_degrees: float = 20.0
@export_range(0.0, 90.0, 1.0) var max_relocation_angle_degrees: float = 65.0
@export_range(1, 20, 1) var relocation_candidate_attempts: int = 8
@export var relocation_arrival_distance: float = 0.6
@export var relocation_timeout: float = 4.0
@export var relocation_max_height_change: float = 1.0
@export var search_speed: float = 6.0
@export var search_arrival_distance: float = 1.0
@export var search_area_radius: float = 10.0
@export var obstacle_look_ahead_distance: float = 3.0
@export var obstacle_emergency_distance: float = 0.75
@export var obstacle_probe_radius: float = 0.5
@export var obstacle_probe_height: float = 0.9
@export_range(1.0, 90.0, 1.0) var obstacle_turn_angle_degrees: float = 55.0
@export var obstacle_turn_commit_duration: float = 0.75
@export var obstacle_collision_mask: int = 1

var current_state: State = State.GUARD
var combat_target: Node3D
var ammo_count: int = 0
var is_reloading: bool = false
var reload_completed: bool = false
var combat_action_delay_remaining: float = 0.0
var shot_pause_remaining: float = 0.0
var shot_in_progress: bool = false
var shots_since_relocation: int = 0
var relocation_chance: float = 0.2
var is_relocating: bool = false
var relocation_target: Vector3 = Vector3.ZERO
var relocation_time_remaining: float = 0.0
var last_known_target_position: Vector3 = Vector3.ZERO
var has_last_known_target_position: bool = false
var search_destination: Vector3 = Vector3.ZERO
var has_search_destination: bool = false
var obstacle_avoidance := CharacterObstacleAvoidance.new()
var pistol_weapon

@onready var alert_indicator: Label3D = $AlertIndicator
@onready var alert_indicator_timer: Timer = $AlertIndicatorTimer


func _ready() -> void:
	super()
	add_to_group(&"hostile")
	pistol_weapon = PISTOL_WEAPON_SCRIPT.new()
	ammo_count = pistol_magazine_size
	relocation_chance = base_relocation_chance
	obstacle_avoidance.configure(
		obstacle_look_ahead_distance,
		obstacle_emergency_distance,
		obstacle_probe_radius,
		obstacle_probe_height,
		obstacle_turn_angle_degrees,
		obstacle_turn_commit_duration,
		obstacle_collision_mask
	)
	alert_indicator.hide()
	alert_indicator_timer.timeout.connect(_on_alert_indicator_timer_timeout)
	animation_controller.connect(&"pistol_reload_finished", _on_pistol_reload_finished)


func _process_behavior(delta: float) -> void:
	match current_state:
		State.GUARD:
			_handle_guard()
		State.PATROL:
			_hold_position()
		State.COMBAT:
			_handle_combat(delta)
		State.SEARCH:
			_handle_search(delta)
		State.KNOCKED_DOWN:
			_hold_position()


func _on_died() -> void:
	current_state = State.DEAD


func _handle_guard() -> void:
	_hold_position()
	var player := _get_player()
	if player == null:
		return

	var offset_to_player := player.global_position - global_position
	offset_to_player.y = 0.0
	if offset_to_player.length_squared() <= guard_detection_radius * guard_detection_radius:
		_alert_nearby_hostiles(player)


func receive_alert(target: Node3D) -> void:
	if is_dead or not is_instance_valid(target):
		return

	var is_entering_combat := current_state != State.COMBAT
	combat_target = target
	current_state = State.COMBAT
	_remember_target_position()
	if is_entering_combat:
		combat_action_delay_remaining = randf_range(
			minf(min_combat_action_delay, max_combat_action_delay),
			maxf(min_combat_action_delay, max_combat_action_delay)
		)
	_hold_position()
	alert_indicator.show()
	alert_indicator_timer.start(alert_indicator_duration)


func _alert_nearby_hostiles(target: Node3D) -> void:
	for hostile_node in get_tree().get_nodes_in_group(&"hostile"):
		var nearby_hostile := hostile_node as Node3D
		if nearby_hostile == null:
			continue

		var offset_to_hostile := nearby_hostile.global_position - global_position
		offset_to_hostile.y = 0.0
		if offset_to_hostile.length_squared() > alert_radius * alert_radius:
			continue
		if nearby_hostile.has_method("receive_alert"):
			nearby_hostile.call("receive_alert", target)


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _handle_combat(delta: float) -> void:
	if not is_instance_valid(combat_target):
		current_state = State.GUARD
		combat_action_delay_remaining = 0.0
		is_relocating = false
		_hold_position()
		return

	if global_position.distance_to(combat_target.global_position) > aggro_range:
		_enter_search()
		return
	_remember_target_position()

	velocity.x = 0.0
	velocity.z = 0.0
	if combat_action_delay_remaining > 0.0:
		combat_action_delay_remaining = maxf(combat_action_delay_remaining - delta, 0.0)
		_hold_position()
		return

	if is_relocating:
		_handle_relocation(delta)
		return

	var direction_to_target := combat_target.global_position - global_position
	direction_to_target.y = 0.0
	if direction_to_target.length_squared() > 0.01:
		look_at(global_position + direction_to_target, Vector3.UP)

	match weapon_type:
		WeaponType.PISTOL:
			_handle_pistol_combat(delta)
		WeaponType.RIFLE, WeaponType.MELEE:
			_hold_position()


func _handle_pistol_combat(delta: float) -> void:
	if is_reloading:
		if reload_completed:
			ammo_count = pistol_magazine_size
			is_reloading = false
			reload_completed = false
		else:
			if not animation_controller.call("is_pistol_reloading"):
				animation_controller.call("play_pistol_reload")
			return

	if shot_in_progress:
		if animation_controller.call("is_pistol_shooting"):
			return
		shot_in_progress = false
		if shots_since_relocation % 4 == 0 and _try_begin_relocation():
			return
		if ammo_count > 0:
			shot_pause_remaining = randf_range(
				minf(min_shot_pause, max_shot_pause),
				maxf(min_shot_pause, max_shot_pause)
			)
			return

	if shot_pause_remaining > 0.0:
		shot_pause_remaining = maxf(shot_pause_remaining - delta, 0.0)
		return

	if ammo_count <= 0:
		is_reloading = true
		reload_completed = false
		animation_controller.call("play_pistol_reload")
		return

	ammo_count -= 1
	shots_since_relocation += 1
	shot_in_progress = true
	_resolve_pistol_shot()
	animation_controller.call("play_pistol_shot")


func _resolve_pistol_shot() -> void:
	if not is_instance_valid(combat_target):
		return

	var distance_to_target := global_position.distance_to(combat_target.global_position)
	var target_is_moving := _is_target_moving_horizontally()
	var hit_chance: float = pistol_weapon.calculate_hit_chance(
		distance_to_target,
		target_is_moving
	)
	if hit_chance <= 0.0 or randf() > hit_chance:
		return
	if not _has_clear_shot_to_target():
		return
	if not combat_target.has_method("apply_damage"):
		return

	var shot_direction := combat_target.global_position - global_position
	var damage_amount: float = pistol_weapon.calculate_damage(distance_to_target)
	var damage_info = DAMAGE_INFO_SCRIPT.new(
		damage_amount,
		global_position + Vector3.UP * pistol_shot_origin_height,
		shot_direction.normalized(),
		&"none",
		self
	)
	combat_target.call("apply_damage", damage_info)


func _is_target_moving_horizontally() -> bool:
	var character_target := combat_target as CharacterBody3D
	if character_target == null:
		return false

	var horizontal_velocity := Vector2(
		character_target.velocity.x,
		character_target.velocity.z
	)
	return horizontal_velocity.length() > target_horizontal_movement_threshold


func _has_clear_shot_to_target() -> bool:
	var shot_origin := global_position + Vector3.UP * pistol_shot_origin_height
	var target_position := combat_target.global_position + Vector3.UP * pistol_target_height
	var query := PhysicsRayQueryParameters3D.create(shot_origin, target_position)
	query.collision_mask = obstacle_collision_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	return result["collider"] == combat_target


func _try_begin_relocation() -> bool:
	var distance_to_target := _get_horizontal_distance_to_target()
	var range_midpoint := (guard_detection_radius + max_threat_distance) * 0.5
	if absf(distance_to_target - range_midpoint) <= relocation_dead_zone_half_width:
		return false

	var distance_pressure := _get_distance_pressure()
	var chance_growth := lerpf(
		min_relocation_chance_growth,
		max_relocation_chance_growth,
		distance_pressure
	)
	relocation_chance = minf(
		relocation_chance + chance_growth,
		max_relocation_chance
	)
	if randf() > relocation_chance:
		return false

	var candidate := _find_relocation_destination()
	if candidate.is_empty():
		return false

	relocation_target = candidate["position"]
	relocation_time_remaining = relocation_timeout
	is_relocating = true
	return true


func _get_distance_pressure() -> float:
	var distance_to_target := _get_horizontal_distance_to_target()
	var inner_range := minf(guard_detection_radius, max_threat_distance)
	var outer_range := maxf(guard_detection_radius, max_threat_distance)
	var range_midpoint := (inner_range + outer_range) * 0.5
	var half_range := maxf((outer_range - inner_range) * 0.5, 0.001)
	var dead_zone_width := clampf(relocation_dead_zone_half_width, 0.0, half_range)
	var distance_outside_dead_zone := maxf(
		absf(distance_to_target - range_midpoint) - dead_zone_width,
		0.0
	)
	var pressure_range := maxf(half_range - dead_zone_width, 0.001)
	return clampf(distance_outside_dead_zone / pressure_range, 0.0, 1.0)


func _find_relocation_destination() -> Dictionary:
	var direction_to_target := combat_target.global_position - global_position
	direction_to_target.y = 0.0
	if direction_to_target.length_squared() < 0.01:
		direction_to_target = -global_transform.basis.z
	direction_to_target = direction_to_target.normalized()

	var range_midpoint := (guard_detection_radius + max_threat_distance) * 0.5
	var base_direction := (
		direction_to_target
		if _get_horizontal_distance_to_target() > range_midpoint
		else -direction_to_target
	)
	var min_angle := minf(min_relocation_angle_degrees, max_relocation_angle_degrees)
	var max_angle := maxf(min_relocation_angle_degrees, max_relocation_angle_degrees)
	var min_distance := minf(min_relocation_distance, max_relocation_distance)
	var max_distance := maxf(min_relocation_distance, max_relocation_distance)
	var excluded_rids := _get_relocation_exclusions()

	for _attempt in relocation_candidate_attempts:
		var angle_sign := -1.0 if randf() < 0.5 else 1.0
		var angle := deg_to_rad(randf_range(min_angle, max_angle)) * angle_sign
		var move_direction := base_direction.rotated(Vector3.UP, angle).normalized()
		var candidate := global_position + move_direction * randf_range(min_distance, max_distance)
		var grounded_candidate := _get_grounded_relocation_position(candidate, excluded_rids)
		if grounded_candidate.is_empty():
			continue

		var destination: Vector3 = grounded_candidate["position"]
		if not _has_clear_relocation_path(destination, excluded_rids):
			continue
		if not _has_clear_relocation_destination(destination, excluded_rids):
			continue
		return {"position": destination}

	return {}


func _get_grounded_relocation_position(
	candidate: Vector3,
	excluded_rids: Array[RID]
) -> Dictionary:
	var ray_start := candidate + Vector3.UP * 3.0
	var ray_end := candidate + Vector3.DOWN * 8.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = obstacle_collision_mask
	query.exclude = excluded_rids
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}

	var ground_position: Vector3 = result["position"]
	if absf(ground_position.y - global_position.y) > relocation_max_height_change:
		return {}
	return {"position": ground_position + Vector3.UP * 0.05}


func _has_clear_relocation_path(
	destination: Vector3,
	excluded_rids: Array[RID]
) -> bool:
	var probe_height := Vector3.UP * obstacle_probe_height
	var query := PhysicsRayQueryParameters3D.create(
		global_position + probe_height,
		destination + probe_height
	)
	query.collision_mask = obstacle_collision_mask
	query.exclude = excluded_rids
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _has_clear_relocation_destination(
	destination: Vector3,
	excluded_rids: Array[RID]
) -> bool:
	var probe_shape := SphereShape3D.new()
	probe_shape.radius = obstacle_probe_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe_shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		destination + Vector3.UP * obstacle_probe_height
	)
	query.collision_mask = obstacle_collision_mask
	query.exclude = excluded_rids
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _get_relocation_exclusions() -> Array[RID]:
	var excluded_rids: Array[RID] = [get_rid()]
	for group_name in [&"player", &"hostile", &"civilian"]:
		for character_node in get_tree().get_nodes_in_group(group_name):
			var collision_object := character_node as CollisionObject3D
			if collision_object != null and collision_object != self:
				excluded_rids.append(collision_object.get_rid())
	return excluded_rids


func _get_horizontal_distance_to_target() -> float:
	var offset_to_target := combat_target.global_position - global_position
	offset_to_target.y = 0.0
	return offset_to_target.length()


func _remember_target_position() -> void:
	if not is_instance_valid(combat_target):
		return

	var target_position := combat_target.global_position
	var ray_start := target_position + Vector3.UP * 5.0
	var ray_end := target_position + Vector3.DOWN * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = obstacle_collision_mask
	query.exclude = _get_relocation_exclusions()
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		last_known_target_position = Vector3(
			target_position.x,
			global_position.y,
			target_position.z
		)
	else:
		last_known_target_position = result["position"]
	has_last_known_target_position = true


func _enter_search() -> void:
	current_state = State.SEARCH
	is_relocating = false
	combat_action_delay_remaining = 0.0
	shot_pause_remaining = 0.0
	shot_in_progress = false
	velocity.x = 0.0
	velocity.z = 0.0
	_choose_search_destination()


func _handle_search(delta: float) -> void:
	if not is_instance_valid(combat_target):
		current_state = State.GUARD
		has_last_known_target_position = false
		has_search_destination = false
		_hold_position()
		return

	if global_position.distance_to(combat_target.global_position) <= aggro_range:
		current_state = State.COMBAT
		combat_action_delay_remaining = randf_range(
			minf(min_combat_action_delay, max_combat_action_delay),
			maxf(min_combat_action_delay, max_combat_action_delay)
		)
		_remember_target_position()
		has_search_destination = false
		_hold_position()
		return

	if not has_search_destination:
		_hold_position()
		return

	var direction_to_search_destination := search_destination - global_position
	direction_to_search_destination.y = 0.0
	if direction_to_search_destination.length() <= search_arrival_distance:
		_hold_position()
		return

	var steered_direction := obstacle_avoidance.get_steered_direction(
		self,
		direction_to_search_destination,
		delta
	)
	velocity.x = steered_direction.x * search_speed
	velocity.z = steered_direction.z * search_speed
	if steered_direction.length_squared() > 0.01:
		look_at(global_position + steered_direction, Vector3.UP)
	animation_controller.call("set_is_running")


func _choose_search_destination() -> void:
	has_search_destination = false
	if not has_last_known_target_position:
		return

	var excluded_rids := _get_relocation_exclusions()
	for _attempt in relocation_candidate_attempts:
		var random_angle := randf_range(0.0, TAU)
		var random_distance := sqrt(randf()) * maxf(search_area_radius, 0.0)
		var candidate := last_known_target_position + Vector3(
			sin(random_angle) * random_distance,
			0.0,
			cos(random_angle) * random_distance
		)
		var grounded_candidate := _get_grounded_relocation_position(candidate, excluded_rids)
		if grounded_candidate.is_empty():
			continue

		var destination: Vector3 = grounded_candidate["position"]
		if not _has_clear_relocation_path(destination, excluded_rids):
			continue
		if not _has_clear_relocation_destination(destination, excluded_rids):
			continue

		search_destination = destination
		has_search_destination = true
		return

	# Preserve the original search behavior if no random candidate is valid.
	search_destination = last_known_target_position
	has_search_destination = true


func _handle_relocation(delta: float) -> void:
	relocation_time_remaining = maxf(relocation_time_remaining - delta, 0.0)
	var direction_to_destination := relocation_target - global_position
	direction_to_destination.y = 0.0
	if direction_to_destination.length() <= relocation_arrival_distance:
		_finish_relocation()
		return
	if relocation_time_remaining <= 0.0:
		is_relocating = false
		_hold_position()
		return

	var steered_direction := obstacle_avoidance.get_steered_direction(
		self,
		direction_to_destination,
		delta
	)
	velocity.x = steered_direction.x * relocation_speed
	velocity.z = steered_direction.z * relocation_speed
	if steered_direction.length_squared() > 0.01:
		look_at(global_position + steered_direction, Vector3.UP)
	animation_controller.call("set_is_running")


func _finish_relocation() -> void:
	is_relocating = false
	relocation_chance = base_relocation_chance
	shots_since_relocation = 0
	velocity.x = 0.0
	velocity.z = 0.0


func _hold_position() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	animation_controller.call("set_is_idle")


func _on_alert_indicator_timer_timeout() -> void:
	alert_indicator.hide()


func _on_pistol_reload_finished() -> void:
	reload_completed = true

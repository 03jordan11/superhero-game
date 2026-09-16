class_name RangedHostile
extends "res://scripts/npc-scripts/hostile_base.gd"

const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")

@export_category("Weapon")
@export var weapon: WeaponBase
@export_category("Ranged Combat")
@export var max_threat_distance: float = 40.0
@export_range(1, 99, 1) var magazine_size: int = 6
## Zero keeps animation-paced pistol shots. Positive values use a firing timer.
@export_range(0.0, 2.0, 0.01) var automatic_shot_interval: float = 0.0
@export_range(0.0, 2.0, 0.05) var min_shot_pause: float = 0.1
@export_range(0.0, 2.0, 0.05) var max_shot_pause: float = 0.35
@export var target_horizontal_movement_threshold: float = 0.25
@export var shot_origin_height: float = 1.4
@export var shot_target_height: float = 0.0
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
@export var relocation_arrival_distance: float = 0.6
@export var relocation_timeout: float = 4.0
var ammo_count: int = 0
var is_reloading: bool = false
var reload_completed: bool = false
var shot_pause_remaining: float = 0.0
var shot_in_progress: bool = false
var shots_since_relocation: int = 0
var relocation_chance: float = 0.2
var is_relocating: bool = false
var relocation_target: Vector3 = Vector3.ZERO
var relocation_time_remaining: float = 0.0

func _ready() -> void:
	super()
	ammo_count = magazine_size
	relocation_chance = base_relocation_chance


func _update_combat(delta: float) -> void:
	if is_relocating:
		_handle_relocation(delta)
	else:
		_handle_ranged_combat(delta)


func _reset_combat_actions() -> void:
	is_relocating = false
	shot_pause_remaining = 0.0
	shot_in_progress = false
	is_reloading = false
	reload_completed = false


func _on_damage_received(damage_info) -> void:
	super(damage_info)
	# Resume with a fresh shot/reload after the hit animation finishes.
	_reset_combat_actions()


func _handle_ranged_combat(delta: float) -> void:
	if weapon == null or not _can_target(combat_target):
		return
	if is_reloading:
		if reload_completed:
			ammo_count = magazine_size
			is_reloading = false
			reload_completed = false
		else:
			if not _is_reload_playing():
				_play_reload()
			return

	if automatic_shot_interval > 0.0:
		_handle_automatic_fire(delta)
		return

	if shot_in_progress:
		if _is_shot_playing():
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
		_play_reload()
		return

	_fire_round()


func _handle_automatic_fire(delta: float) -> void:
	shot_pause_remaining = maxf(shot_pause_remaining - delta, 0.0)
	if shot_pause_remaining > 0.0:
		return
	if shot_in_progress:
		shot_in_progress = false
		if shots_since_relocation % 4 == 0 and _try_begin_relocation():
			return
	if ammo_count <= 0:
		is_reloading = true
		reload_completed = false
		_play_reload()
		return
	# Deliberately independent of animation duration. Never catch up with a
	# burst of several hits in one frame after a hitch or a relocation.
	_fire_round()
	shot_pause_remaining = automatic_shot_interval


func _fire_round() -> void:
	ammo_count -= 1
	shots_since_relocation += 1
	shot_in_progress = true
	_play_shot_audio()
	_resolve_shot()
	_play_shot()


func _resolve_shot() -> void:
	if weapon == null or not _can_target(combat_target):
		return

	var distance_to_target := global_position.distance_to(combat_target.global_position)
	var target_is_moving := _is_target_moving_horizontally()
	var hit_chance: float = weapon.calculate_hit_chance(
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
	var damage_amount: float = weapon.calculate_damage(distance_to_target)
	var damage_info = DAMAGE_INFO_SCRIPT.new(
		damage_amount,
		global_position + Vector3.UP * shot_origin_height,
		shot_direction.normalized(),
		&"none",
		self
	)
	damage_info.damage_type = &"bullet"
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
	var shot_origin := global_position + Vector3.UP * shot_origin_height
	var target_position := combat_target.global_position + Vector3.UP * shot_target_height
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


func _play_shot() -> void:
	pass


func _play_reload() -> void:
	pass


func _is_shot_playing() -> bool:
	return false


func _is_reload_playing() -> bool:
	return false


func _play_shot_audio() -> void:
	pass


func _on_reload_finished() -> void:
	if not is_dead and is_reloading:
		reload_completed = true

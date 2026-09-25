class_name HostileBase
extends "res://scripts/npc-scripts/npc_base.gd"
## Shared walking enemy lifecycle. Weapon behavior belongs in subclasses.

enum State { GUARD, PATROL, COMBAT, SEARCH, KNOCKED_DOWN, DEAD, ELECTRIFIED, FROZEN }
enum NameplateKind { PISTOL, RIFLE, MELEE, SUPER, SNIPER }

# Reserve colors now without adding the unimplemented enemy types.
const NAMEPLATE_COLORS := [
	Color("66e080"), Color("c5b458"), Color("e55d5d"),
	Color("ef9a42"), Color("639df5"),
]
const NAMEPLATE_FONT = preload("res://resources/ui/enemy_nameplate_bold.tres")
const ELECTRIFIED = preload("res://scripts/npc-scripts/hostile_electrified.gd")
var electrified := ELECTRIFIED.new()
const FROST = preload("res://scripts/npc-scripts/hostile_frost.gd")
var frost := FROST.new()

@export_category("Identity and Allegiance")
@export var enemy_type: StringName = &"hostile"
@export var display_name: String = "Hostile"
@export var faction: StringName = &"none"
@export var aggressive_to_player: bool = true
@export var can_grab: bool = true
var is_grabbed: bool = false
var is_thrown: bool = false
## Optional encounter surface restriction. Ordinary city enemies leave this null.
var required_walk_surface: CollisionObject3D
@export_category("Overhead Name")
@export var nameplate_text: String = ""
@export var nameplate_kind: NameplateKind = NameplateKind.PISTOL
@export var nameplate_height: float = 2.85
@export_category("Awareness and Movement")
@export var sight_origin_height: float = 1.4
@export var sight_target_height: float = 0.8
@export var guard_detection_radius: float = 17.0
@export var aggro_range: float = 60.0
@export var alert_radius: float = 25.0
@export var alert_indicator_duration: float = 1.5
@export_range(0.0, 5.0, 0.05) var min_combat_action_delay: float = 0.2
@export_range(0.0, 5.0, 0.05) var max_combat_action_delay: float = 1.5
@export_range(1, 20, 1) var relocation_candidate_attempts: int = 8
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
var combat_action_delay_remaining: float = 0.0
var last_known_target_position: Vector3 = Vector3.ZERO
var has_last_known_target_position: bool = false
var search_destination: Vector3 = Vector3.ZERO
var has_search_destination: bool = false
var obstacle_avoidance := CharacterObstacleAvoidance.new()
var debug_physics_usec: int = 0
var debug_physics_peak_usec: int = 0
var debug_ground_query_usec: int = 0
var nameplate: Label3D
var _debug_meshes: Array[MeshInstance3D] = []
var _original_overlays: Array[Material] = []
var _debug_tint: StandardMaterial3D
@onready var alert_indicator: Label3D = get_node_or_null("AlertIndicator")
@onready var alert_indicator_timer: Timer = get_node_or_null("AlertIndicatorTimer")


func _ready() -> void:
	super()
	add_to_group(&"hostile")
	_create_nameplate()
	_setup_debug_visuals()
	obstacle_avoidance.configure(
		obstacle_look_ahead_distance,
		obstacle_emergency_distance,
		obstacle_probe_radius,
		obstacle_probe_height,
		obstacle_turn_angle_degrees,
		obstacle_turn_commit_duration,
		obstacle_collision_mask
	)
	if alert_indicator != null:
		alert_indicator.hide()
	if alert_indicator_timer != null:
		alert_indicator_timer.timeout.connect(_on_alert_indicator_timer_timeout)



func _physics_process(delta: float) -> void:
	if is_grabbed or is_thrown: return
	frost.update(delta)
	if frost.frozen: return
	if electrified.active:
		electrified.update(delta)
		return
	if is_dead:
		_settle_corpse(delta)
		return
	if not OS.is_debug_build():
		super(delta)
		return
	var started := Time.get_ticks_usec()
	super(delta)
	var elapsed := Time.get_ticks_usec() - started
	debug_physics_usec += elapsed
	debug_physics_peak_usec = maxi(debug_physics_peak_usec, elapsed)


func apply_damage(damage_info) -> bool:
	if frost.frozen and damage_info != null and damage_info.amount > 0.0:
		if damage_info.source is PlayerCharacter and damage_info.damage_type == &"melee": frost.melee_hit()
		if frost.frozen: return health_component.apply_damage(damage_info)
	if electrified.active and damage_info != null and damage_info.amount > 0.0:
		if damage_info.source is PlayerCharacter:
			electrified.cancel()
		else:
			# Other damage may kill the victim but cannot replace the frozen pose.
			return health_component.apply_damage(damage_info)
	return super(damage_info)


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
	_keep_on_walk_surface(delta)


func _keep_on_walk_surface(delta: float) -> void:
	if not is_instance_valid(required_walk_surface): return
	var movement := Vector3(velocity.x,0,velocity.z)
	if movement.is_zero_approx(): return
	var next := global_position + movement * delta + movement.normalized() * 0.9
	var ray := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 0.6, next - Vector3.UP * 1.2, obstacle_collision_mask, [get_rid()])
	var ground := get_world_3d().direct_space_state.intersect_ray(ray)
	if ground.is_empty() or ground.collider != required_walk_surface or ground.normal.y < 0.7:
		velocity.x = 0.0
		velocity.z = 0.0


func _settle_corpse(delta: float) -> void:
	# Use a ground ray after removing the standing capsule, including air kills.
	velocity += get_gravity() * delta
	var destination := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.05, destination, obstacle_collision_mask,
		_get_relocation_exclusions()
	)
	var ground := get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		global_position = ground.position
		velocity = Vector3.ZERO
		set_physics_process(false)
	else:
		global_position = destination


func _on_died() -> void:
	frost.cancel()
	electrified.cancel()
	current_state = State.DEAD
	_reset_combat_actions()
	# The death animation remains active without an obstructing capsule.
	velocity = Vector3.ZERO
	set_physics_process(true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for child in get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			child.set_deferred("disabled", true)
	if nameplate != null:
		nameplate.hide()
	if alert_indicator != null:
		alert_indicator.hide()
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player != null:
		player.stats.add_experience(maxi(experience_gain, 0))


func _create_nameplate() -> void:
	nameplate = Label3D.new()
	nameplate.name = "EnemyName"
	nameplate.text = nameplate_text if not nameplate_text.is_empty() else display_name
	nameplate.font = NAMEPLATE_FONT
	nameplate.font_size = 64
	nameplate.outline_size = 12
	nameplate.outline_modulate = Color(0.04, 0.04, 0.04, 1.0)
	nameplate.modulate = NAMEPLATE_COLORS[nameplate_kind]
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.position.y = nameplate_height
	add_child(nameplate)


func _setup_debug_visuals() -> void:
	if OS.is_debug_build():
		for node in find_children("*", "MeshInstance3D", true, false):
			_debug_meshes.append(node)
			_original_overlays.append(node.material_overlay)
		_debug_tint = StandardMaterial3D.new()
		_debug_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var tint: Color = NAMEPLATE_COLORS[nameplate_kind]
		tint.a = 0.75
		_debug_tint.albedo_color = tint
	var manager := get_node_or_null("/root/DebugManager")
	if manager != null:
		manager.enemy_debug_visuals_changed.connect(_update_debug_visuals)
	_update_debug_visuals()


func _update_debug_visuals() -> void:
	var manager := get_node_or_null("/root/DebugManager")
	var debug_enabled := OS.is_debug_build() and manager != null
	nameplate.visible = debug_enabled and manager.show_enemy_names and not is_dead
	for index in _debug_meshes.size():
		if is_instance_valid(_debug_meshes[index]):
			_debug_meshes[index].material_overlay = _debug_tint if debug_enabled and manager.show_enemy_tints else _original_overlays[index]


func _handle_guard() -> void:
	_hold_position()
	var player := _get_player()
	if not aggressive_to_player or not _can_target(player):
		return

	var offset_to_player := player.global_position - global_position
	offset_to_player.y = 0.0
	if offset_to_player.length_squared() <= guard_detection_radius * guard_detection_radius and _can_see_target(player):
		_alert_nearby_hostiles(player)


func receive_alert(target: Node3D) -> void:
	if is_dead or electrified.active or not _can_target(target):
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
		_reset_combat_actions()
		_hold_position()
		if alert_indicator != null:
			alert_indicator.show()
		if alert_indicator_timer != null:
			alert_indicator_timer.start(alert_indicator_duration)


func _alert_nearby_hostiles(target: Node3D) -> void:
	for hostile_node in get_tree().get_nodes_in_group(&"hostile"):
		var nearby_hostile := hostile_node as HostileBase
		if nearby_hostile == null or not is_allied_with(nearby_hostile):
			continue

		var offset_to_hostile := nearby_hostile.global_position - global_position
		offset_to_hostile.y = 0.0
		if offset_to_hostile.length_squared() > alert_radius * alert_radius:
			continue
		nearby_hostile.receive_alert(target)


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _handle_combat(delta: float) -> void:
	if not _can_target(combat_target):
		combat_target = null
		current_state = State.GUARD
		combat_action_delay_remaining = 0.0
		has_last_known_target_position = false
		has_search_destination = false
		_reset_combat_actions()
		_hold_position()
		return

	if global_position.distance_to(combat_target.global_position) > aggro_range:
		_enter_search()
		return
	if _can_see_target(combat_target):
		_remember_target_position()

	velocity.x = 0.0
	velocity.z = 0.0
	if combat_action_delay_remaining > 0.0:
		combat_action_delay_remaining = maxf(combat_action_delay_remaining - delta, 0.0)
		_hold_position()
		return

	_face_combat_target()
	_update_combat(delta)


func _face_combat_target() -> void:
	var direction_to_target := combat_target.global_position - global_position
	direction_to_target.y = 0.0
	if direction_to_target.length_squared() > 0.01:
		look_at(global_position + direction_to_target, Vector3.UP)

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
	var started := Time.get_ticks_usec() if OS.is_debug_build() else 0

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
	if OS.is_debug_build():
		debug_ground_query_usec += Time.get_ticks_usec() - started


func _enter_search() -> void:
	current_state = State.SEARCH
	_reset_combat_actions()
	combat_action_delay_remaining = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_choose_search_destination()


func _handle_search(delta: float) -> void:
	if not _can_target(combat_target):
		combat_target = null
		current_state = State.GUARD
		combat_action_delay_remaining = 0.0
		_reset_combat_actions()
		has_last_known_target_position = false
		has_search_destination = false
		_hold_position()
		return

	if global_position.distance_to(combat_target.global_position) <= aggro_range and _can_see_target(combat_target):
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


func _hold_position() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	animation_controller.call("set_is_idle")


func _on_alert_indicator_timer_timeout() -> void:
	if alert_indicator != null:
		alert_indicator.hide()


func is_allied_with(other: HostileBase) -> bool:
	return other == self or (faction != &"none" and faction == other.faction)


func _can_target(target: Variant) -> bool:
	# A freed Node3D fails typed argument validation before the function runs.
	# Accept Variant so this lifetime check also handles deleted damage sources.
	if not is_instance_valid(target) or not target is Node3D:
		return false
	if target == self or target.is_queued_for_deletion():
		return false
	if target is NPCBase and target.is_dead:
		return false
	if target is PlayerCharacter and target.is_dead:
		return false
	return not (target is HostileBase and is_allied_with(target))


func _can_see_target(target: Variant) -> bool:
	if not _can_target(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * sight_origin_height,
		target.global_position + Vector3.UP * sight_target_height
	)
	query.exclude = [get_rid()]
	query.collision_mask = obstacle_collision_mask
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == target


func _on_damage_received(damage_info) -> void:
	var attacker = damage_info.source
	if _can_target(attacker):
		receive_alert(attacker)
		_alert_nearby_hostiles(attacker)


func _update_combat(_delta: float) -> void:
	_hold_position()


func _reset_combat_actions() -> void:
	pass

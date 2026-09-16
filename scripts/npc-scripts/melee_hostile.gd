class_name MeleeHostile
extends "res://scripts/npc-scripts/hostile_base.gd"

const COORDINATOR = preload("res://scripts/npc-scripts/melee_attack_coordinator.gd")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
enum MeleeState { SURROUND, APPROACH, ATTACK }

@export_category("Melee Combat")
@export var approach_speed: float = 8.5
@export var approach_start_range: float = 25.0
@export var approach_timeout: float = 4.0
@export var attack_range: float = 2.2
@export var attack_height_tolerance: float = 2.0
@export var punch_damage: float = 10.0
@export var punch_hit_delay: float = 0.2
@export_range(0.1, 2.0, 0.05) var punch_animation_speed: float = 1.0
@export_range(1.0, 180.0, 1.0) var punch_arc_degrees: float = 100.0
@export_range(1, 12, 1) var min_combo_punches: int = 6
@export_range(1, 12, 1) var max_combo_punches: int = 6
@export var combo_recovery_time: float = 2.5
@export var punch_animation_timeout: float = 2.0
@export_category("Surround")
@export var surround_radius: float = 9.0
@export var surround_speed: float = 3.5
@export var surround_spacing: float = 1.8
@export var surround_arrival_distance: float = 0.5

var melee_state: MeleeState = MeleeState.SURROUND
var has_attack_slot: bool = false
var combo_length: int = 0
var punches_started: int = 0
var punch_elapsed: float = 0.0
var punch_resolved: bool = false
var recovery_remaining: float = 0.0
var approach_remaining: float = 0.0
var _coordinator: Node

func _ready() -> void:
	super()
	add_to_group(&"melee_hostile")

func wants_exclusive_melee_turn() -> bool:
	return false

func receive_alert(target: Node3D) -> void:
	if _can_target(target) and target != combat_target:
		_reset_combat_actions()
	super(target)

func _exit_tree() -> void:
	_release_slot()

func _on_damage_received(damage_info) -> void:
	super(damage_info)
	_reset_combat_actions()

func _reset_combat_actions() -> void:
	_release_slot()
	melee_state = MeleeState.SURROUND
	combo_length = 0
	punches_started = 0
	punch_elapsed = 0.0
	punch_resolved = true
	recovery_remaining = combo_recovery_time

func _release_slot() -> void:
	if is_instance_valid(_coordinator):
		_coordinator.release(self)
	has_attack_slot = false
	_coordinator = null

func _get_coordinator() -> Node:
	if not is_instance_valid(_coordinator):
		_coordinator = combat_target.get_node_or_null("MeleeAttackCoordinator")
		if _coordinator == null:
			_coordinator = COORDINATOR.new()
			_coordinator.name = "MeleeAttackCoordinator"
			combat_target.add_child(_coordinator)
	return _coordinator

func _face_combat_target() -> void:
	# Commit facing during each swing, allowing sidesteps to evade it.
	if melee_state != MeleeState.ATTACK:
		super()

func _update_combat(delta: float) -> void:
	recovery_remaining = maxf(recovery_remaining - delta, 0.0)
	if melee_state == MeleeState.ATTACK:
		_update_attack(delta)
		return
	var reachable := absf(combat_target.global_position.y - global_position.y) <= attack_height_tolerance
	if not reachable or _get_horizontal_distance_to_target() > approach_start_range:
		_release_slot()
		melee_state = MeleeState.SURROUND
	elif not has_attack_slot and recovery_remaining <= 0.0 and _can_see_target(combat_target):
		has_attack_slot = _get_coordinator().request_slot(self)
		if has_attack_slot:
			melee_state = MeleeState.APPROACH
			approach_remaining = approach_timeout
	elif not has_attack_slot:
		# A waiter behind cover/on cooldown must not block the eligible queue.
		_release_slot()
	if has_attack_slot:
		approach_remaining -= delta
		if approach_remaining <= 0.0:
			_reset_combat_actions()
		elif _in_punch_range() and _can_see_target(combat_target):
			_start_combo()
			return
		else:
			_move_toward_point(combat_target.global_position, approach_speed, delta)
			return
	_move_toward_point(_surround_waypoint(_surround_destination()), surround_speed, delta)

func _surround_destination() -> Vector3:
	var peers: Array[Node3D] = []
	for enemy in get_tree().get_nodes_in_group(&"melee_hostile"):
		if not enemy.is_dead and enemy.combat_target == combat_target:
			peers.append(enemy)
	var index := maxi(peers.find(self), 0)
	var count := maxi(peers.size(), 1)
	var radius := maxf(surround_radius, count * surround_spacing / TAU)
	var angle := TAU * float(index) / float(count)
	return combat_target.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)

func _surround_waypoint(destination: Vector3) -> Vector3:
	var center := combat_target.global_position
	var radial := global_position - center
	radial.y = 0.0
	var safe_radius := maxf(attack_range + 1.0, surround_radius * 0.75)
	if radial.length_squared() < 0.001:
		radial = global_basis.z
	if radial.length() < safe_radius:
		return center + radial.normalized() * safe_radius
	var goal := destination - center
	goal.y = 0.0
	var segment := goal - radial
	var weight := clampf(-radial.dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	if (radial + segment * weight).length() < safe_radius:
		var angle := radial.signed_angle_to(goal, Vector3.UP)
		return center + radial.normalized().rotated(Vector3.UP, signf(angle) * 0.45) * maxf(radial.length(), surround_radius)
	return destination

func _move_toward_point(destination: Vector3, speed: float, delta: float) -> void:
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() <= surround_arrival_distance:
		_hold_position()
		return
	var direction := obstacle_avoidance.get_steered_direction(self, offset, delta)
	# Probe the next ground step rather than walking blindly over roof edges.
	var step := global_position + direction * maxf(speed * delta, 0.6)
	var ground := _get_grounded_relocation_position(step, _get_relocation_exclusions())
	if ground.is_empty():
		_hold_position()
		return
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)
	animation_controller.set_is_running()

func _in_punch_range() -> bool:
	return _get_horizontal_distance_to_target() <= attack_range and absf(combat_target.global_position.y - global_position.y) <= attack_height_tolerance

func _start_combo() -> void:
	combo_length = randi_range(mini(min_combo_punches, max_combo_punches), maxi(min_combo_punches, max_combo_punches))
	punches_started = 0
	melee_state = MeleeState.ATTACK
	_start_punch()

func _start_punch() -> void:
	super._face_combat_target()
	velocity.x = 0.0
	velocity.z = 0.0
	punch_elapsed = 0.0
	punch_resolved = false
	animation_controller.play_melee_punch(punches_started, punch_animation_speed)
	punches_started += 1

func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	punch_elapsed += delta
	if not punch_resolved and punch_elapsed >= punch_hit_delay:
		punch_resolved = true
		_try_punch_hit()
	if animation_controller.is_melee_punch_playing() and punch_elapsed < punch_animation_timeout:
		return
	if punches_started < combo_length and _in_punch_range() and _can_see_target(combat_target):
		_start_punch()
	else:
		_reset_combat_actions()
		_hold_position()

func _try_punch_hit() -> bool:
	if not has_attack_slot or not _can_target(combat_target) or not _in_punch_range() or not _can_see_target(combat_target):
		return false
	var offset := combat_target.global_position - global_position
	offset.y = 0.0
	var forward := -global_basis.z
	if offset.length_squared() > 0.001 and forward.dot(offset.normalized()) < cos(deg_to_rad(punch_arc_degrees * 0.5)):
		return false
	if not combat_target.has_method("apply_damage"):
		return false
	var damage = DAMAGE.new(punch_damage, global_position + Vector3.UP, forward, &"chest", self)
	damage.damage_type = &"melee"
	return combat_target.apply_damage(damage)

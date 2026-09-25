class_name PlayerElectricity
extends Node3D
## Electricity core: a held, single-target shock with shared Heat.
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const ARC = preload("res://effects/electric_arc.gd")
const ELECTRIFIED_EFFECT = preload("res://effects/electrified.tscn")
@export var damage_per_second := 30.0
@export var shock_range := 30.0
@export var heat_per_second := 20.0
@export var palm_offset := Vector3(0.0, 0.035, 0.0)
@export_category("Reactive Shock")
@export_range(0.0, 1.0, 0.01) var reactive_chance := 0.2
@export_range(0.0, 1.0, 0.01) var reactive_super_chance := 0.05
@export var reactive_duration := 2.5
@export var reactive_tick_damage := 15.0
@export var reactive_end_damage := 10.0
var firing := false
var last_hit: Dictionary = {}
var _hand_bone := -1
var _target := Vector3.ZERO
var _arc: Node3D
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	_arc = ARC.new()
	add_child(_arc)
	# Instantiate hidden during player loading so Forward+ sees the effect's
	# mesh/material pipelines before the first reactive hit.
	var preparation := ELECTRIFIED_EFFECT.instantiate()
	preparation.name = "ElectrifiedPreparation"
	add_child(preparation)
	player.ready.connect(_setup, CONNECT_ONE_SHOT)
	process_priority = 11

func _setup() -> void:
	var skeleton := player.laser_eyes._skeleton
	if is_instance_valid(skeleton): _hand_bone = skeleton.find_bone("RightHand")
	player.damage_receiver.damage_received.connect(_on_damage_received)

func reactive_hit_chance(attacker: Node3D) -> float:
	return reactive_super_chance if attacker is SuperHostile else reactive_chance

func _on_damage_received(info) -> void:
	if player.is_dead or info.damage_type != &"melee": return
	if player.get_node("PlayerPowerController").active_power != PlayerAbilities.ELECTRICITY: return
	if player.get_node("PlayerPowerController").progression.level("electricity") < 1: return
	var attacker = info.source
	if not is_instance_valid(attacker) or not attacker is MeleeHostile or attacker.is_dead: return
	if randf() >= reactive_hit_chance(attacker): return
	attacker.electrified.begin(attacker, player, reactive_duration, reactive_tick_damage, reactive_end_damage)

func hand_position() -> Vector3:
	var skeleton := player.laser_eyes._skeleton
	if is_instance_valid(skeleton) and _hand_bone >= 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(_hand_bone) * palm_offset
	return player.global_position + Vector3.UP * 0.3 + player.global_basis.x * 0.4

func cancel() -> void:
	firing = false
	last_hit = {}
	if is_instance_valid(_arc): _arc.hide()

func update_attack(delta: float, input: PlayerInputSnapshot, allowed: bool, heat_available: float) -> float:
	if not allowed or not input.activate_power_pressed:
		cancel()
		return 0.0
	firing = true
	var duration := minf(delta, heat_available / maxf(heat_per_second, 0.001))
	var camera := player.camera
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var camera_origin := camera.project_ray_origin(center)
	var aim := camera_origin + camera.project_ray_normal(center) * (shock_range + camera_origin.distance_to(hand_position()))
	var camera_hit := player.laser_eyes._raycast(camera_origin, aim)
	if not camera_hit.is_empty(): aim = camera_hit.position
	var origin := hand_position()
	var direction := (aim - origin).normalized()
	var endpoint := origin + direction * minf(shock_range, origin.distance_to(aim) + 0.05)
	# The hand-to-target ray prevents the third-person camera from bypassing cover.
	last_hit = player.laser_eyes._raycast(origin, endpoint)
	_target = last_hit.position if not last_hit.is_empty() else endpoint
	if not last_hit.is_empty():
		var body: Object = last_hit.collider
		if is_instance_valid(body) and body.has_method("apply_damage"):
			var info = DAMAGE.new(damage_per_second * duration, origin, direction, &"none", player)
			info.damage_type = &"electricity"
			body.call("apply_damage", info)
	_arc.draw_arc(origin, _target, camera.global_position, not last_hit.is_empty(), 0.0)
	return heat_per_second * duration

func _process(delta: float) -> void:
	if not firing: return
	if player.is_dead or player.is_knocked_out:
		cancel()
		return
	_arc.draw_arc(hand_position(), _target, player.camera.global_position, not last_hit.is_empty(), delta)

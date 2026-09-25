class_name PlayerFrost
extends Node3D
const BREATH = preload("res://effects/frost_breath.gd")
const ICE = preload("res://effects/frozen_ice.gd")
@export var damage_per_second := 5.0
@export var heat_per_second := 15.0
@export var freeze_seconds := 3.0
@export var super_freeze_seconds := 5.0
@export var thaw_rate := 1.0
@export var frozen_seconds := 5.0
@export var frozen_damage_per_second := 10.0
@export_range(0.05, 1.0, 0.05) var minimum_action_speed := 0.15
var firing := false
var _breath: Node3D
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	_breath = BREATH.new()
	add_child(_breath)
	var preparation := ICE.new()
	preparation.name = "IcePreparation"
	add_child(preparation)
	process_priority = 11

func cancel() -> void:
	firing = false
	if is_instance_valid(_breath): _breath.stop()

func update_attack(delta: float, input: PlayerInputSnapshot, allowed: bool, heat_available: float) -> float:
	if not allowed or not input.activate_power_pressed:
		cancel()
		return 0.0
	firing = true
	_position_breath()
	var duration := minf(delta, heat_available / maxf(heat_per_second, 0.001))
	_breath.apply_frost(duration, player, self)
	return duration * heat_per_second

func _position_breath() -> void:
	# One set of cone dimensions in PlayerFire keeps both breaths in sync.
	var fire: PlayerFire = player.get_node("PlayerFire")
	var eyes := player.laser_eyes.eye_positions()
	var mouth := (eyes[0] + eyes[1]) * 0.5
	var head_basis := player.superhero_character.global_basis
	if is_instance_valid(player.laser_eyes._skeleton):
		head_basis = player.laser_eyes._skeleton.global_basis * player.laser_eyes._skeleton.get_bone_global_pose(player.laser_eyes._head_bone).basis
	mouth -= head_basis.y.normalized() * 0.045
	var direction := (fire._aim_target() - mouth).normalized()
	var endpoint := mouth + direction * fire.breath_range
	var excluded: Array[RID] = [player.get_rid()]
	for enemy in get_tree().get_nodes_in_group(&"hostile"):
		if enemy is CollisionObject3D: excluded.append(enemy.get_rid())
	for aircraft in get_tree().get_nodes_in_group(&"attack_helicopter"):
		if aircraft is CollisionObject3D: excluded.append(aircraft.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(mouth, endpoint, 1, excluded)
	ray.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): endpoint = hit.position
	_breath.set_stream(mouth, endpoint, fire.breath_end_radius / maxf(fire.breath_range, 0.01))

func _process(_delta: float) -> void:
	if player.is_dead or player.is_knocked_out:
		cancel()
		return
	if firing: _position_breath()

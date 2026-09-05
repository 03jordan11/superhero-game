class_name PlayerLandingImpactController
extends Node

## Owns landing classification, camera feedback, area damage, and impact effects.

const HARD_LANDING_EFFECT_SCENE: PackedScene = preload(
	"res://effects/hard_landing_effect.tscn"
)
const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")

signal landing_classified(category: String)

@export var heavy_landing_speed: float = 20.0
@export var super_landing_speed: float = 35.0
@export var landing_impact_radius: float = 5.0
@export var heavy_landing_damage: float = 10.0
@export var super_landing_damage: float = 50.0
@export var heavy_landing_vehicle_damage: float = 50.0
@export var super_landing_vehicle_damage: float = 100.0

var player: CharacterBody3D
var camera_effects: Node
var max_downward_speed: float = 0.0
var was_airborne: bool = false
var max_effect_downward_speed: float = 0.0
var was_on_floor: bool = false


func initialize(
	target_player: CharacterBody3D,
	target_camera_effects: Node
) -> void:
	player = target_player
	camera_effects = target_camera_effects
	was_on_floor = player.is_on_floor()


func observe_normal_airborne(vertical_speed: float) -> void:
	was_airborne = true
	max_downward_speed = maxf(max_downward_speed, -vertical_speed)


func observe_before_move(is_grounded: bool, vertical_speed: float) -> void:
	if not is_grounded:
		max_effect_downward_speed = maxf(
			max_effect_downward_speed,
			-vertical_speed
		)


func resolve_normal_landing() -> void:
	var landing_category := "Normal"
	if max_downward_speed >= super_landing_speed:
		landing_category = "Super"
	elif max_downward_speed >= heavy_landing_speed:
		landing_category = "Heavy"

	landing_classified.emit(landing_category)
	print("Landing impact: %s" % landing_category)
	max_downward_speed = 0.0
	was_airborne = false


func reset_normal_landing_tracking() -> void:
	max_downward_speed = 0.0
	was_airborne = false


func update_after_move(
	is_grounded: bool,
	ground_slam_pending: bool,
	ground_slam_speed: float,
	speed_attribute_multiplier: float
) -> bool:
	if is_grounded and not was_on_floor:
		var landing_speed := max_effect_downward_speed
		if ground_slam_pending:
			landing_speed = maxf(
				landing_speed,
				ground_slam_speed * speed_attribute_multiplier
			)

		camera_effects.call("trigger_landing", landing_speed)
		if landing_speed >= heavy_landing_speed:
			var ground_contact := _get_ground_contact()
			spawn_hard_landing_effect(
				landing_speed,
				ground_contact.position,
				ground_contact.normal,
				&"ground_slam" if ground_slam_pending else &"knockback"
			)
		ground_slam_pending = false
		max_effect_downward_speed = 0.0
	elif is_grounded:
		max_effect_downward_speed = 0.0

	was_on_floor = is_grounded
	return ground_slam_pending


func spawn_hard_landing_effect(
	impact_speed: float,
	spawn_position: Vector3,
	surface_normal: Vector3,
	hit_reaction: StringName = &"knockback"
) -> void:
	_apply_landing_impact_damage(spawn_position, impact_speed, hit_reaction)
	var effect := HARD_LANDING_EFFECT_SCENE.instantiate()
	effect.call(
		"configure_impact",
		impact_speed,
		heavy_landing_speed,
		super_landing_speed,
		surface_normal
	)
	player.get_tree().current_scene.add_child(effect)
	effect.global_position = spawn_position


func _apply_landing_impact_damage(
	impact_position: Vector3,
	impact_speed: float,
	hit_reaction: StringName
) -> void:
	var impact_shape := SphereShape3D.new()
	impact_shape.radius = landing_impact_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = impact_shape
	query.transform = Transform3D(Basis.IDENTITY, impact_position)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit_results: Array[Dictionary] = (
		player.get_world_3d().direct_space_state.intersect_shape(query)
	)
	var hit_instance_ids: Dictionary = {}
	var damage_percent := clampf(
		inverse_lerp(heavy_landing_speed, super_landing_speed, impact_speed),
		0.0,
		1.0
	)
	var damage := lerpf(heavy_landing_damage, super_landing_damage, damage_percent)
	var vehicle_damage: float = (
		super_landing_vehicle_damage
		if impact_speed >= super_landing_speed or hit_reaction == &"ground_slam"
		else heavy_landing_vehicle_damage
	)
	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if collider == null or not collider.has_method("apply_damage"):
			continue
		var collider_id := collider.get_instance_id()
		if hit_instance_ids.has(collider_id):
			continue
		hit_instance_ids[collider_id] = true
		var is_explodable: bool = (
			collider is Node and (collider as Node).is_in_group(&"explodable")
		)
		var damage_amount: float = vehicle_damage if is_explodable else damage
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			damage_amount,
			impact_position,
			Vector3.ZERO,
			hit_reaction,
			player,
			impact_speed
		)
		collider.call("apply_damage", damage_info)


func _get_ground_contact() -> Dictionary:
	var ray_origin := player.global_position + Vector3.UP
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + Vector3.DOWN * 5.0
	)
	ray_query.exclude = [player.get_rid()]
	var ground_hit: Dictionary = (
		player.get_world_3d().direct_space_state.intersect_ray(ray_query)
	)
	if not ground_hit.is_empty():
		return ground_hit
	return {
		"position": player.global_position,
		"normal": Vector3.UP,
	}

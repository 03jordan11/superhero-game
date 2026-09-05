class_name ExplosionController
extends Node3D

const DEFAULT_EFFECT_SCENE: PackedScene = preload("res://effects/vehicle_explosion_effect.tscn")
const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")

@export_category("Explosion")
@export var effect_scene: PackedScene = DEFAULT_EFFECT_SCENE
@export var minimum_impact_speed: float = 18.0
@export var radius: float = 5.0
@export var minimum_damage: float = 50.0
@export var maximum_damage: float = 100.0
@export var explodable_damage: float = 100.0
@export var maximum_damage_speed: float = 75.0


func _ready() -> void:
	add_to_group(&"explosion_controller")
	call_deferred("_register_existing_explodables")


func register_explodable(explodable: Node3D) -> void:
	if not explodable.has_signal(&"destroyed"):
		return

	var destroyed_callback := Callable(self, "_on_explodable_destroyed").bind(explodable)
	if not explodable.is_connected(&"destroyed", destroyed_callback):
		explodable.connect(&"destroyed", destroyed_callback)


func explode(
	explosion_position: Vector3,
	impact_speed: float,
	source: CollisionObject3D = null
) -> void:
	var resolved_impact_speed: float = maxf(impact_speed, minimum_impact_speed)
	_apply_radius_damage(explosion_position, resolved_impact_speed, source)
	_spawn_effect(explosion_position, resolved_impact_speed)
	if source != null and is_instance_valid(source):
		source.queue_free()


func _register_existing_explodables() -> void:
	for node in get_tree().get_nodes_in_group(&"explodable"):
		if node is Node3D:
			register_explodable(node as Node3D)


func _on_explodable_destroyed(impact_speed: float, explodable: Node3D) -> void:
	if not is_instance_valid(explodable):
		return

	var source: CollisionObject3D = explodable as CollisionObject3D
	explode(explodable.global_position, impact_speed, source)


func _apply_radius_damage(
	explosion_position: Vector3,
	impact_speed: float,
	source: CollisionObject3D
) -> void:
	var explosion_shape := SphereShape3D.new()
	explosion_shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = explosion_shape
	query.transform = Transform3D(Basis.IDENTITY, explosion_position)
	if source != null:
		query.exclude = [source.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit_results: Array[Dictionary] = (
		get_world_3d().direct_space_state.intersect_shape(query)
	)
	var hit_instance_ids: Dictionary = {}
	var damage_percent: float = clampf(
		inverse_lerp(minimum_impact_speed, maximum_damage_speed, impact_speed),
		0.0,
		1.0
	)
	var actor_damage: float = lerpf(minimum_damage, maximum_damage, damage_percent)
	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if collider == null:
			continue

		var collider_id: int = collider.get_instance_id()
		if hit_instance_ids.has(collider_id):
			continue
		hit_instance_ids[collider_id] = true

		if not collider.has_method("apply_damage"):
			continue

		var is_explodable: bool = (
			collider is Node and (collider as Node).is_in_group(&"explodable")
		)
		var damage_amount: float = explodable_damage if is_explodable else actor_damage
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			damage_amount,
			explosion_position,
			Vector3.ZERO,
			&"knockback",
			source,
			impact_speed
		)
		collider.call("apply_damage", damage_info)


func _spawn_effect(explosion_position: Vector3, impact_speed: float) -> void:
	if effect_scene == null:
		return

	var effect: Node3D = effect_scene.instantiate() as Node3D
	if effect == null:
		return
	if effect.has_method("configure_impact"):
		effect.call("configure_impact", impact_speed, minimum_impact_speed)
	get_tree().current_scene.add_child(effect)
	effect.global_position = explosion_position

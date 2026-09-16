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


func explode_power(origin: Vector3, damage: float, blast_radius: float, source: CollisionObject3D) -> void:
	# Power bursts exclude their owner, who receives a separate exact health cost.
	_apply_radius_damage(origin, minimum_impact_speed, source, damage, blast_radius)
	_spawn_effect(origin, minimum_impact_speed)


func _on_explodable_destroyed(impact_speed: float, explodable: Node3D) -> void:
	if not is_instance_valid(explodable):
		return

	var source: CollisionObject3D = explodable as CollisionObject3D
	explode(explodable.global_position, impact_speed, source)


func explode_fireball(origin: Vector3, damage: float, blast_radius: float, source: CollisionObject3D, edge_damage := -1.0) -> void:
	_apply_radius_damage(origin, minimum_impact_speed, source, damage, blast_radius, &"fire", edge_damage)
	_spawn_effect(origin, minimum_impact_speed, 0.45 * blast_radius / 3.0, -6.0)


static func radial_damage(center_damage: float, edge_damage: float, distance: float, blast_radius: float) -> float:
	if edge_damage < 0.0: return center_damage
	# Full damage in the inner fifth, then linear falloff to the outer edge.
	var fraction := clampf((distance / maxf(blast_radius, 0.001) - 0.2) / 0.8, 0.0, 1.0)
	return lerpf(center_damage, edge_damage, fraction)


func _apply_radius_damage(
	explosion_position: Vector3,
	impact_speed: float,
	source: CollisionObject3D,
	fixed_damage: float = -1.0,
	custom_radius: float = -1.0,
	damage_type: StringName = &"generic",
	edge_damage: float = -1.0
) -> void:
	var explosion_shape := SphereShape3D.new()
	var blast_radius := custom_radius if custom_radius >= 0.0 else radius
	explosion_shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = explosion_shape
	query.transform = Transform3D(Basis.IDENTITY, explosion_position)
	if source != null:
		query.exclude = [source.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit_results: Array[Dictionary] = (
		get_world_3d().direct_space_state.intersect_shape(query, 256)
	)
	var hit_instance_ids: Dictionary = {}
	var damage_percent: float = clampf(
		inverse_lerp(minimum_impact_speed, maximum_damage_speed, impact_speed),
		0.0,
		1.0
	)
	var actor_damage: float = lerpf(minimum_damage, maximum_damage, damage_percent)
	if fixed_damage >= 0.0: actor_damage = fixed_damage
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
		if fixed_damage >= 0.0: damage_amount = radial_damage(fixed_damage, edge_damage, explosion_position.distance_to((collider as Node3D).global_position), blast_radius)
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			damage_amount,
			explosion_position,
			Vector3.ZERO,
			&"knockback",
			source,
			impact_speed
		)
		damage_info.damage_type = damage_type
		collider.call("apply_damage", damage_info)
	# Distant visual civilians have no physics body to appear in the query.
	var crowd_damage = DAMAGE_INFO_SCRIPT.new(actor_damage,explosion_position,Vector3.ZERO,&"knockback",source,impact_speed)
	crowd_damage.damage_type = damage_type
	get_tree().call_group(&"civilian_capsule_lod",&"apply_radius_damage",explosion_position,blast_radius,crowd_damage,edge_damage)


func _spawn_effect(explosion_position: Vector3, impact_speed: float, size_multiplier := 1.0, volume_offset := 0.0) -> void:
	if effect_scene == null:
		return

	var effect: Node3D = effect_scene.instantiate() as Node3D
	if effect == null:
		return
	if effect.has_method("configure_impact"):
		effect.call("configure_impact", impact_speed, minimum_impact_speed)
	effect.scale *= size_multiplier
	if volume_offset != 0.0 and effect.get("sound_volume_db") != null:
		effect.sound_volume_db += volume_offset
	var world := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world.add_child(effect)
	effect.global_position = explosion_position

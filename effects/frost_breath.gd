extends "res://effects/dragon_breath.gd"
## NPCs build frost; aircraft take only the breath's direct damage.

func _ready() -> void:
	super()
	_flame.material_override.shader = preload("res://effects/frost_breath.gdshader")
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.5, 0.85, 1.0, 0.6))
	gradient.set_color(1, Color(0.9, 1.0, 1.0, 0.0))
	_particles.process_material.color_ramp.gradient = gradient
	_particles.draw_pass_1.material.emission = Color(0.25, 0.65, 1.0)
	_light.light_color = Color(0.4, 0.75, 1.0)

func apply_frost(seconds: float, source: PlayerCharacter, tuning: Node) -> void:
	if length < 0.02 or seconds <= 0.0: return
	var enemies := get_tree().get_nodes_in_group(&"hostile") + get_tree().get_nodes_in_group(&"attack_helicopter")
	var excluded: Array[RID] = [source.get_rid()]
	for enemy in enemies:
		if enemy is CollisionObject3D: excluded.append(enemy.get_rid())
	for enemy in enemies:
		if enemy.is_dead: continue
		if enemy is HostileBase and (enemy.is_grabbed or enemy.is_thrown): continue
		var center: Vector3 = enemy.global_position + Vector3.UP
		var collisions := enemy.find_children("*", "CollisionShape3D", true, false)
		if not collisions.is_empty(): center = collisions[0].global_position
		if enemy.has_method("get_damage_center"):
			center = enemy.get_damage_center()
			var hull_excluded: Array[RID] = excluded.duplicate()
			hull_excluded.erase(enemy.get_rid())
			var hull_ray := PhysicsRayQueryParameters3D.create(global_position, center, 1, hull_excluded)
			hull_ray.hit_from_inside = true
			var hull_hit := get_world_3d().direct_space_state.intersect_ray(hull_ray)
			if hull_hit.is_empty() or hull_hit.collider != enemy: continue
			center = hull_hit.position
		var offset := center - global_position
		var depth := offset.dot(direction)
		if depth < 0.0 or depth > length + 0.5: continue
		if (offset - direction * depth).length() > depth * spread + 0.5: continue
		var ray := PhysicsRayQueryParameters3D.create(global_position, center, 1, excluded)
		ray.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if enemy is HostileBase:
			enemy.frost.receive(enemy, source, seconds, tuning)
		else:
			var info = DAMAGE.new(tuning.damage_per_second * seconds, global_position, direction, &"none", source)
			info.damage_type = &"frost_breath"
			enemy.apply_damage(info)

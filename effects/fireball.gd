extends Node3D
## Swept collision avoids tunneling even at low frame rates. No persistent fire.
var source: PlayerCharacter
var velocity := Vector3.FORWARD * 50.0
var damage := 40.0
var blast_radius := 3.0
var edge_damage := -1.0
var visual_scale := 1.0
var lifetime := 6.0
var _spent := false
var _age := 0.0
var _core: MeshInstance3D
var _trail: GPUParticles3D

func _ready() -> void:
	add_to_group(&"fireball_projectiles")
	_core = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22 * visual_scale
	mesh.height = 0.44 * visual_scale
	mesh.radial_segments = 12
	mesh.rings = 6
	_core.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.65, 0.12)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.025)
	material.emission_energy_multiplier = 6.0
	var core_material := ShaderMaterial.new()
	core_material.shader = preload("res://effects/fireball_core.gdshader")
	_core.material_override = core_material
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	# A tapered flame stays readable even between particle simulation updates.
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.26 * visual_scale
	cone.height = 1.3 * visual_scale
	cone.radial_segments = 7
	flame.mesh = cone
	var flame_material: StandardMaterial3D = material.duplicate()
	flame_material.albedo_color = Color(1.0, 0.2, 0.015)
	flame_material.emission_energy_multiplier = 3.0
	flame.material_override = flame_material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var back := -velocity.normalized() if not velocity.is_zero_approx() else Vector3.BACK
	var reference := Vector3.RIGHT if absf(back.y) > 0.98 else Vector3.UP
	var right := back.cross(reference).normalized()
	flame.transform = Transform3D(Basis(right, back, right.cross(back)), back * 0.65 * visual_scale)
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.03)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)
	_build_trail()

func _physics_process(delta: float) -> void:
	if _spent: return
	var travel_time := minf(delta, maxf(0.0, lifetime - _age))
	advance_to(global_position + velocity * travel_time)
	_age += delta
	if _age >= lifetime: queue_free()
	_core.scale = Vector3.ONE * (1.0 + sin(_age * 35.0) * 0.12)

func advance_to(target: Vector3) -> void:
	if _spent or global_position.is_equal_approx(target): return
	var query := PhysicsRayQueryParameters3D.create(global_position, target)
	if is_instance_valid(source): query.exclude = [source.get_rid()]
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if not hit.is_empty() else target
	for crowd in get_tree().get_nodes_in_group(&"civilian_capsule_lod"):
		var crowd_hit: Dictionary = crowd.intersect_damage_ray(global_position, end)
		if not crowd_hit.is_empty():
			hit = crowd_hit
			end = hit.position
	global_position = end
	if not hit.is_empty(): _impact()

func _impact() -> void:
	if _spent: return
	_spent = true
	var explosions := get_tree().get_first_node_in_group(&"explosion_controller") as ExplosionController
	if explosions == null:
		explosions = ExplosionController.new()
		get_parent().add_child(explosions)
	var owner_body: CollisionObject3D = source if is_instance_valid(source) else null
	explosions.explode_fireball(global_position, damage, blast_radius, owner_body, edge_damage)
	queue_free()

func _build_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 0.3
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.15
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 1.5
	process.gravity = Vector3(0, 1.5, 0)
	process.scale_min = 0.12 * visual_scale
	process.scale_max = 0.32 * visual_scale
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0.2, 0.9))
	gradient.add_point(0.35, Color(1, 0.2, 0.015, 0.7))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.3, 0.035, 0.005, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	_trail.process_material = process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.5
	particle_mesh.height = 1.0
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(1.0, 0.18, 0.005)
	material.emission_energy_multiplier = 2.0
	particle_mesh.material = material
	_trail.draw_pass_1 = particle_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)

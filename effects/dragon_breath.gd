extends Node3D
## Short cone of fire. Each target receives one damage tick, with cover checks.
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var length := 0.0
var spread := 0.25
var direction := Vector3.FORWARD
var _flame: MeshInstance3D
var _particles: GPUParticles3D
var _light: OmniLight3D
var _query_shape := SphereShape3D.new()

func _ready() -> void:
	_flame = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = 0.035
	mesh.top_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.cap_top = false
	mesh.cap_bottom = false
	_flame.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://effects/dragon_breath.gdshader")
	_flame.material_override = material
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_particles = GPUParticles3D.new()
	_particles.amount = 100
	_particles.lifetime = 0.45
	_particles.local_coords = true
	_particles.visibility_aabb = AABB(Vector3(-16, -16, -16), Vector3(32, 32, 32))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.12
	process.scale_max = 0.45
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.85, 0.25, 0.8))
	gradient.add_point(0.4, Color(1, 0.3, 0.01, 0.65))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.5, 0.035, 0, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	_particles.process_material = process
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2.ONE
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.vertex_color_use_as_albedo = true
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	var soft_flame := GradientTexture2D.new()
	soft_flame.gradient = fade
	soft_flame.fill = GradientTexture2D.FILL_RADIAL
	soft_flame.fill_from = Vector2(0.5, 0.5)
	soft_flame.fill_to = Vector2(0.5, 0.0)
	particle_material.albedo_texture = soft_flame
	particle_material.emission_enabled = true
	particle_material.emission = Color(1, 0.18, 0.01)
	particle_material.emission_energy_multiplier = 2.0
	particle_mesh.material = particle_material
	_particles.draw_pass_1 = particle_mesh
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.24, 0.035)
	_light.light_energy = 2.5
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)
	stop()

func set_stream(origin: Vector3, endpoint: Vector3, cone_spread: float) -> void:
	var was_visible := visible
	global_position = origin
	length = origin.distance_to(endpoint)
	spread = cone_spread
	if length < 0.02:
		stop()
		return
	direction = (endpoint - origin) / length
	var reference := Vector3.RIGHT if absf(direction.y) > 0.98 else Vector3.UP
	var right := direction.cross(reference).normalized()
	global_basis = Basis(right, direction, right.cross(direction))
	_flame.position = Vector3.UP * length * 0.5
	_flame.scale = Vector3(maxf(length * spread, 0.04), length, maxf(length * spread, 0.04))
	var process := _particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = length / _particles.lifetime * 0.75
	process.initial_velocity_max = length / _particles.lifetime
	_light.position = Vector3.UP * minf(length * 0.3, 2.0)
	show()
	_particles.emitting = true
	if not was_visible: _particles.restart()

func stop() -> void:
	hide()
	length = 0.0
	if is_instance_valid(_particles): _particles.emitting = false

func deal_damage(amount: float, source: PlayerCharacter) -> void:
	if length < 0.02 or amount <= 0.0: return
	_query_shape.radius = length + 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _query_shape
	query.transform.origin = global_position
	query.exclude = [source.get_rid()]
	var seen := {}
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 256):
		var body: Node3D = hit.collider
		if not body.has_method("apply_damage") or seen.has(body.get_instance_id()): continue
		seen[body.get_instance_id()] = true
		var center := body.global_position
		var collision := body.find_children("*", "CollisionShape3D", true, false)
		if not collision.is_empty(): center = collision[0].global_position
		damage_target(body, center, amount, source)
	for crowd in get_tree().get_nodes_in_group(&"civilian_capsule_lod"):
		crowd.apply_breath_damage(self, amount, source)

func damage_target(body: Node3D, center: Vector3, amount: float, source: PlayerCharacter) -> bool:
	var offset := center - global_position
	var depth := offset.dot(direction)
	# Small padding includes capsule edges without expanding the cone behind us.
	if depth < 0.0 or depth > length + 0.5: return false
	if (offset - direction * depth).length() > depth * spread + 0.5: return false
	var query := PhysicsRayQueryParameters3D.create(global_position, center)
	query.exclude = [source.get_rid()]
	query.hit_from_inside = true
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty() and obstruction.collider != body: return false
	var info = DAMAGE.new(amount, global_position, direction, &"none", source)
	info.damage_type = &"fire"
	body.apply_damage(info)
	return true

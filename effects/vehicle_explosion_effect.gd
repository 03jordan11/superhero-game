extends Node3D

@export_category("Explosion")
@export var explosion_lifetime: float = 1.4
@export var pulse_duration: float = 0.35
@export var fire_particle_lifetime: float = 0.8
@export var spark_particle_lifetime: float = 1.1

@onready var explosion_pulse: MeshInstance3D = $ExplosionPulse
@onready var explosion_light: OmniLight3D = $ExplosionLight
@onready var fire_particles: GPUParticles3D = $FireParticles
@onready var spark_particles: GPUParticles3D = $SparkParticles

var impact_percent: float = 0.0
var pulse_material: ShaderMaterial


func configure_impact(impact_speed: float, minimum_impact_speed: float) -> void:
	impact_percent = clampf(
		inverse_lerp(minimum_impact_speed, minimum_impact_speed * 2.5, impact_speed),
		0.0,
		1.0
	)


func _ready() -> void:
	call_deferred("_start_effect")


func _start_effect() -> void:
	_configure_explosion_shader()
	_configure_particles()
	explosion_light.light_energy *= lerpf(0.7, 1.4, impact_percent)
	fire_particles.restart()
	spark_particles.restart()
	fire_particles.emitting = true
	spark_particles.emitting = true

	var explosion_tween := create_tween()
	explosion_tween.tween_method(_set_pulse_progress, 0.0, 1.0, pulse_duration)
	explosion_tween.parallel().tween_property(explosion_light, "light_energy", 0.0, pulse_duration)

	await get_tree().create_timer(explosion_lifetime).timeout
	queue_free()


func _configure_explosion_shader() -> void:
	var explosion_shader := Shader.new()
	explosion_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX *= mix(0.65, 5.0, progress);
}

void fragment() {
	float fade = 1.0 - progress;
	ALBEDO = vec3(1.0, 0.18, 0.01);
	EMISSION = vec3(1.0, 0.12, 0.01) * (8.0 * fade);
	ALPHA = fade * 0.85;
}
"""
	pulse_material = ShaderMaterial.new()
	pulse_material.shader = explosion_shader
	explosion_pulse.material_override = pulse_material


func _set_pulse_progress(progress: float) -> void:
	pulse_material.set_shader_parameter("progress", progress)


func _configure_particles() -> void:
	var size_multiplier := lerpf(0.8, 1.5, impact_percent)

	fire_particles.amount = roundi(48 * size_multiplier)
	fire_particles.lifetime = fire_particle_lifetime
	var fire_process_material := ParticleProcessMaterial.new()
	fire_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_process_material.emission_sphere_radius = 0.9 * size_multiplier
	fire_process_material.direction = Vector3.UP
	fire_process_material.spread = 180.0
	fire_process_material.initial_velocity_min = 5.0 * size_multiplier
	fire_process_material.initial_velocity_max = 12.0 * size_multiplier
	fire_process_material.gravity = Vector3(0.0, -5.0, 0.0)
	fire_process_material.scale_min = 0.9 * size_multiplier
	fire_process_material.scale_max = 2.0 * size_multiplier
	fire_process_material.color = Color(1.0, 0.2, 0.02, 0.9)
	fire_particles.process_material = fire_process_material

	var fire_mesh := QuadMesh.new()
	fire_mesh.size = Vector2(1.4, 1.4)
	var fire_material := StandardMaterial3D.new()
	fire_material.albedo_color = Color(1.0, 0.18, 0.01, 0.85)
	fire_material.emission_enabled = true
	fire_material.emission = Color(1.0, 0.08, 0.0)
	fire_material.emission_energy_multiplier = 6.0
	fire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_mesh.material = fire_material
	fire_particles.draw_pass_1 = fire_mesh

	spark_particles.amount = roundi(32 * size_multiplier)
	spark_particles.lifetime = spark_particle_lifetime
	var spark_process_material := ParticleProcessMaterial.new()
	spark_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_process_material.emission_sphere_radius = 0.7 * size_multiplier
	spark_process_material.direction = Vector3.UP
	spark_process_material.spread = 180.0
	spark_process_material.initial_velocity_min = 10.0 * size_multiplier
	spark_process_material.initial_velocity_max = 20.0 * size_multiplier
	spark_process_material.gravity = Vector3(0.0, -22.0, 0.0)
	spark_process_material.scale_min = 0.08
	spark_process_material.scale_max = 0.2
	spark_process_material.color = Color(1.0, 0.75, 0.1, 1.0)
	spark_particles.process_material = spark_process_material

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.08
	spark_mesh.height = 0.16
	var spark_material := StandardMaterial3D.new()
	spark_material.albedo_color = Color(1.0, 0.7, 0.08)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.45, 0.02)
	spark_material.emission_energy_multiplier = 8.0
	spark_mesh.material = spark_material
	spark_particles.draw_pass_1 = spark_mesh

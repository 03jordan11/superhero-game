extends Node3D

@export_category("Impact Scaling")
@export var dust_amount_min: int = 20
@export var dust_amount_max: int = 80
@export var debris_amount_min: int = 4
@export var debris_amount_max: int = 20

@export_category("Dust")
@export var dust_lifetime: float = 0.65
@export var dust_spread: float = 85.0
@export var dust_velocity_min: float = 3.0
@export var dust_velocity_max: float = 9.0
@export var dust_radius: float = 1.8

@export_category("Debris")
@export var debris_lifetime: float = 1.25
@export var debris_spread: float = 55.0
@export var debris_velocity_min: float = 5.0
@export var debris_velocity_max: float = 15.0
@export var debris_radius: float = 1.2

@export_category("Ground Crack Decal")
@export var decal_size_min: float = 4.0
@export var decal_size_max: float = 9.0
@export var decal_projection_depth: float = 0.25
@export var decal_lifetime: float = 8.0

@onready var dust_particles: GPUParticles3D = $DustParticles
@onready var debris_particles: GPUParticles3D = $DebrisParticles
@onready var impact_decal: Decal = $ImpactDecal

var impact_percent: float = 0.0
var surface_normal: Vector3 = Vector3.UP


func configure_impact(
	impact_speed: float,
	hard_landing_speed: float,
	super_landing_speed: float,
	impact_surface_normal: Vector3 = Vector3.UP
) -> void:
	impact_percent = clampf(
		inverse_lerp(hard_landing_speed, maxf(super_landing_speed, hard_landing_speed + 0.01), impact_speed),
		0.0,
		1.0
	)
	surface_normal = impact_surface_normal.normalized()


func _ready() -> void:
	call_deferred("_start_effect")


func _start_effect() -> void:
	_configure_dust()
	_configure_debris()
	_configure_decal()
	dust_particles.restart()
	debris_particles.restart()
	dust_particles.emitting = true
	debris_particles.emitting = true

	await get_tree().create_timer(maxf(maxf(dust_lifetime, debris_lifetime) + 0.25, decal_lifetime)).timeout
	queue_free()


func _configure_decal() -> void:
	var decal_size := lerpf(decal_size_min, decal_size_max, impact_percent)
	impact_decal.size = Vector3(decal_size, decal_projection_depth, decal_size)
	impact_decal.albedo_mix = 0.85
	impact_decal.upper_fade = 0.0
	impact_decal.lower_fade = 0.0

	# Decals project along their local -Y axis. Align local +Y to the impact
	# normal so the projection travels into the surface from the contact point.
	var reference_axis := Vector3.FORWARD
	if abs(surface_normal.dot(reference_axis)) > 0.98:
		reference_axis = Vector3.RIGHT
	var decal_x_axis := reference_axis.cross(surface_normal).normalized()
	var decal_z_axis := decal_x_axis.cross(surface_normal).normalized()
	var decal_transform := impact_decal.global_transform
	decal_transform.basis = Basis(decal_x_axis, surface_normal, decal_z_axis)
	decal_transform.origin = global_position + surface_normal * 0.01
	impact_decal.global_transform = decal_transform


func _configure_dust() -> void:
	dust_particles.amount = roundi(lerpf(dust_amount_min, dust_amount_max, impact_percent))
	dust_particles.lifetime = dust_lifetime

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = dust_radius * lerpf(0.6, 1.0, impact_percent)
	process_material.direction = Vector3.UP
	process_material.spread = dust_spread
	process_material.initial_velocity_min = dust_velocity_min * lerpf(0.7, 1.0, impact_percent)
	process_material.initial_velocity_max = dust_velocity_max * lerpf(0.7, 1.0, impact_percent)
	process_material.gravity = Vector3(0.0, -3.0, 0.0)
	process_material.scale_min = 0.8
	process_material.scale_max = 1.8
	process_material.color = Color(0.45, 0.38, 0.3, 0.55)
	dust_particles.process_material = process_material

	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(1.4, 1.4)
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.45, 0.38, 0.3, 0.5)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mesh.material = dust_material
	dust_particles.draw_pass_1 = dust_mesh


func _configure_debris() -> void:
	debris_particles.amount = roundi(lerpf(debris_amount_min, debris_amount_max, impact_percent))
	debris_particles.lifetime = debris_lifetime

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = debris_radius * lerpf(0.6, 1.0, impact_percent)
	process_material.direction = Vector3.UP
	process_material.spread = debris_spread
	process_material.initial_velocity_min = debris_velocity_min * lerpf(0.7, 1.0, impact_percent)
	process_material.initial_velocity_max = debris_velocity_max * lerpf(0.7, 1.0, impact_percent)
	process_material.gravity = Vector3(0.0, -18.0, 0.0)
	process_material.angular_velocity_min = -540.0
	process_material.angular_velocity_max = 540.0
	process_material.scale_min = 0.35
	process_material.scale_max = 0.8
	process_material.color = Color(0.32, 0.28, 0.24, 1.0)
	debris_particles.process_material = process_material

	var debris_mesh := SphereMesh.new()
	debris_mesh.radius = 0.16
	debris_mesh.height = 0.22
	debris_mesh.radial_segments = 6
	debris_mesh.rings = 3
	var debris_material := StandardMaterial3D.new()
	debris_material.albedo_color = Color(0.28, 0.24, 0.2)
	debris_material.roughness = 1.0
	debris_mesh.material = debris_material
	debris_particles.draw_pass_1 = debris_mesh

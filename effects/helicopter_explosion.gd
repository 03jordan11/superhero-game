extends "res://effects/vehicle_explosion_effect.gd"

# Keep the existing explosion timing/audio, with soft fire particles for aircraft.
func _configure_particles() -> void:
	super._configure_particles()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material: StandardMaterial3D = fire_particles.draw_pass_1.material
	material.albedo_texture = texture
	material.emission_texture = texture
	material.emission_energy_multiplier = 2.0

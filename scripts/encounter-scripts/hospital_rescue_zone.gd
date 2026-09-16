class_name HospitalRescueZone
extends Node3D
## Hospital-owned drop-off point; more points can later serve rooftop helipads.

@export var radius := 4.0
@export var height_tolerance := 1.5
var ring: MeshInstance3D

func _ready() -> void:
	add_to_group(&"hospital_rescue_zone")
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.rings = 32
	mesh.ring_segments = 4
	mesh.inner_radius = radius - 0.15
	mesh.outer_radius = radius
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 1.0, 0.25)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var label := Label3D.new()
	label.text = "HOSPITAL\nE: Set down patient"
	label.position.y = 1.4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.modulate = Color(0.3, 1.0, 0.4)
	add_child(label)

func contains_patient(patient: RescuePatient) -> bool:
	if not patient.is_on_floor() or is_instance_valid(patient.carrier): return false
	var local := to_local(patient.global_position)
	return Vector2(local.x, local.z).length() <= radius and absf(local.y) <= height_tolerance

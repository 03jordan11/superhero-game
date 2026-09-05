class_name LandingTargetIndicator
extends Node3D

@export var marker_size: float = 2.0
@export var marker_thickness: float = 0.12
@export var ray_length: float = 1000.0
@export var surface_offset: float = 0.03

var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	camera = player.get_node("SpringArm3D/Camera3D") as Camera3D
	_create_marker_meshes()
	visible = false


func _physics_process(_delta: float) -> void:
	if not OS.is_debug_build() or not DebugManager.show_landing_target:
		visible = false
		return

	var hit := get_landing_hit()
	if hit.is_empty():
		visible = false
		return

	visible = true
	global_position = hit.position + hit.normal * surface_offset


func get_landing_hit() -> Dictionary:
	# Project from the center of the active third-person camera, so the target
	# appears on the surface the player is looking at rather than directly below.
	var ray_origin := camera.global_position
	var ray_end := ray_origin + -camera.global_transform.basis.z * ray_length
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray_query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
	return hit


func _create_marker_meshes() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.emission_enabled = true
	material.emission = Color.RED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for rotation_degrees in [-45.0, 45.0]:
		var marker_arm := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(marker_size, 0.03, marker_thickness)
		marker_arm.mesh = mesh
		marker_arm.material_override = material
		marker_arm.rotation_degrees.y = rotation_degrees
		add_child(marker_arm)

@tool
extends Node3D
## Reusable visual asset. Forward is -Z; movement/AI can drive the root later.
const LIVERY_PATHS := [
	"res://assets/aircraft/helicopter/materials/forest_cream.tres",
	"res://assets/aircraft/helicopter/materials/rescue_red.tres",
	"res://assets/aircraft/helicopter/materials/coastal_blue.tres",
	"res://assets/aircraft/helicopter/materials/charcoal_orange.tres",
]
@export_enum("Forest / cream", "Rescue red", "Coastal blue", "Charcoal / orange") var livery: int = 0:
	set(value):
		livery = clampi(value, 0, 3)
		_apply_livery()
## Optional albedo atlas, using the supplied 4x4 tile UV layout.
@export var custom_livery_texture: Texture2D:
	set(value):
		custom_livery_texture = value
		_apply_livery()
@export var rotors_spinning := false
@export_range(0, 600, 1) var main_rotor_rpm := 324.0
@export_range(0, 2400, 1) var tail_rotor_rpm := 1650.0
## Solid parked collision; leave disabled for a future separately controlled aircraft body.
@export var parked_collision_enabled := false:
	set(value):
		parked_collision_enabled = value
		_update_collision()

func _ready() -> void:
	_apply_livery()
	_update_collision()

func _apply_livery() -> void:
	if not is_inside_tree() or not has_node("Body"):
		return
	var material := load(LIVERY_PATHS[livery]) as StandardMaterial3D
	if custom_livery_texture != null:
		material = material.duplicate() as StandardMaterial3D
		material.albedo_texture = custom_livery_texture
	for path in ["Body", "MainRotorPivot/MainRotor", "TailRotorPivot/TailRotor"]:
		var part := get_node_or_null(path) as MeshInstance3D
		if part != null:
			part.material_override = material

func _update_collision() -> void:
	var body := get_node_or_null("ParkedCollision") as StaticBody3D
	if body != null:
		body.collision_layer = 1 if parked_collision_enabled else 0
		body.collision_mask = 0

func _process(delta: float) -> void:
	# Keep editor placement previews stationary. The default scene is also static.
	if Engine.is_editor_hint() or not rotors_spinning:
		return
	advance_rotors(delta)

func advance_rotors(delta: float) -> void:
	var main := get_node("MainRotorPivot") as Node3D
	var tail := get_node("TailRotorPivot") as Node3D
	main.rotation.y = wrapf(main.rotation.y + main_rotor_rpm * TAU / 60.0 * delta, -PI, PI)
	tail.rotation.x = wrapf(tail.rotation.x + tail_rotor_rpm * TAU / 60.0 * delta, -PI, PI)

func reset_rotors() -> void:
	get_node("MainRotorPivot").rotation = Vector3.ZERO
	get_node("TailRotorPivot").rotation = Vector3.ZERO

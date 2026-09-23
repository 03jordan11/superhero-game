@tool
extends Node3D
## Selects an offline Blender bake; no per-frame generation or processing.
## Floors includes the ground parking level and the open top parking deck.
const WIDTHS := [32, 44, 56]
const VARIANTS := preload("res://assets/buildings/parking_garage/variants.gd")

@export_enum("Small — 32 m", "Medium — 44 m", "Large — 56 m") var width_preset: int = 1:
	set(value):
		width_preset = clampi(value, 0, 2)
		_queue_rebuild()
@export_range(3, 10, 1) var floors: int = 6:
	set(value):
		floors = clampi(value, 3, 10)
		_queue_rebuild()
var _rebuild_pending := false

func _ready() -> void:
	_rebuild()

func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_rebuild_pending = false
	if not is_inside_tree():
		return
	var old := get_node_or_null("GeneratedGarage")
	if old != null:
		remove_child(old)
		old.queue_free()
	var model := (VARIANTS.SCENES[width_preset * 8 + floors - 3] as PackedScene).instantiate()
	model.name = "GeneratedGarage"
	add_child(model)
	# Deliberately unowned: the Inspector saves parameters, not duplicated children.
	set_meta("rendered_triangles", model.get_meta("rendered_triangles"))

func get_dimensions() -> Vector3:
	return Vector3(WIDTHS[width_preset], (floors - 1) * 3.6 + 1.16, 54.0)

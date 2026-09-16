extends Node
## Removes complete repeated AC props once at city startup, including their collision.
## Library scenes remain intact for previews and future placement.

@export_range(0.0, 1.0, 0.01) var ac_retention := 0.30
@export var layout_seed: int = 7319

const AC_SCENES := [
	"res://assets/props/rooftop_hvac/rooftop_hvac.tscn",
	"res://assets/props/rooftop_hvac/rooftop_hvac_lowpoly.tscn",
]

var original_ac_count: int = 0
var retained_ac_count: int = 0

func _ready() -> void:
	# Deferred so every sibling has finished constructing its static props.
	_reduce_rooftop_equipment.call_deferred()

func _reduce_rooftop_equipment() -> void:
	var city := get_parent()
	var candidates: Array[Dictionary] = []
	for node in city.find_children("*", "StaticBody3D", true, false):
		if node.scene_file_path not in AC_SCENES:
			continue
		var path := str(city.get_path_to(node))
		var rng := RandomNumberGenerator.new()
		rng.seed = (str(layout_seed) + ":" + path).hash()
		candidates.append({"node": node, "score": rng.randf(), "path": path})
	# Rank placements independently of scene traversal order, then keep an exact quota.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score == b.score:
			return a.path < b.path
		return a.score < b.score)
	original_ac_count = candidates.size()
	retained_ac_count = roundi(original_ac_count * ac_retention)
	for index in range(retained_ac_count, original_ac_count):
		var unit: Node = candidates[index].node
		unit.get_parent().remove_child(unit)
		unit.queue_free()

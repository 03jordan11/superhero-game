extends Node3D
## Select once per person; the journey preserves this choice across LOD changes.
const MODELS: Array[PackedScene] = [
	preload("res://assets/characters/Civilians/prepared/civilian_male_fat_rigged.glb"),
	preload("res://assets/characters/Civilians/prepared/civilian_male_young_rigged.glb"),
	preload("res://assets/characters/Civilians/prepared/civilian_woman_athletic_rigged.glb"),
	preload("res://assets/characters/Civilians/prepared/civilian_woman_sweater_rigged.glb"),
]


static func choose_for(actor: Node) -> void:
	if actor.model_variant_index < 0 or actor.model_variant_index >= MODELS.size():
		actor.model_variant_index = randi_range(0, MODELS.size() - 1)


func _enter_tree() -> void:
	if has_node("Visual"):
		return
	var actor := get_parent()
	choose_for(actor)
	var visual := MODELS[actor.model_variant_index].instantiate() as Node3D
	visual.name = "Visual"
	add_child(visual)

extends RefCounted

var amount: float
var impact_origin: Vector3
var impact_direction: Vector3
var reaction: StringName
var source: Node3D
var impact_speed: float


func _init(
	damage_amount: float,
	damage_impact_origin: Vector3 = Vector3.ZERO,
	damage_impact_direction: Vector3 = Vector3.ZERO,
	damage_reaction: StringName = &"none",
	damage_source: Node3D = null,
	damage_impact_speed: float = 0.0
) -> void:
	amount = damage_amount
	impact_origin = damage_impact_origin
	impact_direction = damage_impact_direction
	reaction = damage_reaction
	source = damage_source
	impact_speed = damage_impact_speed

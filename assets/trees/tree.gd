@tool
extends MeshInstance3D
## One selectable tree, sharing its species mesh and material. No frame processing.
const TRUNK_SHAPE = preload("res://assets/trees/trunk_shape.tres")
@export var trunk_collision_enabled := true:
	set(value):
		trunk_collision_enabled = value
		_sync_collision()

func _enter_tree() -> void:
	_sync_collision()

func _sync_collision() -> void:
	if not is_inside_tree(): return
	var body := get_node_or_null("TrunkBody") as StaticBody3D
	if not trunk_collision_enabled:
		if body != null: body.free()
		return
	if body != null: return
	body = StaticBody3D.new()
	body.name = "TrunkBody"
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.position = Vector3(0,3.75,0)
	shape.shape = TRUNK_SHAPE
	body.add_child(shape)
	# Transient children follow the editable tree and are never baked into its scene.
	add_child(body,false,Node.INTERNAL_MODE_BACK)

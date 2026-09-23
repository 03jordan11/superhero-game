@tool
extends Marker3D
## Planning aid only. Its origin marks a proposed travel-boundary point.

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		hide()
		queue_free()

@tool
extends Node3D
## An authoring group referencing whole buildings in their original scene paths.
## CorridorHLOD adds runtime replacements; original building paths stay intact.

@export var building_paths: Array[NodePath] = []
## Nominal horizontal cell; assigned buildings may extend across its edges.
@export var cell_size_m := Vector2(250.0, 250.0)
## Bounds of all authored visible member meshes, relative to this chunk.
@export var source_bounds := AABB()
@export var show_editor_boundary := true:
	set(value):
		show_editor_boundary = value
		if is_inside_tree() and Engine.is_editor_hint():
			_refresh_editor_boundary.call_deferred()

var _editor_boundary: MeshInstance3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_boundary()

func get_buildings() -> Array[Node3D]:
	var buildings: Array[Node3D] = []
	for path in building_paths:
		var building := get_node_or_null(path) as Node3D
		if building != null:
			buildings.append(building)
	return buildings

func _refresh_editor_boundary() -> void:
	if not Engine.is_editor_hint(): return
	if is_instance_valid(_editor_boundary):
		remove_child(_editor_boundary)
		_editor_boundary.queue_free()
	if not show_editor_boundary: return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("4cc9df") if get_parent().name == &"Left" else Color("eeaa66")
	var half_size := cell_size_m * 0.5
	var corners := [Vector3(-half_size.x, 2.0, -half_size.y), Vector3(half_size.x, 2.0, -half_size.y), Vector3(half_size.x, 2.0, half_size.y), Vector3(-half_size.x, 2.0, half_size.y)]
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in 4:
		mesh.surface_add_vertex(corners[i])
		mesh.surface_add_vertex(corners[(i + 1) % 4])
	mesh.surface_end()
	_editor_boundary = MeshInstance3D.new()
	_editor_boundary.name = "EditorBoundary"
	_editor_boundary.mesh = mesh
	_editor_boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Unowned, internal and editor-only: never serialized or drawn in the game.
	add_child(_editor_boundary, false, Node.INTERNAL_MODE_BACK)

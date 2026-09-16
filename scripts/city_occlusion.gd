extends Node3D
## One static occluder per district, plus park structures/terrain and airport buildings.
## Source triangles preserve openings; no box is placed around an entire district.
@export var trial_enabled := true:
	set(value):
		trial_enabled = value
		visible = value
@export_node_path("Node3D") var districts_path := NodePath("../Districts")
@export_node_path("Node3D") var park_path := NodePath("../Landmarks/CentralPark")
@export_node_path("Node3D") var airport_path := NodePath("../CoastalRegion/Airport")

var building_count: int = 0
var triangle_count: int = 0
var inventory: Dictionary = {}

func _ready() -> void:
	_build.call_deferred()

func _build() -> void:
	var districts := get_node(districts_path)
	for district in districts.get_children():
		var visuals: Array[MeshInstance3D] = []
		for building in district.get_children():
			var visual := building.get_node_or_null("MeshInstance3D") as MeshInstance3D
			if visual != null: visuals.append(visual)
		_add_region(str(district.name),visuals)
	_add_region("CentralPark",_branch_meshes(get_node(park_path),["Terrain","Houses","Landmarks"]))
	_add_region("Airport",_branch_meshes(get_node(airport_path),["Terminal","ControlTower","Hangar","Hangar2"]))
	visible = trial_enabled

func _branch_meshes(root: Node, branches: Array[String]) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for path in branches:
		var branch := root.get_node(path)
		for visual in branch.find_children("*","MeshInstance3D",true,false):
			if visual.has_meta("strobe") or visual.has_meta("blink"): continue
			result.append(visual as MeshInstance3D)
	return result

func _add_region(region_name: String, visuals: Array[MeshInstance3D]) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var sources: Array[Dictionary] = []
	for visual in visuals:
		if visual == null or visual.mesh == null or not visual.is_visible_in_tree():
			continue
		var transform_to_occluder := global_transform.affine_inverse() * visual.global_transform
		var previous_count := indices.size()
		for surface in visual.mesh.get_surface_count():
			if visual.mesh is ArrayMesh and visual.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var material := visual.get_active_material(surface) as BaseMaterial3D
			if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var arrays := visual.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var offset := vertices.size()
			for point in points:
				vertices.append(transform_to_occluder * point)
			if faces.is_empty():
				for index in points.size(): indices.append(offset + index)
			else:
				for index in faces: indices.append(offset + index)
		if indices.size() > previous_count:
			sources.append({"path":str(get_parent().get_path_to(visual)),"triangles":(indices.size()-previous_count)/3})
	if not indices.is_empty():
		var shape := ArrayOccluder3D.new()
		shape.set_arrays(vertices, indices)
		var blocker := OccluderInstance3D.new()
		blocker.name = region_name
		blocker.occluder = shape
		add_child(blocker)
	building_count += sources.size()
	triangle_count += indices.size() / 3
	inventory[region_name] = {"sources":sources,"triangles":indices.size()/3}

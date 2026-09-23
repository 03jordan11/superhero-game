extends Node3D
## Static solid surfaces block hidden rendering; source faces preserve openings.
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
var terrain_inventory: Dictionary = {}
var _included: Dictionary = {}
const TERRAIN := {
	"Ground/GroundMesh/MeshInstance3D": preload("res://assets/occlusion/terrain/city_ground.scn"),
	"CityLife/Highway/NorthernGround": preload("res://assets/occlusion/terrain/northern_ground.scn"),
	"CoastalRegion/Landscape/CoastalTerrain": preload("res://assets/occlusion/terrain/coastal_terrain.scn"),
	"CityLife/Highway/PinePassMountains": preload("res://assets/occlusion/terrain/pine_pass_mountains.scn"),
}
const EXTRA_STATIC_BRANCHES := [
	"Ground", "Roads", "Sidewalks", "CityLife/Highway", "CityLife/Baseball",
	"Waterfront/Harbor", "Waterfront/PrisonIsland", "Waterfront/Riverbanks",
	"SouthRiverBridge", "CityHallBridge", "NorthRiverBridge", "RiverFrontage", "MountainRiver",
]

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
	# These are the actual land surfaces, not boxes around the mountain range.
	for path: String in TERRAIN:
		var source := get_parent().get_node_or_null(path) as MeshInstance3D
		if source == null or source.mesh == null: continue
		_add_region("Land_"+str(source.name),[source])
		_partition_terrain(source,TERRAIN[path])
	for path: String in EXTRA_STATIC_BRANCHES:
		var branch := get_parent().get_node_or_null(path)
		if branch != null: _add_region(path.replace("/","_"),_static_meshes(branch))
	# New stand-alone building assets (including configurable garages) are found
	# automatically. Their real surfaces keep ramps, colonnades and bays open.
	for branch in get_parent().get_children():
		if branch.scene_file_path.begins_with("res://assets/buildings/"):
			if not branch.find_children("*","OccluderInstance3D",true,false).is_empty(): continue
			_add_region(str(branch.name),_static_meshes(branch))
	# User-requested exception: the distant mountain image strip is a backdrop,
	# never an occlusion wall, and must not vanish behind terrain occluders.
	var backdrop := get_parent().get_node_or_null("CoastalRegion/DistantLandscape") as GeometryInstance3D
	if backdrop != null: backdrop.ignore_occlusion_culling = true
	visible = trial_enabled

func _static_meshes(branch: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if branch is RigidBody3D or branch is CharacterBody3D: return result
	var lower := String(branch.name).to_lower()
	if lower.contains("forest") or lower.contains("tree") or lower.contains("foliage") or lower.contains("foam") or lower.contains("surf"): return result
	if branch is MeshInstance3D:
		if branch.mesh == null or branch.skin != null: return result
		# Tiny props already get culled as targets; baking them as blockers adds
		# work with little benefit. Keep broad walls, floors and large structures.
		var size: Vector3 = branch.global_basis.get_scale().abs() * branch.get_aabb().size
		var broad_axes := int(size.x >= 2.0)+int(size.y >= 2.0)+int(size.z >= 2.0)
		if broad_axes >= 2: result.append(branch)
	for child in branch.get_children(): result.append_array(_static_meshes(child))
	return result

func _partition_terrain(source: MeshInstance3D, packed: PackedScene) -> void:
	var chunks := packed.instantiate() as Node3D
	if source.mesh.resource_path != chunks.get_meta("source_path") or FileAccess.get_sha256(source.mesh.resource_path) != chunks.get_meta("source_sha256"):
		push_warning("Terrain source changed; rebuild assets/occlusion/build_terrain_chunks.gd: "+str(source.get_path()))
		chunks.free()
		return
	for chunk: MeshInstance3D in chunks.get_children():
		chunk.material_override = source.material_override
		chunk.material_overlay = source.material_overlay
		chunk.cast_shadow = source.cast_shadow
		chunk.layers = source.layers
		chunk.gi_mode = source.gi_mode
		chunk.visibility_range_begin = source.visibility_range_begin
		chunk.visibility_range_end = source.visibility_range_end
		chunk.ignore_occlusion_culling = false
		var surfaces: PackedInt32Array = chunk.get_meta("source_surfaces")
		for i in surfaces.size(): chunk.set_surface_override_material(i,source.get_surface_override_material(surfaces[i]))
	source.set_meta("occlusion_source_mesh",source.mesh)
	source.add_child(chunks)
	source.mesh = null # Keep the existing node, transform and all collision children.
	terrain_inventory[str(get_parent().get_path_to(source))] = chunks.get_child_count()

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
		if _included.has(visual.get_instance_id()): continue
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
			_included[visual.get_instance_id()] = true
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

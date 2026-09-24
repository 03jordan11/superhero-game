extends SceneTree
## Offline triangle projection source. Main is never added to the scene tree.
const DEST := "res://artifacts/minimap/"
const BOUNDS := Rect2(-5000, -3500, 7200, 6500)
var city: Node3D
var output: FileAccess
var counts: Dictionary = {}
var sources: Dictionary = {}
var triangles := 0

func _initialize() -> void:
	call_deferred("export_map")

func export_map() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	city = main.get_node("SuperCity")
	sources["res://scenes/main.tscn"] = FileAccess.get_sha256("res://scenes/main.tscn")
	DirAccess.make_dir_recursive_absolute(DEST)
	output = FileAccess.open(DEST + "region_triangles.bin", FileAccess.WRITE)
	visit(city, Transform3D.IDENTITY, true)
	output.close()
	var data := {"bounds_xz": [-5000, -3500, 2200, 3000], "coordinate_space": "SuperCity local: +X right, -Z up", "city_transform": var_to_str(city.transform), "triangle_count": triangles, "categories": counts, "source_sha256": sources, "format": "little endian float32 records: category, ax,ay,az,bx,by,bz,cx,cy,cz"}
	FileAccess.open(DEST + "region_geometry.json", FileAccess.WRITE).store_string(JSON.stringify(data, "\t"))
	print("REGION_MAP: ", triangles, " triangles; ", counts)
	main.free()
	quit()

func visit(node: Node, parent_transform: Transform3D, shown: bool) -> void:
	var transform := parent_transform
	if node != city and node is Node3D:
		transform = parent_transform * node.transform
		shown = shown and node.visible
	var path := str(city.get_path_to(node))
	var lower := path.to_lower()
	if not node.scene_file_path.is_empty() and not sources.has(node.scene_file_path):
		sources[node.scene_file_path] = FileAccess.get_sha256(node.scene_file_path)
	if lower.contains("proxy") or lower.contains("proxies") or lower.contains("occlusion") or lower.contains("distantlandscape") or lower.contains("airtraffic") or lower.contains("civilian") or lower.contains("collision"):
		return
	if shown and node is MeshInstance3D and node.mesh != null:
		export_mesh(node.mesh, transform, lower)
	if shown and node is MultiMeshInstance3D and node.multimesh != null:
		var mm: MultiMesh = node.multimesh
		if mm.mesh != null:
			var amount := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			for i in amount:
				export_mesh(mm.mesh, transform * mm.get_instance_transform(i), lower)
	for child in node.get_children():
		visit(child, transform, shown)

func category(path: String) -> int:
	if path.contains("seabed") or path.contains("foam") or path.contains("wash") or path.contains("islandsurf") or path.contains("navigation") or path.contains("boats/"): return -1
	if path == "ground/groundmesh/meshinstance3d": return 9
	if path.contains("/lake/water"): return 0
	if path.contains("/trails/"): return 4
	if path.contains("highway/") and (path.contains("carriage") or path.contains("asphalt") or path.contains("embankment") or path.contains("median")): return 4
	if path.contains("waterfront/water") or path.contains("mountainriver/water") or path.contains("pond") and not path.contains("bank"): return 0
	if path.contains("mountainriver/bed"): return 1
	if path.contains("pinepassmountains") or path.contains("islandterrain") or path.contains("coastaloutcrop") or path.contains("forestboundarybackdrop"): return 2
	if path.contains("forest") or path.contains("pine_") or path.contains("/trees/") or path.contains("/tree") or path.contains("/hedge"): return 3
	if path.contains("terrain") or path.contains("northernground") or path.contains("grass") or path.contains("ground/mesh"): return 1
	if path.contains("marking") or path.contains("stripe") or path.contains("runwayedge") or path.contains("threshold"): return 6
	if path.contains("runway09") or path.contains("taxiway") or path.contains("runwayconnector"): return 5
	if path.contains("road") or path.contains("highwaysurface") or path.contains("access") or path.contains("/deck") or path.contains("bridge") or path.contains("sidewalk") or path.contains("infill") or path.contains("apron") or path.contains("parkinglot") or path.contains("/path") or path.contains("/yard"): return 4
	if path.contains("landmarks/centralpark"): return 3
	if path.contains("/districts/") or path.begins_with("districts/"): return 7
	if path.contains("airport") or path.contains("penitentiary") or path.contains("cityhall") or path.contains("hospital") or path.contains("bank") or path.contains("policestation") or path.contains("firehouse"): return 8
	return 7

func export_mesh(mesh: Mesh, transform: Transform3D, path: String) -> void:
	var cat := category(path)
	if cat < 0: return
	var box := transform * mesh.get_aabb()
	if not Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersects(BOUNDS): return
	# Tiny props do not survive map resolution. Keep ground markings.
	if cat != 6 and box.size.x * box.size.z < 2.0: return
	# Tree crowns use their actual transformed footprint, without millions of leaf triangles.
	if cat == 3 and not path.contains("centralpark") and not path.contains("chunks"):
		var y := box.end.y
		var center := box.get_center()
		for i in 12:
			var a := float(i) * TAU / 12.0
			var b := float(i + 1) * TAU / 12.0
			write_triangle(cat, Vector3(center.x,y,center.z), Vector3(center.x+cos(a)*box.size.x/2,y,center.z+sin(a)*box.size.z/2), Vector3(center.x+cos(b)*box.size.x/2,y,center.z+sin(b)*box.size.z/2))
		return
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for i in range(0, indices.size(), 3):
			write_triangle(cat, transform * vertices[indices[i]], transform * vertices[indices[i+1]], transform * vertices[indices[i+2]])

func write_triangle(cat: int, a: Vector3, b: Vector3, c: Vector3) -> void:
	var area := absf((b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x))
	if area < 0.08: return
	var values := PackedFloat32Array([cat, a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z])
	output.store_buffer(values.to_byte_array())
	triangles += 1
	counts[str(cat)] = counts.get(str(cat), 0) + 1

extends SceneTree
## Read-only geometry inventory; never saves the park or its meshes.
const OUTPUT := "res://artifacts/central_park/triangle_audit.json"

func _initialize() -> void:
	run.call_deferred()

func category(path: String) -> String:
	if path.begins_with("Woodland/"): return "Trees"
	if path.begins_with("Terrain/"): return "Ground and lake bed"
	if path.begins_with("Trails/"): return "Paths"
	if path.begins_with("Lake/"): return "Lake water"
	if path.contains("/Bench"): return "Benches"
	if path.begins_with("Houses/"): return "Houses and furnishings (excluding benches)"
	if path.begins_with("Lanterns/"): return "Trail lanterns"
	if path.contains("BowBridge/"): return "Bridge"
	if path.contains("MoonwaterDock/"): return "Dock (excluding bench)"
	if path.contains("WhisperingStones/"): return "Standing stones and runes"
	if path.contains("StarlitGrotto/"): return "Crystal grotto"
	if path.contains("ParkGate"): return "Entrance piers"
	if path.contains("ShoreBoulders"): return "Shore rocks"
	if path.contains("Undergrowth"): return "Bushes and undergrowth"
	if path.contains("MushroomStem") or path.contains("Mooncap"): return "Mushrooms"
	if path == "Fireflies" or path == "Wisps": return "Night swarms"
	return "UNCLASSIFIED"

func mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh:
			assert(mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES)
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		assert(count % 3 == 0)
		total += count / 3
	return total

func run() -> void:
	var park: Node3D = load("res://scenes/central_park.tscn").instantiate()
	root.add_child(park)
	await process_frame
	park.set_process(false)
	var rows: Array[Dictionary] = []
	var categories: Dictionary = {}
	var trees: Dictionary = {}
	var collision: Dictionary = {}
	var lights := 0
	var shadow_lights := 0
	for node in park.find_children("*", "", true, false):
		var path := str(park.get_path_to(node))
		if node is Light3D:
			lights += 1
			if node.shadow_enabled: shadow_lights += 1
		if node is CollisionShape3D and node.shape != null:
			var kind: String = node.shape.get_class()
			collision[kind] = int(collision.get(kind, 0)) + 1
			if node.shape is ConcavePolygonShape3D:
				collision["concave_triangles"] = int(collision.get("concave_triangles", 0)) + node.shape.get_faces().size() / 3
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count
			if node.multimesh.visible_instance_count >= 0:
				instances = mini(instances, node.multimesh.visible_instance_count)
		else:
			continue
		if mesh == null: continue
		var per_mesh := mesh_triangles(mesh)
		var total := per_mesh * instances
		var group := category(path)
		assert(group != "UNCLASSIFIED", path)
		park.apply_night(0.0)
		var day: bool = node.is_visible_in_tree()
		park.apply_night(1.0)
		var night: bool = node.is_visible_in_tree()
		var row := {"path":path,"category":group,"node_type":node.get_class(),"mesh":mesh.resource_path,
			"instances":instances,"triangles_each":per_mesh,"triangles":total,"surfaces":mesh.get_surface_count(),
			"day_visible":day,"night_visible":night,"visibility_end":node.visibility_range_end}
		rows.append(row)
		if not categories.has(group): categories[group] = {"triangles":0,"day_triangles":0,"night_triangles":0,"mesh_nodes":0,"instances":0}
		var result: Dictionary = categories[group]
		result.triangles += total
		result.day_triangles += total if day else 0
		result.night_triangles += total if night else 0
		result.mesh_nodes += 1
		result.instances += instances
		if group == "Trees":
			var species := mesh.resource_path.get_file().get_basename().trim_prefix("tree_")
			if not trees.has(species): trees[species] = {"count":0,"triangles":0,"triangles_each":per_mesh,"batches":0,"individual_nodes":0}
			trees[species].count += instances
			trees[species].triangles += total
			if node is MultiMeshInstance3D: trees[species].batches += 1
			else: trees[species].individual_nodes += 1
	var total := 0
	var day_total := 0
	var night_total := 0
	for entry: Dictionary in categories.values():
		total += entry.triangles
		day_total += entry.day_triangles
		night_total += entry.night_triangles
	var report := {"scene":"res://scenes/central_park.tscn","scope":"Highest-detail triangles per placed instance; before camera/distance/occlusion culling and extra rendering passes. Collision excluded.",
		"total_triangles":total,"day_triangles":day_total,"night_triangles":night_total,"mesh_nodes":rows.size(),
		"lights":lights,"shadow_lights":shadow_lights,"collision":collision,"categories":categories,"trees":trees,"rows":rows}
	DirAccess.make_dir_recursive_absolute("res://artifacts/central_park")
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"total":total,"day":day_total,"night":night_total,"categories":categories,"trees":trees,"collision":collision,"mesh_nodes":rows.size(),"lights":lights,"shadow_lights":shadow_lights}))
	park.free()
	quit()

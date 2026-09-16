extends SceneTree
## Count all instances of the shared tree resources without running scene scripts.
func _initialize() -> void:
	var report := {}
	for file in ["central_park","city_life","coastal_region"]:
		var scene: Node = load("res://scenes/%s.tscn" % file).instantiate()
		var species := {}
		var total := 0
		var trees := 0
		for node in scene.find_children("*","GeometryInstance3D",true,false):
			var mesh: Mesh
			var count := 1
			if node is MeshInstance3D: mesh = node.mesh
			elif node is MultiMeshInstance3D:
				mesh = node.multimesh.mesh
				count = node.multimesh.instance_count
			else: continue
			if mesh == null: continue
			if not mesh.resource_path.begins_with("res://assets/central-park/meshes/tree_"): continue
			var name := mesh.resource_path.get_file().get_basename().trim_prefix("tree_")
			var triangles := mesh.get_faces().size()/3
			if OS.get_cmdline_user_args().has("--validate"):
				assert(triangles <= 100,"Shared tree exceeds triangle limit: "+name)
			if not species.has(name): species[name] = {"count":0,"triangles_each":triangles,"triangles":0,"batches":0,"individual_nodes":0}
			species[name].count += count
			species[name].triangles += count*triangles
			if node is MultiMeshInstance3D: species[name].batches += 1
			else: species[name].individual_nodes += 1
			total += count*triangles
			trees += count
		report[file] = {"tree_count":trees,"tree_triangles":total,"species":species}
		scene.free()
	var output := FileAccess.open("res://artifacts/central_park/shared_tree_audit.json",FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()

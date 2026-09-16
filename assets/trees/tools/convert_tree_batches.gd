extends SceneTree
const TREES = preload("res://assets/trees/tools/tree_instances.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	assert(DisplayServer.get_name()!="headless","Use graphics renderer to preserve unrelated MultiMeshes")
	var report := {}
	for file in ["central_park","city_life","coastal_region"]:
		var path := "res://scenes/%s.tscn" % file
		var scene: Node3D = load(path).instantiate()
		var before: Array = []
		var non_tree_meshes := {}
		for mesh_node in scene.find_children("*","MeshInstance3D",true,false):
			non_tree_meshes[str(scene.get_path_to(mesh_node))] = mesh_node.mesh
		for batch: MultiMeshInstance3D in scene.find_children("*","MultiMeshInstance3D",true,false):
			var mesh: Mesh = batch.multimesh.mesh
			if not mesh.resource_path.begins_with("res://assets/central-park/meshes/tree_"): continue
			var species := mesh.resource_path.get_file().get_basename().trim_prefix("tree_")
			var poses: Array = []
			for i in batch.multimesh.instance_count:
				poses.append(batch.multimesh.get_instance_transform(i))
				before.append({"species":species,"pose":var_to_str(batch.transform*poses[-1]),"parent":str(scene.get_path_to(batch.get_parent())),"distance":batch.visibility_range_end,"margin":batch.visibility_range_end_margin})
			var parent := batch.get_parent()
			var index := batch.get_index()
			var label := batch.name
			var pose := batch.transform
			var distance := batch.visibility_range_end
			var margin := batch.visibility_range_end_margin
			batch.free()
			var container := TREES.group(parent,scene,label,species,poses,distance,margin,file=="central_park")
			container.transform = pose
			parent.move_child(container,index)
		if file=="central_park":
			for child in scene.get_node("TreeCollisions").get_children(): child.free()
			scene.get_node("Woodland").set_meta("tree_container",true)
		scene.set_meta("individual_tree_scenes",true)
		assert(TREES.trees(scene).size()==before.size())
		for node_path in non_tree_meshes:
			assert(scene.get_node(node_path).mesh == non_tree_meshes[node_path],"Non-tree mesh changed")
		var packed := PackedScene.new()
		assert(packed.pack(scene)==OK)
		assert(ResourceSaver.save(packed,path)==OK)
		report[file] = before
		scene.free()
		print("Converted %s: %d individually editable trees" % [file,before.size()])
	var output := FileAccess.open("res://artifacts/central_park/tree_conversion_baseline.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	quit()

extends SceneTree
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 15: push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/central_park/tree_conversion_baseline.json"))
	var pruning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mountain-river/report.json"))
	var total := 0
	var saved_counts := {}
	for file in baseline:
		var scene: Node = load("res://scenes/%s.tscn" % file).instantiate()
		var found := TREES.trees(scene)
		var removed: Array = pruning.removed_trees.get(file,[]).duplicate()
		if file == "city_life":
			var thinning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/trees/highway_thinning.json"))
			removed.append_array(thinning.removed)
		# Include manual deletions made after the original tree conversion, before this task.
		var before_count: int = pruning.before_tree_counts[file]
		saved_counts[file]=before_count-removed.size()
		check(found.size()==saved_counts[file],"Tree count matches saved edits and mountain clearing: "+file)
		for row in removed: check(not scene.has_node(row.path),"Pruned mountain tree remains deleted")
		var expected := {}
		for row in baseline[file]:
			var pose: Transform3D = str_to_var(row.pose)
			var key: String = row.parent+"/"+row.species+"/"+str(pose.origin.snapped(Vector3.ONE*.01))
			expected[key] = row
		for tree: MeshInstance3D in found:
			var container := tree.get_parent() as Node3D
			var pose := container.transform*tree.transform
			var species := tree.scene_file_path.get_file().get_basename()
			var key := str(scene.get_path_to(container.get_parent()))+"/"+species+"/"+str(pose.origin.snapped(Vector3.ONE*.01))
			check(expected.has(key),"Tree remains at its original location: "+key)
			if expected.has(key):
				var row: Dictionary = expected[key]
				var original: Transform3D = str_to_var(row.pose)
				check(pose.origin.distance_to(original.origin)<.002 and pose.basis.is_equal_approx(original.basis),"Rotation/scale/position preserved")
				check(is_equal_approx(tree.visibility_range_end,row.distance) and is_equal_approx(tree.visibility_range_end_margin,row.margin),"Distance settings preserved")
			check(tree.owner == scene,"Tree is an editable instance owned by its scene")
			check(tree.mesh.get_faces().size()/3 <=100,"Triangle budget preserved")
			check(tree.trunk_collision_enabled == (file=="central_park"),"Regional collision behavior preserved")
		for batch in scene.find_children("*","MultiMeshInstance3D",true,false):
			check(not batch.multimesh.mesh.resource_path.begins_with("res://assets/central-park/meshes/tree_"),"No tree batches remain")
		total += found.size()
		scene.free()
	var probe: MeshInstance3D = load("res://assets/trees/oak.tscn").instantiate()
	probe.trunk_collision_enabled = false
	root.add_child(probe)
	check(not probe.has_node("TrunkBody"),"Disabled collision allocates no physics body")
	probe.trunk_collision_enabled = true
	check(probe.has_node("TrunkBody/CollisionShape3D"),"Enabling collision creates trunk")
	probe.trunk_collision_enabled = false
	check(not probe.has_node("TrunkBody"),"Disabling collision removes trunk")
	probe.free()
	for file in baseline: test_saved_edits(file,saved_counts[file])
	print("Individual tree scenes: %d instances checked, %d failures" % [total,failures])
	quit(0 if failures==0 else 1)

func test_saved_edits(file: String, original_count: int) -> void:
	var scene_path := "res://scenes/%s.tscn" % file
	var old: Node3D = load(scene_path).instantiate()
	var old_trees := TREES.trees(old)
	var deleted_path := old.get_path_to(old_trees[0])
	var moved_path := old.get_path_to(old_trees[1])
	old_trees[0].free()
	old_trees[1].position += Vector3(1.5,0,-2.5)
	var moved: Vector3 = old_trees[1].position
	var packed := PackedScene.new()
	check(packed.pack(old)==OK,"Pack edited fixture")
	var fixture := "res://artifacts/central_park/%s_tree_edit_fixture.tscn" % file
	check(ResourceSaver.save(packed,fixture)==OK,"Save edited fixture")
	old.free()
	var rebuilt: Node3D = load(scene_path).instantiate()
	check(TREES.restore_saved_layout(rebuilt,fixture)==original_count-1,"Rebuild preserves deletion")
	check(not rebuilt.has_node(deleted_path),"Deleted tree and collision stay deleted")
	check(rebuilt.get_node(moved_path).position.is_equal_approx(moved),"Rebuild preserves manual movement")
	for tree in TREES.trees(rebuilt): check(tree.owner==rebuilt and not tree.scene_file_path.is_empty(),"Restored instances retain ownership and scene links")
	# Persist a completely cleared forest too, rather than restoring generated trees.
	for container in TREES.containers(rebuilt): container.free()
	check(packed.pack(rebuilt)==OK,"Pack cleared forest fixture")
	var empty_fixture := "res://artifacts/central_park/%s_tree_empty_fixture.tscn" % file
	check(ResourceSaver.save(packed,empty_fixture)==OK,"Save cleared forest fixture")
	rebuilt.free()
	var empty: Node3D = load(scene_path).instantiate()
	check(TREES.restore_saved_layout(empty,empty_fixture)==0,"Explicitly cleared forest stays empty")
	empty.free()

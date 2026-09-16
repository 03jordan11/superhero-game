extends RefCounted
## Offline shared helpers. Saved individual instances are authoritative on rebuild.
const SPECIES := ["oak","pine","birch","willow"]
const PREFIX := "res://assets/trees/"
static var scenes := {}

static func is_tree(node: Node) -> bool:
	return node is MeshInstance3D and node.scene_file_path in SPECIES.map(func(s: String) -> String: return PREFIX+s+".tscn")

static func trees(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for node in root.find_children("*","MeshInstance3D",true,false):
		if is_tree(node): result.append(node)
	return result

static func create(parent: Node, owner: Node, species: String, pose: Transform3D, label: String, distance: float, margin: float, collision: bool) -> MeshInstance3D:
	if not scenes.has(species): scenes[species] = load(PREFIX+species+".tscn")
	var tree: MeshInstance3D = scenes[species].instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	tree.name = label
	tree.transform = pose
	tree.visibility_range_end = distance
	tree.visibility_range_end_margin = margin
	tree.trunk_collision_enabled = collision
	parent.add_child(tree,true)
	tree.owner = owner
	return tree

static func group(parent: Node, owner: Node, label: String, species: String, poses: Array, distance: float, margin: float, collision: bool) -> Node3D:
	var container := Node3D.new()
	container.name = label
	container.set_meta("tree_container",true)
	parent.add_child(container,true)
	container.owner = owner
	for i in poses.size(): create(container,owner,species,poses[i],"%s_%04d" % [species.capitalize(),i+1],distance,margin,collision)
	return container

static func containers(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for node in root.find_children("*","Node3D",true,false):
		if not node.get_meta("tree_container",false): continue
		var nested := false
		var parent := node.get_parent()
		while parent != root:
			if parent.get_meta("tree_container",false): nested = true
			parent = parent.get_parent()
		if not nested: result.append(node)
	return result

static func own_branch(node: Node, owner: Node) -> void:
	node.owner = owner
	if not node.scene_file_path.is_empty(): return
	for child in node.get_children(): own_branch(child,owner)

static func restore_saved_layout(root: Node, path: String) -> int:
	# An empty saved forest is also an edit: do not silently repopulate it.
	if not FileAccess.file_exists(path):
		root.set_meta("individual_tree_scenes",true)
		return -1
	var old: Node = load(path).instantiate()
	if not old.get_meta("individual_tree_scenes",false):
		old.free()
		root.set_meta("individual_tree_scenes",true)
		return -1
	for node in containers(root): node.free()
	for source in containers(old):
		var parent := root.get_node(old.get_path_to(source.get_parent()))
		var copy := source.duplicate()
		parent.add_child(copy)
		own_branch(copy,root)
	root.set_meta("individual_tree_scenes",true)
	var count := trees(root).size()
	old.free()
	return count

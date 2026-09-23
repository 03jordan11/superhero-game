extends SceneTree
const CLIP = preload("res://assets/trees/tools/forest_boundary_clip.gd")
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/trees/forest_boundary_report.json"))
	var planes := CLIP.saved_planes()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIP.CONFIG))
	for marker in config.markers:
		var p := Vector3(marker.position[0],marker.position[1],marker.position[2])
		for i in 64:
			var direction := Vector2.from_angle(TAU*i/64.0)
			check(CLIP.contains(p+Vector3(direction.x,0,direction.y)*2000,planes,0.01),"Full 2 km buffer around marker")
	for row in report.meshes:
		var scene: Node3D = load("res://scenes/"+row.scene+".tscn").instantiate()
		var node: MeshInstance3D = scene.get_node(row.node)
		check(node.mesh.resource_path==row.mesh,"Scene uses trimmed terrain: "+row.node)
		var faces := node.mesh.get_faces()
		check(faces.size()/3==row.after_triangles,"Baked triangle count matches")
		var outside := 0
		for vertex in faces:
			if not CLIP.contains(vertex,planes,0.02): outside += 1
		check(outside==0,"All terrain vertices lie within cutoff: "+row.node)
		# Verify exported geometry inside the buffer wasn't accidentally dropped or moved.
		var retained_triangles := {}
		for i in range(0,faces.size(),3): retained_triangles[triangle_key(faces,i)] = true
		var original: Mesh = load(row.source)
		var original_faces := original.get_faces()
		var missing := 0
		for i in range(0,original_faces.size(),3):
			# Degenerate source triangles have no surface area to preserve.
			if (original_faces[i+1]-original_faces[i]).cross(original_faces[i+2]-original_faces[i]).length_squared() == 0.0: continue
			if CLIP.contains(original_faces[i],planes) and CLIP.contains(original_faces[i+1],planes) and CLIP.contains(original_faces[i+2],planes):
				if not retained_triangles.has(triangle_key(original_faces,i)):
					missing += 1
		check(missing==0,"All original interior triangles retained: "+row.node)
		if row.has("collision"):
			check(node.get_node("Solid/CollisionShape3D").shape.get_faces()==faces,"Terrain collision matches clipped surface")
		scene.free()
	for name in report.tree_counts:
		var scene: Node3D = load("res://scenes/"+name+".tscn").instantiate()
		var trees := TREES.trees(scene)
		check(trees.size()==int(report.tree_counts[name].after),"Remaining tree count: "+name)
		for row in report.removed_trees[name]: check(not scene.has_node(row.path),"Removed tree stays absent")
		for tree: Node3D in trees:
			var pose := tree.transform
			var parent := tree.get_parent()
			while parent != scene:
				if parent is Node3D: pose=parent.transform*pose
				parent=parent.get_parent()
			check(CLIP.contains(pose.origin,planes,0.02),"Tree root stays inside retained ground: "+str(scene.get_path_to(tree)))
		scene.free()
	print("Forest boundary: %d failures"%failures)
	quit(1 if failures else 0)

func triangle_key(faces: PackedVector3Array, start: int) -> String:
	var points: Array[String] = []
	for i in 3: points.append(str(faces[start+i].snapped(Vector3.ONE*0.01)))
	points.sort()
	return "|".join(points)

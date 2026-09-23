extends SceneTree
## Bake from current authored terrain; apply the resulting manifest separately.
const CLIP = preload("res://assets/trees/tools/forest_boundary_clip.gd")
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
const OUT := "res://assets/trees/boundary_terrain/"
const REPORT := "res://assets/trees/forest_boundary_report.json"
const BUFFER := 2000.0
var planes: Array[Plane] = []
var report := {"meshes": [], "removed_trees": {}, "tree_counts": {}, "markers": []}

func _initialize() -> void: run.call_deferred()

func pose_in(node: Node3D, ancestor: Node) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent != ancestor:
		if parent is Node3D: pose = parent.transform * pose
		parent = parent.get_parent()
	return pose

func run() -> void:
	if FileAccess.file_exists(REPORT):
		push_error("Boundary already baked. Preserve the previous source/report before rebuilding.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	var points := PackedVector2Array()
	for group in city.get_node("ForestBoundaryMarkers").get_children():
		for marker in group.get_children():
			if not marker is Marker3D: continue
			var p := pose_in(marker, city).origin
			points.append(Vector2(p.x, p.z))
			report.markers.append({"path": str(city.get_path_to(marker)), "position": [p.x,p.y,p.z]})
	assert(points.size() >= 4)
	# Conservatively surround every marker, then add 2 km in every horizontal direction.
	# 64 supporting directions approximate rounded corners without cutting into the buffer.
	var directions: Array[Vector2] = []
	for i in 64: directions.append(Vector2.from_angle(TAU*i/64.0))
	var hull := Geometry2D.convex_hull(points)
	for i in hull.size()-1:
		var edge := (hull[i+1]-hull[i]).normalized()
		directions.append(Vector2(edge.y,-edge.x))
	var saved := []
	for normal in directions:
		var extent := -INF
		for point in points: extent = maxf(extent, normal.dot(point))
		planes.append(Plane(Vector3(normal.x,0,normal.y), extent+BUFFER))
		saved.append([normal.x,normal.y,extent+BUFFER])
	var config := {"buffer_m": BUFFER, "method": "Convex envelope of placed travel markers plus a conservative rounded 2 km buffer", "markers": report.markers, "planes": saved}
	FileAccess.open(CLIP.CONFIG,FileAccess.WRITE).store_string(JSON.stringify(config,"\t"))
	for item in [["CityLife/Highway/NorthernGround","city_northern"],["CoastalRegion/Landscape/CoastalTerrain","city_coastal"]]:
		bake_mesh(city, item[0], item[1], "super_city")
	city.free()
	for scene_name in ["city_life", "coastal_region"]:
		var scene: Node3D = load("res://scenes/"+scene_name+".tscn").instantiate()
		var removed := []
		var trees := TREES.trees(scene)
		for tree: MeshInstance3D in trees:
			var pose := pose_in(tree,scene)
			# A crown can overhang the cut, but its trunk must remain on retained ground.
			if not CLIP.contains(pose.origin, planes):
				removed.append({"path":str(scene.get_path_to(tree)),"position":[pose.origin.x,pose.origin.y,pose.origin.z],"triangles":tree.mesh.get_faces().size()/3})
		report.removed_trees[scene_name] = removed
		report.tree_counts[scene_name] = {"before":trees.size(),"removed":removed.size(),"after":trees.size()-removed.size()}
		if scene_name == "city_life":
			bake_mesh(scene,"Highway/NorthernGround","standalone_northern",scene_name)
		else:
			bake_mesh(scene,"Landscape/CoastalTerrain","standalone_coastal",scene_name)
			bake_mesh(scene,"Landscape/BeachWash","beach_wash",scene_name)
		scene.free()
	if report.meshes.size() != 5:
		push_error("Incomplete terrain bake; no application manifest written")
		quit(1)
		return
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BOUNDARY_BAKE: ", report.tree_counts)
	quit()

func bake_mesh(scene: Node3D, node_path: String, label: String, scene_name: String) -> void:
	var node: MeshInstance3D = scene.get_node(node_path)
	assert(pose_in(node,scene).is_equal_approx(Transform3D.IDENTITY), "Terrain clipping expects world-aligned sources")
	var source: Mesh = node.mesh
	var clipped := CLIP.clip_mesh(source, planes)
	if clipped == null: return
	var mesh_path := OUT+label+".res"
	assert(ResourceSaver.save(clipped,mesh_path,ResourceSaver.FLAG_COMPRESS)==OK)
	var row := {"scene":scene_name,"node":node_path,"source":source.resource_path,"source_sha256":FileAccess.get_sha256(source.resource_path),"mesh":mesh_path,"before_triangles":source.get_faces().size()/3,"after_triangles":clipped.get_faces().size()/3,"before_bounds":var_to_str(source.get_aabb()),"after_bounds":var_to_str(clipped.get_aabb())}
	if node.has_node("Solid/CollisionShape3D"):
		var original: ConcavePolygonShape3D = node.get_node("Solid/CollisionShape3D").shape
		var shape := clipped.create_trimesh_shape()
		shape.backface_collision = original.backface_collision
		var collision_path := OUT+label+"_collision.res"
		assert(ResourceSaver.save(shape,collision_path,ResourceSaver.FLAG_COMPRESS)==OK)
		row.collision = collision_path
	report.meshes.append(row)
	print("CLIPPED ",label,": ",row.before_triangles," -> ",row.after_triangles," triangles")

extends SceneTree
## Offline 500 m forest cells, with sparse neighboring cells paired once.
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
const OUT := "res://assets/trees/chunks/"
const CELL := 500.0
var material: StandardMaterial3D
var recipes := {}

func _initialize() -> void: run.call_deferred()

func pose_in(tree: Node3D, region: Node3D) -> Transform3D:
	var pose := tree.transform
	var parent := tree.get_parent()
	while parent != region:
		if parent is Node3D: pose = parent.transform*pose
		parent = parent.get_parent()
	return pose

func authored_visible(tree: Node3D, region: Node3D) -> bool:
	var node := tree
	while node != region:
		if not node.visible: return false
		node = node.get_parent() as Node3D
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	material = (load("res://assets/central-park/meshes/tree_pine.res") as Mesh).surface_get_material(0).duplicate()
	assert(ResourceSaver.save(material,OUT+"tree_material.tres")==OK)
	material.take_over_path(OUT+"tree_material.tres")
	for item in [["city_life","Highway","northern"],["coastal_region",".","coastal"]]:
		bake(item[0],item[1],item[2])
	quit()

func bake(scene_name: String, root_path: String, region_name: String) -> void:
	var scene: Node3D = load("res://scenes/"+scene_name+".tscn").instantiate()
	var region: Node3D = scene.get_node(root_path)
	var cells := {}
	var hashes := {}
	var visibility := {}
	var trees := TREES.trees(region)
	var tree_scenes: Array[String] = []
	for tree: MeshInstance3D in trees:
		assert(not tree.trunk_collision_enabled,"Regional forest bake must not replace collision behavior")
		var pose := pose_in(tree,region)
		var cell := Vector2i(floori(pose.origin.x/CELL),floori(pose.origin.z/CELL))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append({"tree":tree,"pose":pose})
		var ancestor: Node3D = tree
		while ancestor != region:
			visibility[str(region.get_path_to(ancestor))] = ancestor.visible
			ancestor = ancestor.get_parent() as Node3D
		hashes[tree.mesh.resource_path] = FileAccess.get_sha256(tree.mesh.resource_path)
		if tree.scene_file_path not in tree_scenes: tree_scenes.append(tree.scene_file_path)
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return cells[a].size()<cells[b].size() if cells[a].size()!=cells[b].size() else (a.x<b.x if a.x!=b.x else a.y<b.y))
	var used := {}
	var groups := []
	for cell: Vector2i in keys:
		if used.has(cell): continue
		used[cell] = true
		var members: Array = cells[cell].duplicate()
		var grouped := [cell]
		if members.size()<6:
			for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
				var neighbor: Vector2i = cell+offset
				if used.has(neighbor) or not cells.has(neighbor) or cells[neighbor].size()>12: continue
				if members.size()+cells[neighbor].size()>16: continue
				members.append_array(cells[neighbor])
				grouped.append(neighbor)
				used[neighbor] = true
				break
		groups.append({"cells":grouped,"members":members})
	var root_node := Node3D.new()
	root_node.name = "ForestChunks"
	root_node.set_script(load("res://scripts/forest_chunks.gd"))
	root_node.inventory_path = OUT+region_name+".json"
	var data := {"tree_count":trees.size(),"tree_scenes":tree_scenes,"source_hashes":hashes,"authored_visibility":visibility,"cell_size_m":CELL,"chunks":[],"source_triangles":0,"proxy_triangles":0,"near_triangles":0,"original_cells":cells.size()}
	for group: Dictionary in groups:
		var record := bake_chunk(region,region_name,group,root_node)
		if record.is_empty(): continue
		data.chunks.append(record)
		data.source_triangles += record.source_triangles
		data.near_triangles += record.near_triangles
		data.proxy_triangles += record.proxy_triangles
	FileAccess.open(root_node.inventory_path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	var packed := PackedScene.new()
	assert(packed.pack(root_node)==OK)
	assert(ResourceSaver.save(packed,OUT+region_name+".tscn")==OK)
	print("FOREST ",region_name,": ",trees.size()," trees -> ",groups.size()," chunks; triangles ",data.source_triangles," -> ",data.proxy_triangles," distant; near=",data.near_triangles)
	root_node.free()
	scene.free()

func bake_chunk(region: Node3D, region_name: String, group: Dictionary, root_node: Node3D) -> Dictionary:
	var bounds := AABB()
	var started := false
	var sources := []
	var source_triangles := 0
	var limit := 0.0
	var unlimited := false
	for member: Dictionary in group.members:
		var tree: MeshInstance3D = member.tree
		var box: AABB = member.pose*tree.get_aabb()
		bounds = bounds.merge(box) if started else box
		started = true
		limit = maxf(limit,tree.visibility_range_end)
		unlimited = unlimited or tree.visibility_range_end == 0.0
		sources.append({"path":str(region.get_path_to(tree)),"transform":var_to_str(member.pose),"visible":tree.visible,"mesh":tree.mesh.resource_path,"visibility_end":tree.visibility_range_end})
		if authored_visible(tree,region): source_triangles += tree.mesh.get_faces().size()/3
	if source_triangles == 0: return {}
	var centre := bounds.get_center()
	var near := SurfaceTool.new()
	near.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far := SurfaceTool.new()
	far.begin(Mesh.PRIMITIVE_TRIANGLES)
	for member: Dictionary in group.members:
		var tree: MeshInstance3D = member.tree
		if not authored_visible(tree,region): continue
		var pose: Transform3D = member.pose
		pose.origin -= centre
		append_original(near,tree.mesh,pose)
		append_proxy(far,tree,pose)
	var key: Vector2i = group.cells[0]
	var name_tag := "Chunk_%d_%d"%[key.x,key.y]
	var node := Node3D.new()
	node.name = name_tag
	node.position = centre
	node.visible = false # Editor displays the editable original trees.
	node.set_meta("cells",str(group.cells))
	node.set_meta("tree_count",sources.size())
	node.set_meta("source_bounds",bounds)
	root_node.add_child(node)
	node.owner = root_node
	var counts := []
	for pair in [[near,"FullDetail"],[far,"DistantProxy"]]:
		var builder: SurfaceTool = pair[0]
		builder.set_material(material)
		builder.index()
		var mesh := builder.commit()
		assert(mesh!=null and mesh.get_surface_count()==1)
		var path := OUT+region_name+"_"+name_tag.to_lower()+"_"+str(pair[1]).to_snake_case()+".res"
		assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
		mesh.take_over_path(path)
		var instance := MeshInstance3D.new()
		instance.name = pair[1]
		instance.mesh = mesh
		if pair[1]=="DistantProxy": instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(instance)
		instance.owner = root_node
		counts.append(mesh.get_faces().size()/3)
	return {"name":name_tag,"cells":str(group.cells),"bounds_position":[bounds.position.x,bounds.position.y,bounds.position.z],"bounds_size":[bounds.size.x,bounds.size.y,bounds.size.z],"sources":sources,"source_triangles":source_triangles,"near_triangles":counts[0],"proxy_triangles":counts[1],"visibility_end":0.0 if unlimited else limit}

func append_original(builder: SurfaceTool, mesh: Mesh, pose: Transform3D) -> void:
	for surface in mesh.get_surface_count():
		var mat := mesh.surface_get_material(surface) as StandardMaterial3D
		assert(mat!=null and mat.vertex_color_use_as_albedo and mat.vertex_color_is_srgb and mat.albedo_color==Color.WHITE and mat.albedo_texture==null)
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
		for index in indices:
			builder.set_normal((pose.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][index]).normalized())
			builder.set_color(arrays[Mesh.ARRAY_COLOR][index])
			builder.add_vertex(pose*arrays[Mesh.ARRAY_VERTEX][index])

func append_proxy(builder: SurfaceTool, tree: MeshInstance3D, pose: Transform3D) -> void:
	var key := tree.mesh.resource_path
	if not recipes.has(key): recipes[key] = recipe(tree)
	for triangle: Array in recipes[key]:
		var normal: Vector3 = (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
		for i in 3:
			builder.set_normal((pose.basis.inverse().transposed()*normal).normalized())
			builder.set_color(triangle[3])
			builder.add_vertex(pose*triangle[i])

func face(output: Array, a: Vector3,b: Vector3,c: Vector3,centre: Vector3,color: Color) -> void:
	if (c-a).cross(b-a).dot((a+b+c)/3.0-centre)<0: output.append([a,c,b,color])
	else: output.append([a,b,c,color])

func recipe(tree: MeshInstance3D) -> Array:
	var leaves := AABB()
	var trunk := AABB()
	var leaves_started := false
	var trunk_started := false
	var green := Color(0,0,0,0)
	var count := 0
	for surface in tree.mesh.get_surface_count():
		var arrays := tree.mesh.surface_get_arrays(surface)
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
			var color: Color = arrays[Mesh.ARRAY_COLOR][i]
			if color.g>color.r*1.05:
				leaves = leaves.expand(vertex) if leaves_started else AABB(vertex,Vector3.ZERO)
				leaves_started = true
				green += color
				count += 1
			else:
				trunk = trunk.expand(vertex) if trunk_started else AABB(vertex,Vector3.ZERO)
				trunk_started = true
	assert(leaves_started and trunk_started)
	green /= float(count)
	var result := []
	var center := trunk.get_center()
	for i in 4:
		var a := TAU*i/4.0
		var b := TAU*(i+1)/4.0
		var p := Vector3(center.x+cos(a)*trunk.size.x*0.5,trunk.position.y,center.z+sin(a)*trunk.size.z*0.5)
		var q := Vector3(center.x+cos(b)*trunk.size.x*0.5,trunk.position.y,center.z+sin(b)*trunk.size.z*0.5)
		var up := Vector3.UP*trunk.size.y
		face(result,p,p+up,q+up,center,Color("60503a"))
		face(result,p,q+up,q,center,Color("60503a"))
	center = leaves.get_center()
	var top := Vector3(center.x,leaves.end.y,center.z)
	var bottom := Vector3(center.x,leaves.position.y,center.z)
	var pine := tree.scene_file_path.ends_with("pine.tscn")
	var sides := 6 if pine else 4
	for i in sides:
		var a := TAU*i/float(sides)
		var b := TAU*(i+1)/float(sides)
		var height := leaves.position.y if pine else center.y
		var p := Vector3(center.x+cos(a)*leaves.size.x*0.5,height,center.z+sin(a)*leaves.size.z*0.5)
		var q := Vector3(center.x+cos(b)*leaves.size.x*0.5,height,center.z+sin(b)*leaves.size.z*0.5)
		face(result,p,top,q,center,green)
		face(result,p,q,bottom,center,green.darkened(0.08))
	return result

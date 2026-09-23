extends SceneTree
## Offline combined cargo and harbor meshes, using Main's final edited placements.
const RUNTIME = preload("res://scripts/harbor_chunks.gd")
const OUT := "res://assets/waterfront/harbor_chunks/"
var material: ShaderMaterial
var region: Node3D

func _initialize() -> void: run.call_deferred()

func surface() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	region = world.get_node("SuperCity/Waterfront/Harbor")
	var snapshot := RUNTIME.harbor_snapshot(region)
	assert(not snapshot.is_empty(),"Unsupported harbor material; review before baking")
	var paving: ShaderMaterial = region.get_node("ConcretePierExtension").get_active_material(0)
	material = ShaderMaterial.new()
	material.shader = load(OUT+"harbor.gdshader")
	material.set_shader_parameter("night_amount",0.0)
	material.set_shader_parameter("paving",paving.get_shader_parameter("paving"))
	material.set_shader_parameter("tile_size",paving.get_shader_parameter("tile_size"))
	material.set_shader_parameter("warm_emission",region.get_node("HarborOffice/OfficeWindow").get_active_material(0).emission)
	material.set_shader_parameter("cool_emission",region.get_node("HarborLamp/Lens").get_active_material(0).emission)
	material.set_shader_parameter("iron_color",region.get_node("HarborLamp/Housing").get_active_material(0).albedo_color)
	assert(ResourceSaver.save(material,OUT+"material.tres")==OK)
	material.take_over_path(OUT+"material.tres")
	var cargo := surface()
	var structures := surface()
	var proxy := surface()
	var labels := []
	var bounds := AABB()
	var first := true
	var data := {"sources":snapshot,"source_hashes":{},"chunks":[],"source_surfaces":0,"source_triangles":0,"cargo_sources":0,"cargo_items":0}
	var texture: Texture2D = paving.get_shader_parameter("paving")
	for path in [paving.shader.resource_path,texture.resource_path]: data.source_hashes[path] = FileAccess.get_sha256(path)
	for child in region.get_children():
		if str(child.name).begins_with("Container") or str(child.name).begins_with("CargoCrate"): data.cargo_items+=1
	for path: String in snapshot:
		if not snapshot[path].visible: continue
		var node := region.get_node(NodePath(path))
		if node is Label3D:
			labels.append(path)
			continue
		var mesh := node as MeshInstance3D
		var pose := RUNTIME.pose_in(mesh,region)
		var box := pose*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		var is_cargo := path.begins_with("Container") or path.begins_with("CargoCrate")
		append(cargo if is_cargo else structures,mesh.mesh,pose,mesh.get_active_material(0))
		data.source_surfaces += mesh.mesh.get_surface_count()
		data.source_triangles += mesh.mesh.get_faces().size()/3
		if is_cargo: data.cargo_sources += 1
		# Tiny trim disappears at distance; the major silhouettes stay geometrical.
		var name_tag := str(mesh.name)
		if name_tag.begins_with("Corrugation") or name_tag.begins_with("DoorLock") or name_tag.begins_with("RailingPost") or name_tag.begins_with("StoneCourse"): continue
		var simplified: Mesh = mesh.mesh
		if simplified is CylinderMesh:
			var simple := BoxMesh.new()
			simple.size = mesh.get_aabb().size
			simplified = simple
		append(proxy,simplified,pose,mesh.get_active_material(0),name_tag.begins_with("Container"))
	# This compact harbor fits a single 500 m region; don't split its cargo stacks.
	assert(maxf(bounds.size.x,bounds.size.z)<=500,"Harbor grew beyond one chunk; split the authoring groups before rebaking")
	var root_node := Node3D.new()
	root_node.name = "HarborChunks"
	root_node.set_script(RUNTIME)
	var chunk := Node3D.new()
	chunk.name = "Harbor_0"
	chunk.visible = false
	root_node.add_child(chunk)
	chunk.owner = root_node
	var near := Node3D.new()
	near.name = "FullDetail"
	chunk.add_child(near)
	near.owner = root_node
	var cargo_mesh := save_mesh("CargoCombined",cargo,near,root_node)
	var structures_mesh := save_mesh("StructuresCombined",structures,near,root_node)
	var far_mesh := save_mesh("DistantProxy",proxy,chunk,root_node)
	far_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	data.near_triangles = cargo_mesh.mesh.get_faces().size()/3+structures_mesh.mesh.get_faces().size()/3
	data.far_triangles = far_mesh.mesh.get_faces().size()/3
	data.label_triangle_upper_bound = 0
	for path: String in labels: data.label_triangle_upper_bound += region.get_node(path).text.length()*4
	assert(data.near_triangles+data.label_triangle_upper_bound<=10000,"Complete harbor POI budget")
	data.chunks.append({"name":str(chunk.name),"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z],"labels":labels})
	var packed := PackedScene.new()
	assert(packed.pack(root_node)==OK)
	assert(ResourceSaver.save(packed,OUT+"harbor_chunks.tscn")==OK)
	FileAccess.open(OUT+"inventory.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("HARBOR: ",data.source_surfaces," surfaces -> 2 near / 1 far; ",data.source_triangles," triangles -> ",data.near_triangles," near / ",data.far_triangles," far; cargo ",data.cargo_items," items / ",data.cargo_sources," surfaces -> 1")
	root_node.free()
	world.free()
	quit()

func append(tool: SurfaceTool, mesh: Mesh, pose: Transform3D, mat: Material, painted_container := false) -> void:
	var color := Color.WHITE
	var glow := 0.0
	var paving := false
	if mat is StandardMaterial3D:
		assert(mat.albedo_texture==null and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and is_zero_approx(mat.metallic) and not mat.vertex_color_use_as_albedo)
		color = mat.albedo_color.srgb_to_linear()
		glow = float(mat.get_meta("night_glow",0.0))
		if mat.emission.b>mat.emission.r: glow = -glow
	else:
		assert(mat is ShaderMaterial and mat.shader.resource_path.ends_with("modular-sidewalks/sidewalk.gdshader"))
		paving = true
	for index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for i in indices:
			var style := 1.0 if paving else 0.0
			var uv := Vector2.ZERO
			if painted_container:
				if absf(normals[i].x)>0.9:
					style = 2.0
					uv = Vector2(vertices[i].z+1.0,vertices[i].y)
				elif normals[i].z>0.9:
					style = 3.0
					uv = Vector2(vertices[i].x,vertices[i].y)
			tool.set_normal((pose.basis.inverse().transposed()*normals[i]).normalized())
			tool.set_color(color)
			tool.set_uv(uv)
			tool.set_uv2(Vector2(glow,style))
			tool.add_vertex(pose*vertices[i])

func save_mesh(label: String, tool: SurfaceTool, parent: Node3D, owner_node: Node3D) -> MeshInstance3D:
	tool.set_material(material)
	tool.index()
	var mesh := tool.commit()
	assert(mesh.get_surface_count()==1)
	var path := OUT+label+".res"
	assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
	mesh.take_over_path(path)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	parent.add_child(node)
	node.owner = owner_node
	return node

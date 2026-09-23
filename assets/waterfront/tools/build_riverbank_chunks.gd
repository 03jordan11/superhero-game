extends SceneTree
## Main's authored riverbank overrides are authoritative; never resurrect hidden walls.
const RUNTIME = preload("res://scripts/riverbank_chunks.gd")
const OUT := "res://assets/waterfront/chunks/"
const CELL := 500.0
var material: ShaderMaterial
var scene: Node3D
var region: Node3D
var output: Node3D
var data := {}
var covered := {}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = load("res://scenes/main.tscn").instantiate()
	region = scene.get_node("SuperCity/Waterfront/Riverbanks")
	material = ShaderMaterial.new()
	material.shader = load(OUT+"riverbank.gdshader")
	material.set_shader_parameter("night_amount",0.0)
	material.set_shader_parameter("course_color",region.get_node("QuayWall171/StoneCourse").get_active_material(0).albedo_color)
	var lens := region.get_node("HarborLamp/Lens") as MeshInstance3D
	material.set_shader_parameter("lamp_emission",lens.get_active_material(0).emission)
	assert(ResourceSaver.save(material,OUT+"material.tres")==OK)
	material.take_over_path(OUT+"material.tres")
	output = Node3D.new()
	output.name = "RiverbankChunks"
	output.set_script(RUNTIME)
	data = {"cell_size_m":CELL,"sources":RUNTIME.snapshot(region),"chunks":[],"source_surfaces":0,"source_triangles":0,"near_triangles":0,"far_triangles":0}
	assert(not data.sources.is_empty())
	for path: String in data.sources:
		if not data.sources[path].visible: continue
		var node: MeshInstance3D = region.get_node(path)
		data.source_surfaces += node.mesh.get_surface_count()
		data.source_triangles += node.mesh.get_faces().size()/3
	var cells := {}
	for child: Node3D in region.get_children():
		if not RUNTIME.authored_visible(child,region): continue
		if str(child.name).begins_with("QuayWall"):
			bake_wall(child)
		elif str(child.name).begins_with("HarborLamp"):
			var position := RUNTIME.pose_in(child,region).origin
			var cell := Vector2i(floori(position.x/CELL),floori(position.z/CELL))
			if not cells.has(cell): cells[cell] = []
			cells[cell].append(child)
	for cell: Vector2i in cells: bake_lamps(cell,cells[cell])
	for path: String in data.sources:
		assert(not data.sources[path].visible or covered.has(path),"Unbaked riverbank source: "+path)
	var packed := PackedScene.new()
	assert(packed.pack(output)==OK)
	assert(ResourceSaver.save(packed,OUT+"riverbank_chunks.tscn")==OK)
	FileAccess.open(OUT+"inventory.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("RIVERBANK_CHUNKS: ",data.source_surfaces," source surfaces -> ",data.chunks.size()," one-surface chunks; triangles ",data.source_triangles," original / ",data.near_triangles," near / ",data.far_triangles," distant")
	output.free()
	scene.free()
	quit()

func surface() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func append(tool: SurfaceTool, mesh: Mesh, pose: Transform3D, mat: StandardMaterial3D, painted := false) -> void:
	assert(mat.albedo_texture == null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_zero_approx(mat.metallic))
	for index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for i in indices:
			var point := pose*vertices[i]
			var normal := (pose.basis.inverse().transposed()*normals[i]).normalized()
			tool.set_normal(normal)
			tool.set_color(mat.albedo_color.srgb_to_linear())
			tool.set_uv(Vector2(1.0 if painted and absf(normal.y)<0.1 else 0.0,point.y))
			tool.set_uv2(Vector2(float(mat.get_meta("night_glow",0.0)),mat.roughness))
			tool.add_vertex(point)

func bake_wall(wall: MeshInstance3D) -> void:
	var length: float = wall.mesh.size.z
	var pieces := ceili(length/CELL)
	for part in pieces:
		var near := surface()
		var far := surface()
		var span := length/pieces
		var offset := -length/2+span*(part+0.5)
		var meshes: Array[MeshInstance3D] = [wall]
		for node: MeshInstance3D in wall.find_children("*","MeshInstance3D",true,false):
			if RUNTIME.authored_visible(node,region): meshes.append(node)
		for mesh in meshes:
			covered[str(region.get_path_to(mesh))] = true
			assert(mesh.mesh is BoxMesh,"Review non-box wall details before baking")
			var box := BoxMesh.new()
			box.size = mesh.mesh.size
			box.size.z = span
			var pose := RUNTIME.pose_in(mesh,region)
			pose.origin += RUNTIME.pose_in(wall,region).basis*Vector3(0,0,offset)
			append(near,box,pose,mesh.get_active_material(0))
			if not str(mesh.name).begins_with("StoneCourse"):
				append(far,box,pose,mesh.get_active_material(0),mesh==wall)
		save_chunk("Seawall_%s_%d"%[wall.name,part],near,far)

func bake_lamps(cell: Vector2i, lamps: Array) -> void:
	var near := surface()
	var far := surface()
	for lamp: Node3D in lamps:
		for mesh: MeshInstance3D in lamp.find_children("*","MeshInstance3D",true,false):
			if not RUNTIME.authored_visible(mesh,region): continue
			covered[str(region.get_path_to(mesh))] = true
			var pose := RUNTIME.pose_in(mesh,region)
			append(near,mesh.mesh,pose,mesh.get_active_material(0))
			var replacement: Mesh = mesh.mesh
			if mesh.mesh is CylinderMesh:
				var box := BoxMesh.new()
				box.size = mesh.get_aabb().size
				replacement = box
			append(far,replacement,pose,mesh.get_active_material(0))
	save_chunk("Lamps_%d_%d"%[cell.x,cell.y],near,far)

func save_chunk(label: String, near: SurfaceTool, far: SurfaceTool) -> void:
	var chunk := Node3D.new()
	chunk.name = label
	chunk.visible = false # Editable originals remain visible in the editor.
	output.add_child(chunk)
	chunk.owner = output
	var record := {"name":label}
	for item in [["FullDetail",near],["DistantProxy",far]]:
		var tool: SurfaceTool = item[1]
		tool.set_material(material)
		tool.index()
		var mesh := tool.commit()
		assert(mesh.get_surface_count()==1)
		var path: String = OUT+label+"_"+item[0]+".res"
		assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
		mesh.take_over_path(path)
		var node := MeshInstance3D.new()
		node.name = item[0]
		node.mesh = mesh
		if item[0]=="DistantProxy": node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(node)
		node.owner = output
		var triangles := mesh.get_faces().size()/3
		record[item[0]] = {"mesh":path,"triangles":triangles}
		data["near_triangles" if item[0]=="FullDetail" else "far_triangles"] += triangles
	data.chunks.append(record)

extends SceneTree
const OUT="res://assets/mountain-river/mouth/"
func _initialize() -> void: run.call_deferred()
func make_mesh(surfaces: Array,origin:=Vector3.ZERO,generate:=false) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	for s in surfaces:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in s.v:
			st.set_normal(Vector3(v[3],v[4],v[5]));st.set_uv(Vector2(v[6],v[7]));st.add_vertex(Vector3(v[0],v[1],v[2])-origin)
		if generate:st.generate_normals()
		st.set_material(load(s.material) if s.get("material","")!="" else null)
		st.commit(mesh)
	return mesh
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT+"meshes")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/river_mouth/build.json"))
	for record in data.replacements:
		var mesh:=make_mesh(record.surfaces,Vector3(record.origin[0],record.origin[1],record.origin[2]))
		var slug: String=record.body.get_file()
		assert(ResourceSaver.save(mesh,OUT+"meshes/"+slug+".res",ResourceSaver.FLAG_COMPRESS)==OK)
		assert(ResourceSaver.save(mesh.create_trimesh_shape(),OUT+"meshes/"+slug+"_collision.res",ResourceSaver.FLAG_COMPRESS)==OK)
	var frontage:=Node3D.new();frontage.name="RiverFrontage"
	for key in data.frontage:
		var material_path: String="res://assets/super-city/materials/sidewalk.tres" if key=="Quay" else "res://assets/super-city/materials/ground.tres"
		var mesh:=make_mesh([{"v":data.frontage[key],"material":material_path}],Vector3.ZERO,key in ["Stone","Rail"])
		var file:=OUT+"meshes/"+str(key).to_snake_case()+".res"
		assert(ResourceSaver.save(mesh,file,ResourceSaver.FLAG_COMPRESS)==OK)
		if key=="Water":continue
		var node:=MeshInstance3D.new();node.name=key;node.mesh=mesh;frontage.add_child(node);node.owner=frontage
		if key=="Stone" or key=="Bed":
			var mat:=StandardMaterial3D.new();mat.albedo_color=Color("596269") if key=="Stone" else Color("434d42");mat.roughness=.9;node.material_override=mat
		if key=="Rail":
			var mat:=ShaderMaterial.new();mat.shader=load("res://assets/mountain-river/railing.gdshader");node.material_override=mat
		else:
			var body:=StaticBody3D.new();body.name="Solid";node.add_child(body);body.owner=frontage
			var shape:=CollisionShape3D.new();shape.name="CollisionShape3D";shape.shape=mesh.create_trimesh_shape();body.add_child(shape);shape.owner=frontage
	var packed:=PackedScene.new();assert(packed.pack(frontage)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/river_frontage.tscn")==OK);frontage.free()
	# Main keeps only the mountain reach; the city's waterfront owns urban water.
	var north: Node3D=load("res://artifacts/river_mouth/before/scenes/mountain_river.tscn").instantiate()
	var source: Mesh=north.get_node("Water").mesh;var a: Array=source.surface_get_arrays(0)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,a[Mesh.ARRAY_VERTEX].size(),3):
		var keep:=true
		for k in 3:
			if a[Mesh.ARRAY_VERTEX][i+k].z>-999.99:keep=false
		if not keep:continue
		for k in 3:st.set_normal(Vector3.UP);st.add_vertex(a[Mesh.ARRAY_VERTEX][i+k])
	var mesh:=st.commit();assert(ResourceSaver.save(mesh,OUT+"meshes/north_water.res",ResourceSaver.FLAG_COMPRESS)==OK)
	north.get_node("Water").mesh=mesh
	for name in ["Quay","Stone","Rail"]:north.get_node(name).free()
	assert(packed.pack(north)==OK);assert(ResourceSaver.save(packed,"res://scenes/mountain_river.tscn")==OK);north.free()
	print("Built curved city frontage and separate mountain reach.");quit()

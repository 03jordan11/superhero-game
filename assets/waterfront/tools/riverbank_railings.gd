extends RefCounted
## One alpha-cutout surface, with thin top strips so rails remain visible from above.
const OUT := "res://assets/waterfront/railings/"

static func pose_in(node: Node3D, root: Node3D) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent != root:
		if parent is Node3D: pose = parent.transform*pose
		parent = parent.get_parent()
	return pose

static func material() -> StandardMaterial3D:
	var path := OUT+"railing_material.tres"
	if FileAccess.file_exists(path): return load(path)
	DirAccess.make_dir_recursive_absolute(OUT)
	var image := Image.create(1024,256,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.16,0.21,0.24,0))
	# Six-metre repeat: existing narrow posts plus the continuous top handrail.
	image.fill_rect(Rect2i(0,0,1024,19),Color("29353c"))
	image.fill_rect(Rect2i(0,0,7,256),Color("29353c"))
	image.fill_rect(Rect2i(1017,0,7,256),Color("29353c"))
	assert(image.save_png(OUT+"railing.png")==OK)
	image.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	assert(ResourceSaver.save(mat,path)==OK)
	mat.take_over_path(path)
	return mat

static func quad(tool: SurfaceTool, points: Array, uv: Array, normal: Vector3) -> void:
	var order := [0,1,2,0,2,3]
	if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0: order=[0,2,1,0,3,2]
	for index in order:
		tool.set_normal(normal)
		tool.set_uv(uv[index])
		tool.add_vertex(points[index])

static func build(group: Node3D) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 0
	for wall: Node3D in group.get_children():
		if not wall.has_meta("railing_length"): continue
		var length: float = wall.get_meta("railing_length")
		var pose := pose_in(wall,group)
		var a := -length/2
		var b := length/2
		var repeat := length/6.0
		quad(tool,[pose*Vector3(0,5.125,a),pose*Vector3(0,5.125,b),pose*Vector3(0,6.19,b),pose*Vector3(0,6.19,a)],
			[Vector2(0,1),Vector2(repeat,1),Vector2(repeat,0),Vector2(0,0)],(pose.basis*Vector3.RIGHT).normalized())
		quad(tool,[pose*Vector3(-0.035,6.19,a),pose*Vector3(0.035,6.19,a),pose*Vector3(0.035,6.19,b),pose*Vector3(-0.035,6.19,b)],
			[Vector2(0,0.02),Vector2(0,0.04),Vector2(repeat,0.04),Vector2(repeat,0.02)],(pose.basis*Vector3.UP).normalized())
		segments += 1
	assert(segments>0,"No riverbank rail segments to bake")
	tool.set_material(material())
	tool.index()
	var mesh := tool.commit()
	assert(mesh.get_surface_count()==1)
	var path := OUT+"riverbank_railings.res"
	assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
	mesh.take_over_path(path)
	var node := MeshInstance3D.new()
	node.name = "RiverbankRailings"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("segments",segments)
	group.add_child(node)
	return node

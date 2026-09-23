extends RefCounted
## Small-detail reductions for the complete 10k-triangle POI budget. Colliders stay intact.
static func quad(size: Vector2, normal: Vector3, offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var u := Vector3.RIGHT if normal == Vector3.UP else Vector3.BACK
	var v := Vector3.FORWARD if normal == Vector3.UP else Vector3.UP
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [-u*size.x/2-v*size.y/2,u*size.x/2-v*size.y/2,u*size.x/2+v*size.y/2,-u*size.x/2+v*size.y/2]
	var uv := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	for i in [0,2,1,0,3,2]:
		tool.set_normal(normal)
		tool.set_uv(uv[i])
		tool.add_vertex(points[i]+offset)
	return tool.commit()

static func octahedron(radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := Vector3(cos(i*PI/2),0,sin(i*PI/2))*radius
		var b := Vector3(cos((i+1)*PI/2),0,sin((i+1)*PI/2))*radius
		for points in [[a,Vector3.UP*radius,b],[b,Vector3.DOWN*radius,a]]:
			var normal: Vector3 = (points[2]-points[0]).cross(points[1]-points[0]).normalized()
			for p: Vector3 in points:
				tool.set_normal(normal)
				tool.add_vertex(p)
	return tool.commit()

static func prison(root: Node3D) -> Array[Dictionary]:
	var edits: Array[Dictionary] = []
	var window_material: StandardMaterial3D
	for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if str(node.name).begins_with("WindowBar"):
			node.mesh = null
			edits.append({"node":node,"property":"mesh","resource":null})
		elif str(node.name).begins_with("CellWindow"):
			if window_material == null:
				window_material = node.material_override.duplicate()
				window_material.cull_mode = BaseMaterial3D.CULL_DISABLED
				var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
				image.fill(Color.WHITE)
				for x in [26,64,102]: image.fill_rect(Rect2i(x-3,0,7,128),Color("29353c"))
				image.generate_mipmaps()
				window_material.albedo_texture = ImageTexture.create_from_image(image)
				var emission := image.duplicate() as Image
				for x in [26,64,102]: emission.fill_rect(Rect2i(x-3,0,7,128),Color.BLACK)
				emission.generate_mipmaps()
				window_material.emission_texture = ImageTexture.create_from_image(emission)
			node.mesh = quad(Vector2(1.5,2.0),Vector3.RIGHT)
			node.material_override = window_material
			edits.append({"node":node,"property":"mesh","resource":node.mesh})
			edits.append({"node":node,"property":"material_override","resource":window_material})
	return edits

static func airport(root: Node3D) -> Array[Dictionary]:
	var edits: Array[Dictionary] = []
	var window_material: StandardMaterial3D
	for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh
		if mesh is SphereMesh and mesh.radial_segments>12:
			mesh = mesh.duplicate()
			mesh.radial_segments = 12
			mesh.rings = 5
		elif mesh is CylinderMesh:
			mesh = mesh.duplicate()
			mesh.radial_segments = 6
			mesh.rings = 0
		elif mesh is BoxMesh and str(node.name).begins_with("CabinWindow"):
			if window_material == null:
				window_material = node.material_override.duplicate()
				window_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh = quad(Vector2(mesh.size.z,mesh.size.y),Vector3.RIGHT)
			node.material_override = window_material
			edits.append({"node":node,"property":"material_override","resource":window_material})
		elif mesh is BoxMesh and mesh.size.y<0.05:
			mesh = quad(Vector2(mesh.size.x,mesh.size.z),Vector3.UP,Vector3.UP*mesh.size.y/2)
		else: continue
		node.mesh = mesh
		edits.append({"node":node,"property":"mesh","resource":mesh})
	var bulb := octahedron(0.45)
	for node: MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
		if not str(node.name).begins_with("AirfieldLights"): continue
		node.multimesh = node.multimesh.duplicate()
		node.multimesh.mesh = bulb
		edits.append({"node":node,"property":"multimesh","resource":node.multimesh})
	return edits

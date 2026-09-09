extends RefCounted
## Small offline surface builder. All surfaces are ordinary StandardMaterial3D.
var surfaces: Dictionary = {}
var collision_faces = PackedVector3Array()
var origin := Vector3.ZERO

func quad(points: Array, uv: Array, normal: Vector3, material: Material) -> void:
	if not surfaces.has(material):
		surfaces[material] = [PackedVector3Array(),PackedVector3Array(),PackedVector2Array()]
	var data: Array = surfaces[material]
	for index in [0,1,2,0,2,3]:
		data[0].append(points[index]-origin)
		data[1].append(normal)
		data[2].append(uv[index])
		collision_faces.append(points[index]-origin)

func slab(rect: Rect2, top: float, depth: float, material: Material, uv_scale := Vector2.ONE, rotate_uv := false, uv_offset := Vector2.ZERO) -> void:
	var a = Vector3(rect.position.x,top,rect.position.y)
	var b = Vector3(rect.end.x,top,rect.position.y)
	var c = Vector3(rect.end.x,top,rect.end.y)
	var d = Vector3(rect.position.x,top,rect.end.y)
	var uv = [Vector2.ZERO,Vector2(uv_scale.x,0),uv_scale,Vector2(0,uv_scale.y)]
	if rotate_uv:
		uv = [Vector2.ZERO,Vector2(0,uv_scale.y),uv_scale,Vector2(uv_scale.x,0)]
	for i in range(uv.size()):
		uv[i] += uv_offset
	quad([a,b,c,d],uv,Vector3.UP,material)
	if depth <= 0:
		return
	var down = Vector3(0,-depth,0)
	var zero = [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
	quad([a+down,b+down,b,a],zero,Vector3.FORWARD,material)
	quad([b+down,c+down,c,b],zero,Vector3.RIGHT,material)
	quad([c+down,d+down,d,c],zero,Vector3.BACK,material)
	quad([d+down,a+down,a,d],zero,Vector3.LEFT,material)

func mesh() -> ArrayMesh:
	var result = ArrayMesh.new()
	for material in surfaces:
		var data: Array = surfaces[material]
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data[0]
		arrays[Mesh.ARRAY_NORMAL] = data[1]
		arrays[Mesh.ARRAY_TEX_UV] = data[2]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,material)
	return result

func body(node_name: String, mesh_path: String, simple_box := false) -> StaticBody3D:
	var result = StaticBody3D.new()
	result.name = node_name
	result.position = origin
	var visual = MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = mesh()
	assert(ResourceSaver.save(visual.mesh,mesh_path) == OK)
	visual.mesh.take_over_path(mesh_path)
	result.add_child(visual)
	visual.owner = result
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	if simple_box:
		var shape = BoxShape3D.new()
		var bounds = visual.mesh.get_aabb()
		shape.size = bounds.size
		collision.shape = shape
		collision.position = bounds.get_center()
	else:
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		collision.shape = shape
	result.add_child(collision)
	collision.owner = result
	return result

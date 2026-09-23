extends RefCounted
## Offline terrain clipping. Does not change runtime visibility or player movement.
const CONFIG := "res://assets/trees/forest_boundary.json"

static func saved_planes() -> Array[Plane]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var result: Array[Plane] = []
	for row in data.planes:
		result.append(Plane(Vector3(row[0], 0, row[1]), row[2]))
	return result

static func contains(point: Vector3, planes: Array[Plane], margin := 0.0) -> bool:
	for plane in planes:
		if plane.distance_to(point) > margin: return false
	return true

static func clip_mesh(source: Mesh, planes: Array[Plane]) -> ArrayMesh:
	var output := ArrayMesh.new()
	for surface in source.get_surface_count():
		assert(source.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES)
		var arrays := source.surface_get_arrays(surface)
		# These terrain sources use positions, normals, colors and optional UVs only.
		for slot in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			assert(arrays[slot] == null or arrays[slot].is_empty(), "Unsupported terrain attribute")
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var has_normals: bool = arrays[Mesh.ARRAY_NORMAL] != null and not arrays[Mesh.ARRAY_NORMAL].is_empty()
		var has_colors: bool = arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty()
		var has_uv: bool = arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty()
		var has_uv2: bool = arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty()
		var has_tangents: bool = arrays[Mesh.ARRAY_TANGENT] != null and not arrays[Mesh.ARRAY_TANGENT].is_empty()
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var emitted := 0
		for i in range(0, indices.size(), 3):
			var polygon: Array = []
			for j in 3:
				var index := indices[i+j]
				var tangent := Vector4(1,0,0,1)
				if has_tangents:
					var data: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
					tangent = Vector4(data[index*4],data[index*4+1],data[index*4+2],data[index*4+3])
				polygon.append([vertices[index], arrays[Mesh.ARRAY_NORMAL][index] if has_normals else Vector3.UP,
					arrays[Mesh.ARRAY_COLOR][index] if has_colors else Color.WHITE,
					arrays[Mesh.ARRAY_TEX_UV][index] if has_uv else Vector2.ZERO,
					arrays[Mesh.ARRAY_TEX_UV2][index] if has_uv2 else Vector2.ZERO, tangent])
			for plane in planes:
				polygon = clip_polygon(polygon, plane)
				if polygon.size() < 3: break
			for j in range(1, polygon.size()-1):
				if (polygon[j][0]-polygon[0][0]).cross(polygon[j+1][0]-polygon[0][0]).length_squared() == 0.0: continue
				for vertex in [polygon[0], polygon[j], polygon[j+1]]:
					if has_normals: builder.set_normal(vertex[1])
					if has_colors: builder.set_color(vertex[2])
					if has_uv: builder.set_uv(vertex[3])
					if has_uv2: builder.set_uv2(vertex[4])
					if has_tangents:
						var tangent: Vector4 = vertex[5]
						builder.set_tangent(Plane(Vector3(tangent.x,tangent.y,tangent.z).normalized(),tangent.w))
					builder.add_vertex(vertex[0])
				emitted += 3
		if emitted > 0:
			builder.set_material(source.surface_get_material(surface))
			builder.index()
			builder.commit(output)
	assert(output.get_surface_count() > 0, "Boundary unexpectedly removed the entire terrain")
	return output

static func clip_polygon(polygon: Array, plane: Plane) -> Array:
	var outside := 0
	for vertex in polygon:
		if plane.distance_to(vertex[0]) > 0.0: outside += 1
	if outside == 0: return polygon
	if outside == polygon.size(): return []
	var result: Array = []
	for i in polygon.size():
		var a: Array = polygon[i]
		var b: Array = polygon[(i+1)%polygon.size()]
		var da := plane.distance_to(a[0])
		var db := plane.distance_to(b[0])
		if da <= 0.0: result.append(a)
		if (da <= 0.0) != (db <= 0.0):
			var weight := da/(da-db)
			result.append([a[0].lerp(b[0], weight), a[1].lerp(b[1], weight).normalized(),
				a[2].lerp(b[2], weight), a[3].lerp(b[3], weight), a[4].lerp(b[4], weight), a[5].lerp(b[5], weight)])
	return result

extends SceneTree

# End both river promenades and their railings at the city-side bridge edge.
func clip_polygon(points: Array, plane: float, keep_less: bool) -> Array:
	var result: Array = []
	for i in points.size():
		var a: Array = points[i]
		var b: Array = points[(i+1)%points.size()]
		var inside_a: bool = a[0].z <= plane if keep_less else a[0].z >= plane
		var inside_b: bool = b[0].z <= plane if keep_less else b[0].z >= plane
		if inside_a: result.append(a)
		if inside_a != inside_b:
			var t: float = (plane-a[0].z)/(b[0].z-a[0].z)
			result.append([a[0].lerp(b[0],t), a[1].lerp(b[1],t).normalized(), a[2].lerp(b[2],t)])
	return result

func _initialize() -> void:
	var scene: Node = load("res://scenes/river_frontage.tscn").instantiate()
	for label in ["Rail", "Quay"]:
		var source: Mesh = scene.get_node(label).mesh
		var output := trim_mesh(source)
		var path := "res://assets/bridges/north_arch/river_railing.res" if label == "Rail" else "res://assets/bridges/north_arch/river_quay.res"
		assert(ResourceSaver.save(output,path) == OK)
		if label == "Quay":
			assert(ResourceSaver.save(output.create_trimesh_shape(),"res://assets/bridges/north_arch/river_quay_collision.res") == OK)
	scene.free()
	quit()

func trim_mesh(source: Mesh) -> ArrayMesh:
	var output := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,indices.size(),3):
			var triangle: Array = []
			for j in 3:
				var index := indices[i+j]
				triangle.append([vertices[index],normals[index],uvs[index]])
			for polygon in [clip_polygon(triangle,-946,false)]:
				for j in range(1,polygon.size()-1):
					for vertex in [polygon[0],polygon[j],polygon[j+1]]:
						builder.set_normal(vertex[1]); builder.set_uv(vertex[2]); builder.add_vertex(vertex[0])
		builder.set_material(source.surface_get_material(surface))
		builder.index()
		builder.commit(output)
	return output

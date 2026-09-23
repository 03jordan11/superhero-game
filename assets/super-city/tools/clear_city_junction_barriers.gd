extends SceneTree
## Trim only the highway furniture protruding into the northern city junction.
## Retain everything north of its curb; do not change outer road routing.
const DEST := "res://assets/super-city/traffic/"
const LIMIT := -974.0
func _initialize() -> void:
	var source: ArrayMesh = load("res://assets/city-life/meshes/highway_guardrails.res")
	var output := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if ids.is_empty(): ids = PackedInt32Array(range(vertices.size()))
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,ids.size(),3):
			var polygon: Array[Vector3] = [vertices[ids[i]],vertices[ids[i+1]],vertices[ids[i+2]]]
			var clipped: Array[Vector3] = []
			for j in polygon.size():
				var a := polygon[j]
				var b := polygon[(j+1)%polygon.size()]
				if a.z <= LIMIT: clipped.append(a)
				if (a.z<=LIMIT)!=(b.z<=LIMIT): clipped.append(a.lerp(b,(LIMIT-a.z)/(b.z-a.z)))
			for j in range(1,clipped.size()-1):
				var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][ids[i]]
				for v in [clipped[0],clipped[j],clipped[j+1]]:
					builder.set_normal(normal)
					builder.add_vertex(v)
		builder.index()
		builder.commit(output)
	assert(ResourceSaver.save(output,DEST+"junction_guardrails.res") == OK)
	assert(ResourceSaver.save(output.create_trimesh_shape(),DEST+"junction_guardrails_collision.res") == OK)
	var median := BoxMesh.new()
	median.size = Vector3(0.6,0.8,26.1)
	assert(ResourceSaver.save(median,DEST+"junction_median.res") == OK)
	var shape := BoxShape3D.new()
	shape.size = median.size
	assert(ResourceSaver.save(shape,DEST+"junction_median_collision.res") == OK)
	print("CITY_JUNCTION_BARRIERS: clipped to northern curb at Z=-974")
	quit()

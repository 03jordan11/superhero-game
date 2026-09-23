extends SceneTree
## Offline spatial partitioning. Clips triangles at tile borders; preserves UVs,
## normals and vertex colors. Source terrain and collision resources are untouched.
const OUTPUT := "res://assets/occlusion/terrain/"
const SOURCES := {
	"city_ground": ["res://assets/mountain-river/mouth/meshes/GroundMesh.res", 256.0],
	"northern_ground": ["res://assets/trees/boundary_terrain/city_northern.res", 1024.0],
	"coastal_terrain": ["res://assets/trees/boundary_terrain/city_coastal.res", 2048.0],
	"pine_pass_mountains": ["res://assets/city-life/meshes/pine_pass_mountains.res", 512.0],
}
func _initialize() -> void:
	build.call_deferred()

func interpolate(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result := {}
	for key in a: result[key] = a[key].lerp(b[key],weight)
	return result

func clip(poly: Array, axis: int, boundary: float, keep_greater: bool) -> Array:
	var result := []
	if poly.is_empty(): return result
	var previous: Dictionary = poly[-1]
	var previous_inside: bool = previous.p[axis] >= boundary if keep_greater else previous.p[axis] <= boundary
	for vertex: Dictionary in poly:
		var inside: bool = vertex.p[axis] >= boundary if keep_greater else vertex.p[axis] <= boundary
		if inside != previous_inside:
			var weight: float = (boundary-previous.p[axis])/(vertex.p[axis]-previous.p[axis])
			result.append(interpolate(previous,vertex,weight))
		if inside: result.append(vertex)
		previous = vertex
		previous_inside = inside
	return result

func build() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var report := {}
	for key: String in SOURCES:
		var path: String = SOURCES[key][0]
		var cell: float = SOURCES[key][1]
		var mesh := load(path) as ArrayMesh
		var tiles := {}
		var source_area := 0.0
		var result_area := 0.0
		var triangle_count := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			assert(arrays[Mesh.ARRAY_BONES] == null and arrays[Mesh.ARRAY_WEIGHTS] == null)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in positions.size(): indices.append(i)
			for start in range(0,indices.size(),3):
				var polygon := []
				for corner in 3:
					var index := indices[start+corner]
					var vertex := {"p":positions[index]}
					for attribute: Array in [["n",Mesh.ARRAY_NORMAL],["uv",Mesh.ARRAY_TEX_UV],["uv2",Mesh.ARRAY_TEX_UV2],["c",Mesh.ARRAY_COLOR]]:
						if arrays[attribute[1]] != null and not arrays[attribute[1]].is_empty(): vertex[attribute[0]] = arrays[attribute[1]][index]
					if arrays[Mesh.ARRAY_TANGENT] != null and not arrays[Mesh.ARRAY_TANGENT].is_empty():
						var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
						vertex.t = Vector4(t[index*4],t[index*4+1],t[index*4+2],t[index*4+3])
					polygon.append(vertex)
				source_area += (polygon[1].p-polygon[0].p).cross(polygon[2].p-polygon[0].p).length()*.5
				var bounds := AABB(polygon[0].p,Vector3.ZERO)
				for v: Dictionary in polygon: bounds = bounds.expand(v.p)
				for x in range(floori(bounds.position.x/cell),floori(bounds.end.x/cell)+1):
					for z in range(floori(bounds.position.z/cell),floori(bounds.end.z/cell)+1):
						var clipped := clip(polygon,0,x*cell,true)
						clipped = clip(clipped,0,(x+1)*cell,false)
						clipped = clip(clipped,2,z*cell,true)
						clipped = clip(clipped,2,(z+1)*cell,false)
						for i in range(1,clipped.size()-1):
							var tri := [clipped[0],clipped[i],clipped[i+1]]
							var area: float = (tri[1].p-tri[0].p).cross(tri[2].p-tri[0].p).length()*.5
							if area < .000001: continue
							# Boundary-aligned vertical faces belong to only one cell.
							var center: Vector3 = (tri[0].p+tri[1].p+tri[2].p)/3.0
							if bounds.size.x < .00001 and floori(center.x/cell)!=x: continue
							if bounds.size.z < .00001 and floori(center.z/cell)!=z: continue
							var tile := Vector2i(x,z)
							if not tiles.has(tile): tiles[tile] = {}
							if not tiles[tile].has(surface): tiles[tile][surface] = []
							tiles[tile][surface].append_array(tri)
							result_area += area
							triangle_count += 1
		var chunk_root := Node3D.new()
		chunk_root.name = "RenderChunks"
		chunk_root.set_meta("source_path",path)
		chunk_root.set_meta("source_sha256",FileAccess.get_sha256(path))
		for tile: Vector2i in tiles:
			var output_mesh := ArrayMesh.new()
			var source_surfaces := PackedInt32Array()
			for surface: int in tiles[tile]:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mesh.surface_get_material(surface))
				for vertex: Dictionary in tiles[tile][surface]:
					if vertex.has("n"): st.set_normal(vertex.n.normalized())
					if vertex.has("uv"): st.set_uv(vertex.uv)
					if vertex.has("uv2"): st.set_uv2(vertex.uv2)
					if vertex.has("c"): st.set_color(vertex.c)
					if vertex.has("t"): st.set_tangent(Plane(vertex.t.x,vertex.t.y,vertex.t.z,vertex.t.w))
					st.add_vertex(vertex.p)
				st.index()
				st.commit(output_mesh)
				source_surfaces.append(surface)
			var mi := MeshInstance3D.new()
			mi.name = "Tile_%d_%d" % [tile.x,tile.y]
			mi.mesh = output_mesh
			mi.set_meta("source_surfaces",source_surfaces)
			chunk_root.add_child(mi)
			mi.owner = chunk_root
		assert(absf(result_area-source_area)/maxf(source_area,1.0)<.00001,"Terrain area changed")
		var packed := PackedScene.new()
		assert(packed.pack(chunk_root)==OK)
		assert(ResourceSaver.save(packed,OUTPUT+key+".scn")==OK)
		report[key] = {"source":path,"sha256":FileAccess.get_sha256(path),"cell_metres":cell,"chunks":tiles.size(),"source_triangles":mesh.get_faces().size()/3,"render_triangles":triangle_count,"source_area":source_area,"result_area":result_area}
		print("TERRAIN_CHUNKS ",key," ",JSON.stringify(report[key]))
		chunk_root.free()
	FileAccess.open(OUTPUT+"audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit()

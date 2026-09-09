extends RefCounted
## One normalized car silhouette, built once and shared by every distant region.

static func build(body_height: float, cabin_width: float, cabin_length: float, cabin_offset: float, window_brightness: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := clampf(body_height,0.25,0.8)
	var width := clampf(cabin_width,0.4,1.0)
	var length := clampf(cabin_length,0.25,0.85)
	# Keep the cabin inside the unit bounds used for LOD sizing and culling.
	var offset := clampf(cabin_offset,-(1.0-length)*0.5,(1.0-length)*0.5)
	_append_box(tool,Vector3(1.0,height,1.0),Vector3(0,-0.5+height*0.5,0),false,window_brightness)
	_append_box(tool,Vector3(width,1.0-height,length),Vector3(0,height*0.5,offset),true,window_brightness)
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0,material)
	return mesh

static func _append_box(tool: SurfaceTool, size: Vector3, center: Vector3, cabin: bool, window_brightness: float) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var shade := clampf(window_brightness,0.0,1.0)
	for index in indices:
		var normal := normals[index]
		if cabin and normal.y < -0.5: continue # Hidden cabin floor needs no triangles.
		# Painted body and roof inherit the per-car tint; cabin sides become dark windows.
		tool.set_color(Color(shade,shade,shade) if cabin and absf(normal.y) < 0.5 else Color.WHITE)
		tool.set_normal(normal)
		tool.add_vertex(vertices[index]+center)

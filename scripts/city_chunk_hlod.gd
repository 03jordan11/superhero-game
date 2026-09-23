extends RefCounted
## New box/tier stand-ins: exactly ONE surface and material per chunk.
var originals: Array[GeometryInstance3D] = []
var original_visibility: Array[bool] = []
var proxies: Array[MeshInstance3D] = []
var far_active := false
var bounds := AABB()
var centre := Vector3.ZERO
var radius := 0.0
var source_surfaces := 0
var merged_surfaces := 0
var source_triangles := 0
var merged_triangles := 0
var proxy_boxes := 0
var chunk_name := ""

func build(chunk: Node3D, _near_distance: float, atlas: RefCounted) -> void:
	chunk_name = str(chunk.name)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var rooms := PackedVector2Array()
	var indices := PackedInt32Array()
	var started := false
	for building: Node3D in chunk.get_buildings():
		var meshes: Array[MeshInstance3D] = []
		for visual: GeometryInstance3D in building.find_children("*", "GeometryInstance3D", true, false):
			originals.append(visual)
			original_visibility.append(visual.visible)
			if not visual is MeshInstance3D or visual.mesh == null or not visual.is_visible_in_tree(): continue
			var box := visual.global_transform * visual.get_aabb()
			bounds = bounds.merge(box) if started else box
			started = true
			for surface in visual.mesh.get_surface_count():
				source_surfaces += 1
				source_triangles += _triangle_count(atlas.source_arrays(visual.mesh, surface))
			if building.scene_file_path.contains("generated-buildings") and visual != building.get_node("MeshInstance3D"): continue
			meshes.append(visual)
		var shapes := _structural_boxes(building, meshes, atlas)
		var key: Array = [building.scene_file_path, shapes]
		for mesh in meshes: key.append([mesh.mesh, building.global_transform.affine_inverse() * mesh.global_transform])
		if not atlas.proxy_recipes.has(key): atlas.proxy_recipes[key] = _make_faces(building, meshes, shapes, atlas)
		proxy_boxes += shapes.size()
		for face: Dictionary in atlas.proxy_recipes[key]:
			var material: Material = meshes[face.mesh].get_active_material(face.surface) if face.mesh >= 0 else atlas.fallback
			material = atlas.with_vertex_tint(material, face.tint)
			var slot: int = atlas.slot(material)
			var tag := Color(float(slot % 256) / 255, float(slot >> 8) / 255, 0, 1)
			var offset := vertices.size()
			for i in 4:
				vertices.append(building.global_transform * face.points[i])
				normals.append((building.global_basis.inverse().transposed() * face.normal).normalized())
				uvs.append(face.uv[i])
				rooms.append(face.uv2[i])
				colors.append(tag)
			# Godot front faces are clockwise; face axes are outward CCW.
			indices.append_array(PackedInt32Array([offset, offset + 2, offset + 1, offset, offset + 3, offset + 2]))
	if vertices.is_empty(): return
	for point in vertices: bounds = bounds.expand(point)
	centre = bounds.get_center()
	radius = bounds.size.length() * 0.5
	for i in vertices.size(): vertices[i] -= centre
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	for pair in [[Mesh.ARRAY_VERTEX, vertices], [Mesh.ARRAY_NORMAL, normals], [Mesh.ARRAY_COLOR, colors], [Mesh.ARRAY_TEX_UV, uvs], [Mesh.ARRAY_TEX_UV2, rooms], [Mesh.ARRAY_INDEX, indices]]: arrays[pair[0]] = pair[1]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, atlas.material)
	var proxy := MeshInstance3D.new()
	proxy.name = "DistantProxy"
	proxy.mesh = mesh
	proxy.visible = false
	chunk.add_child(proxy)
	proxy.global_position = centre
	proxies.append(proxy)
	merged_surfaces = 1
	merged_triangles = indices.size() / 3

func _structural_boxes(building: Node3D, meshes: Array[MeshInstance3D], atlas: RefCounted) -> Array:
	# Runtime collision optimization enlarges some boxes; use authored tiers.
	if building.scene_file_path.contains("generated-buildings"):
		if not atlas.authored_boxes.has(building.scene_file_path):
			var authored := load(building.scene_file_path).instantiate() as Node3D
			atlas.authored_boxes[building.scene_file_path] = _read_boxes(authored, true)
			authored.free()
		return atlas.authored_boxes[building.scene_file_path]
	var boxes := _read_boxes(building, false)
	# Open garages have slab colliders; use their complete exterior shell.
	if boxes.is_empty():
		var body := AABB()
		var first := true
		for mesh in meshes:
			var box := building.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			body = box if first else body.merge(box)
			first = false
		boxes.append(body)
	return boxes

func _read_boxes(building: Node3D, generated: bool) -> Array:
	var boxes := []
	for collider: CollisionShape3D in building.find_children("*", "CollisionShape3D", true, false):
		if not collider.shape is BoxShape3D: continue
		var path := str(building.get_path_to(collider))
		if generated and path.contains("/"): continue
		var size: Vector3 = collider.shape.size
		if size.x < 2 or size.z < 1 or size.y < 2 or size.x * size.z < 4: continue
		var local := Transform3D.IDENTITY
		var node: Node3D = collider
		while node != building:
			local = node.transform * local
			node = node.get_parent() as Node3D
		boxes.append(local * AABB(-size * 0.5, size))
	return boxes

func _make_faces(building: Node3D, meshes: Array[MeshInstance3D], boxes: Array, atlas: RefCounted) -> Array:
	var triangles := []
	for m in meshes.size():
		var transform := building.global_transform.affine_inverse() * meshes[m].global_transform
		for s in meshes[m].mesh.get_surface_count():
			var a: Array = atlas.source_arrays(meshes[m].mesh, s)
			var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var faces: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if faces.is_empty():
				for i in points.size(): faces.append(i)
			for i in range(0, faces.size(), 3):
				var p := PackedVector3Array([transform * points[faces[i]], transform * points[faces[i + 1]], transform * points[faces[i + 2]]])
				var cross := (p[2] - p[0]).cross(p[1] - p[0])
				if cross.length_squared() < 0.000001: continue
				var uv := PackedVector2Array()
				var uv2 := PackedVector2Array()
				var tint := Color(0, 0, 0, 0)
				for j in 3:
					uv.append(a[Mesh.ARRAY_TEX_UV][faces[i + j]] if a[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO)
					uv2.append(a[Mesh.ARRAY_TEX_UV2][faces[i + j]] if a[Mesh.ARRAY_TEX_UV2] != null else Vector2.ZERO)
					tint += a[Mesh.ARRAY_COLOR][faces[i + j]] / 3.0 if a[Mesh.ARRAY_COLOR] != null else Color.WHITE / 3.0
				triangles.append({"p": p, "normal": cross.normalized(), "area": cross.length() * 0.5, "uv": uv, "uv2": uv2, "tint": tint, "mesh": m, "surface": s})
	var result := []
	for box: AABB in boxes:
		# Five new quads per structural box; no source triangles are copied.
		for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
			var u := Vector3.FORWARD if absf(normal.x) > 0.5 else Vector3.RIGHT
			var v: Vector3 = normal.cross(u)
			var mid: Vector3 = box.get_center() + normal * box.size * 0.5
			var half_u: Vector3 = u * absf(u.dot(box.size)) * 0.5
			var half_v: Vector3 = v * absf(v.dot(box.size)) * 0.5
			var points := PackedVector3Array([mid - half_u - half_v, mid + half_u - half_v, mid + half_u + half_v, mid - half_u + half_v])
			var best := {}
			var score := -INF
			for tri: Dictionary in triangles:
				if tri.normal.dot(normal) < 0.9: continue
				var tc: Vector3 = (tri.p[0] + tri.p[1] + tri.p[2]) / 3.0
				var distance: float = absf((tc - mid).dot(normal))
				var vertical: float = maxf(box.position.y - tc.y, maxf(tc.y - box.end.y, 0.0))
				var candidate: float = tri.area / (1.0 + distance * distance + vertical * vertical)
				if candidate > score:
					score = candidate
					best = tri
			var uv := PackedVector2Array()
			var uv2 := PackedVector2Array()
			for p in points:
				var weights := _weights(p, best.p) if not best.is_empty() else Vector3(1, 0, 0)
				uv.append(best.uv[0] * weights.x + best.uv[1] * weights.y + best.uv[2] * weights.z if not best.is_empty() else Vector2.ZERO)
				uv2.append(best.uv2[0] * weights.x + best.uv2[1] * weights.y + best.uv2[2] * weights.z if not best.is_empty() else Vector2.ZERO)
			result.append({"points": points, "normal": normal, "uv": uv, "uv2": uv2, "tint": best.get("tint", Color.WHITE), "mesh": best.get("mesh", -1), "surface": best.get("surface", 0)})
	return result

func _weights(point: Vector3, triangle: PackedVector3Array) -> Vector3:
	var a := triangle[1] - triangle[0]
	var b := triangle[2] - triangle[0]
	var p := point - triangle[0]
	var divisor := a.dot(a) * b.dot(b) - a.dot(b) * a.dot(b)
	var y := (b.dot(b) * p.dot(a) - a.dot(b) * p.dot(b)) / divisor
	var z := (a.dot(a) * p.dot(b) - a.dot(b) * p.dot(a)) / divisor
	return Vector3(1 - y - z, y, z)

func _triangle_count(arrays: Array) -> int:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	return (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3

func update(camera_position: Vector3, near_distance: float, margin: float) -> void:
	var threshold := near_distance + radius + (0.0 if far_active else margin)
	set_far(camera_position.distance_to(centre) > threshold)

func set_far(value: bool) -> void:
	if far_active == value: return
	far_active = value
	for i in originals.size():
		if is_instance_valid(originals[i]): originals[i].visible = false if value else original_visibility[i]
	for proxy in proxies:
		if is_instance_valid(proxy): proxy.visible = value

func dispose() -> void:
	set_far(false)
	for proxy in proxies:
		if is_instance_valid(proxy): proxy.free()
	proxies.clear()
	originals.clear()
	original_visibility.clear()

func inventory() -> Dictionary:
	return {"chunk": chunk_name, "source_meshes": originals.size(), "source_surfaces": source_surfaces, "merged_surfaces": merged_surfaces, "source_triangles": source_triangles, "merged_triangles": merged_triangles, "proxy_boxes": proxy_boxes, "radius": radius, "centre": [centre.x, centre.y, centre.z], "far_active": far_active}

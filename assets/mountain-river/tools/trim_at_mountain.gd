extends SceneTree
# Subtract the volume below the original mountain surface from river meshes.
const OUT := "res://assets/mountain-river/terminated/"
func _initialize() -> void: run.call_deferred()
func clip(poly: Array, plane: Plane, inside: bool) -> Array:
	var result: Array = []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i+1)%poly.size()]
		var da := plane.distance_to(a[0])
		var db := plane.distance_to(b[0])
		var ia := da>=0 if inside else da<=0
		var ib := db>=0 if inside else db<=0
		if ia:result.append(a)
		if ia != ib:
			var t := da/(da-db)
			result.append([a[0].lerp(b[0],t),a[1].lerp(b[1],t).normalized(),a[2].lerp(b[2],t)])
	return result
func run() -> void:
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	var mountain: MeshInstance3D = city.get_node("CityLife/Highway/PinePassMountains")
	var transform := mountain.transform
	var parent := mountain.get_parent()
	while parent != city:
		transform = parent.transform * transform
		parent = parent.get_parent()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:city.get_node(label).free()
	root.add_child(city)
	mountain.get_node("Solid").collision_layer=1<<19
	await physics_frame
	await physics_frame
	var space := city.get_world_3d().direct_space_state
	var faces := mountain.mesh.get_faces()
	var cutters: Array = []
	for i in range(0,faces.size(),3):
		var vertices := [transform*faces[i],transform*faces[i+1],transform*faces[i+2]]
		var top: Vector3 = (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		if absf(top.y)<.00001:continue
		if top.y>0:top=-top
		var center: Vector3 = (vertices[0]+vertices[1]+vertices[2])/3
		var planes: Array[Plane] = []
		for j in 3:
			var edge: Vector3 = vertices[(j+1)%3]-vertices[j]
			var normal := Vector3(-edge.z,0,edge.x).normalized()
			if normal.dot(center-vertices[j])<0:normal=-normal
			planes.append(Plane(normal,normal.dot(vertices[j])))
		planes.append(Plane(top,top.dot(vertices[0])))
		var bounds := AABB(vertices[0],Vector3.ZERO)
		for v in vertices:bounds=bounds.expand(v)
		cutters.append([planes,Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)])
	var river: Node3D = load("res://scenes/mountain_river.tscn").instantiate()
	var audit := {}
	for label in ["Water","Rock","Bed"]:
		var node: MeshInstance3D = river.get_node(label)
		var output := ArrayMesh.new()
		var before := node.mesh.get_faces().size()/3
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for j in verts.size():indices.append(j)
			var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(0,indices.size(),3):
				var poly: Array = []
				var bounds := Rect2(Vector2(verts[indices[j]].x,verts[indices[j]].z),Vector2.ZERO)
				for k in 3:
					var index := indices[j+k]
					poly.append([verts[index],normals[index],uvs[index] if not uvs.is_empty() else Vector2.ZERO])
					bounds=bounds.expand(Vector2(verts[index].x,verts[index].z))
				var pieces: Array = [poly]
				for cutter in cutters:
					if not bounds.intersects(cutter[1],true):continue
					var remaining: Array = []
					for piece in pieces:
						var inside: Array = piece
						for plane in cutter[0]:
							var outside := clip(inside,plane,false)
							if outside.size()>=3:remaining.append(outside)
							inside=clip(inside,plane,true)
							if inside.size()<3:break
					pieces=remaining
				for piece in pieces:
					for k in range(1,piece.size()-1):
						if (piece[k][0]-piece[0][0]).cross(piece[k+1][0]-piece[0][0]).length_squared()<.000001:continue
						# Remove numerical boundary slivers still inside the solid collision.
						var center: Vector3 = (piece[0][0]+piece[k][0]+piece[k+1][0])/3
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,1500,center.z),Vector3(center.x,-500,center.z),1<<19))
						if not hit.is_empty() and center.y<hit.position.y-.02:continue
						for vertex in [piece[0],piece[k],piece[k+1]]:
							builder.set_normal(vertex[1]);builder.set_uv(vertex[2]);builder.add_vertex(vertex[0])
			builder.set_material(node.mesh.surface_get_material(surface));builder.index();builder.commit(output)
		node.mesh=output
		assert(ResourceSaver.save(output,OUT+label+".res")==OK)
		output.take_over_path(OUT+label+".res")
		if node.has_node("Solid/CollisionShape3D"):
			var shape := output.create_trimesh_shape()
			node.get_node("Solid/CollisionShape3D").shape=shape
			assert(ResourceSaver.save(shape,OUT+label+"_collision.res")==OK)
			shape.take_over_path(OUT+label+"_collision.res")
		audit[label]={"before":before,"after":output.get_faces().size()/3}
	var packed := PackedScene.new();assert(packed.pack(river)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/mountain_river.tscn")==OK)
	var file := FileAccess.open(OUT+"audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(audit,"  "));file.close()
	print("TRIMMED_RIVER: ",audit)
	river.free();city.free();quit()

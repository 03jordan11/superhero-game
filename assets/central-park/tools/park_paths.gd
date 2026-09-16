extends RefCounted
## Offline path intersections and terrain fitting; textures do not subdivide meshes.
const LAYOUT = preload("res://assets/central-park/tools/park_layout.gd")
const OUT := "res://assets/central-park/meshes/"
var ground_cells := {}
var ground_faces: PackedVector3Array
var occupied := {}
var coverage: Array[Dictionary] = []

func cell_bounds(poly: PackedVector2Array) -> Rect2i:
	var bounds := Rect2(poly[0],Vector2.ZERO)
	for p in poly: bounds = bounds.expand(p)
	var low := Vector2i((bounds.position/8.0).floor())
	var high := Vector2i((bounds.end/8.0).floor())
	return Rect2i(low,high-low+Vector2i.ONE)

func index_polygon(grid: Dictionary, poly: PackedVector2Array, id: int) -> void:
	var bounds := cell_bounds(poly)
	for z in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var key := Vector2i(x,z)
			if not grid.has(key): grid[key] = []
			grid[key].append(id)

func candidates(grid: Dictionary, poly: PackedVector2Array) -> Array:
	var found := {}
	var bounds := cell_bounds(poly)
	for z in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			for id in grid.get(Vector2i(x,z),[]): found[id] = true
	return found.keys()

func ground_polygon(id: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in 3: result.append(Vector2(ground_faces[id+i].x,ground_faces[id+i].z))
	return result

func plane_height(p: Vector2, id: int) -> float:
	var a := ground_faces[id]
	var normal := (ground_faces[id+1]-a).cross(ground_faces[id+2]-a)
	return a.y-(normal.x*(p.x-a.x)+normal.z*(p.y-a.z))/normal.y

static func nearest(p: Vector2, points: PackedVector2Array) -> Vector2:
	var result := points[0]
	var distance := INF
	for i in points.size()-1:
		var q := Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1])
		if q.distance_squared_to(p) < distance:
			distance = q.distance_squared_to(p)
			result = q
	return result

static func remove_collinear(poly: PackedVector2Array) -> PackedVector2Array:
	# Boolean clipping retains strip vertices on straight terrain edges.
	# Removing these sub-millimetre redundancies does not change the visible outline.
	var changed := true
	while changed and poly.size()>3:
		changed = false
		for i in poly.size():
			var a := poly[posmod(i-1,poly.size())]
			var b := poly[(i+1)%poly.size()]
			if poly[i].distance_to(Geometry2D.get_closest_point_to_segment(poly[i],a,b)) < .0001:
				poly.remove_at(i)
				changed = true
				break
	return poly

static func corrected_routes() -> Array[Dictionary]:
	var routes := LAYOUT.paths()
	var lake: PackedVector2Array = routes[1].points
	for route in routes:
		var p: PackedVector2Array = route.points
		if route.name in ["LakeApproach","WestLakeLink","NorthLakeLink","EastLakeLink"]:
			var target := nearest(p[-1],lake)
			# Stretch the final 15 m smoothly to the parent walk's centerline.
			var end := p[-1]
			for i in p.size(): p[i] += (target-end)*clampf(1.0-p[i].distance_to(end)/15.0,0,1)
		if route.name == "BridgeWestLink":
			p = LAYOUT.smooth([nearest(Vector2(-74,18),lake),Vector2(-57,18),Vector2(-48,18)],false)
		if route.name == "BridgeEastLink":
			p = LAYOUT.smooth([nearest(Vector2(133,18),lake),Vector2(120,18),Vector2(112,18)],false)
		if route.name.ends_with("HouseTrail"):
			var cabin: Vector2 = LAYOUT.CABINS[["WillowHouseTrail","BirchHouseTrail","MossHouseTrail"].find(route.name)]
			# Approach the ramp squarely instead of cutting across the cabin corner.
			var keep := PackedVector2Array()
			for point in p:
				if point.distance_to(cabin) > 24.0: keep.append(point)
			var side := signf(keep[-1].x-cabin.x)
			var tail := LAYOUT.smooth([keep[-1],cabin+Vector2(side*12,10),cabin+Vector2(side*6,14),cabin+Vector2(0,12),cabin+Vector2(0,8.0976)],false)
			keep.resize(keep.size()-1)
			keep.append_array(tail)
			p = keep
		if route.name.ends_with("Gate"):
			# Leave enough space after an oblique boundary cut for a convex first quad.
			var trimmed := PackedVector2Array([p[0]])
			for i in range(1,p.size()):
				if p[i].distance_to(p[0]) > 6.0: trimmed.append(p[i])
			p = trimmed
		route.points = p
	return routes

func strips(route: Dictionary) -> Array[PackedVector2Array]:
	var points: PackedVector2Array = route.points
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var closed := points[0].is_equal_approx(points[-1])
	for i in points.size():
		var previous := points[maxi(0,i-1)]
		var next := points[mini(points.size()-1,i+1)]
		if closed and (i==0 or i==points.size()-1):
			previous = points[-2]
			next = points[1]
		var tangent := (next-previous).normalized()
		if i==points.size()-1 and route.name.ends_with("HouseTrail"):
			tangent = Vector2(0,-1)
		var half_width := float(route.width)*.5
		if route.name.begins_with("Bridge"):
			half_width = lerpf(half_width,2.3,clampf(1.0-points[i].distance_to(points[-1])/9.0,0,1))
		var side := Vector2(-tangent.y,tangent.x)*half_width
		# Gates terminate on the park boundary, including the diagonal SW approach.
		var a := points[i]+side
		var b := points[i]-side
		if i==0 and route.name.ends_with("Gate"):
			if absf(points[0].y)==302:
				a += tangent*((points[0].y-a.y)/tangent.y)
				b += tangent*((points[0].y-b.y)/tangent.y)
			else:
				a += tangent*((points[0].x-a.x)/tangent.x)
				b += tangent*((points[0].x-b.x)/tangent.x)
		left.append(a)
		right.append(b)
	var result: Array[PackedVector2Array] = []
	for i in points.size()-1:
		result.append(PackedVector2Array([left[i],right[i],right[i+1],left[i+1]]))
	return result

func fitted_height(p: Vector2, ground_id: int, route: Dictionary) -> float:
	var ground_y := plane_height(p,ground_id)
	var y := ground_y+.025
	if route.name.ends_with("Gate"):
		var edge := minf(254-absf(p.x),302-absf(p.y))
		y = maxf(.03,ground_y+.025*clampf(edge/4.0,0,1))
	if route.name.ends_with("HouseTrail"):
		var end: Vector2 = route.points[-1]
		var cap := Geometry2D.get_closest_point_to_segment(p,end-Vector2(1.25,0),end+Vector2(1.25,0))
		y = lerpf(.15,y,clampf(p.distance_to(cap)/3.0,0,1))
	if route.name.begins_with("Bridge"):
		var end: Vector2 = route.points[-1]
		y = lerpf(LAYOUT.height(end)+.13,y,clampf(absf(p.x-end.x)/6.0,0,1))
	return maxf(ground_y,y)

func build(ground: Mesh) -> Dictionary:
	ground_faces = ground.get_faces()
	for id in range(0,ground_faces.size(),3): index_polygon(ground_cells,ground_polygon(id),id)
	var result := {}
	var mats := [make_material(false),make_material(true)]
	for route in corrected_routes():
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ground_pieces := {}
		for strip in strips(route):
			var pieces: Array[PackedVector2Array] = [strip]
			# First-authored main walks own intersections. Subtract their footprint,
			# instead of lifting competing strips and leaving visible overlap tails.
			for other in candidates(occupied,strip):
				var remaining: Array[PackedVector2Array] = []
				for piece in pieces: remaining.append_array(Geometry2D.clip_polygons(piece,coverage[other].polygon))
				pieces = remaining
			for piece in pieces:
				for ground_id in candidates(ground_cells,piece):
					for poly in Geometry2D.intersect_polygons(piece,ground_polygon(ground_id)):
						if not ground_pieces.has(ground_id): ground_pieces[ground_id] = []
						ground_pieces[ground_id].append(poly)
			index_polygon(occupied,strip,coverage.size())
			coverage.append({"name":route.name,"polygon":strip})
		for ground_id in ground_pieces:
			# Remove redundant cuts from the original three-metre strip sampling.
			# Only terrain facets and the actual path outline need vertices.
			var pieces: Array = ground_pieces[ground_id]
			var changed := true
			while changed:
				changed = false
				for a in pieces.size():
					for b in range(a+1,pieces.size()):
						var merged := Geometry2D.merge_polygons(pieces[a],pieces[b])
						if merged.size() == 1:
							pieces[a] = merged[0]
							pieces.remove_at(b)
							changed = true
							break
					if changed: break
			for raw: PackedVector2Array in pieces:
				var poly := remove_collinear(raw)
				var indices := Geometry2D.triangulate_polygon(poly)
				for i in range(0,indices.size(),3):
					var vertices: Array[Vector3] = []
					for j in 3:
						var p: Vector2 = poly[indices[i+j]]
						vertices.append(Vector3(p.x,fitted_height(p,ground_id,route),p.y))
					var normal := (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
					if normal.y < 0:
						vertices.reverse()
						normal = -normal
					for vertex in vertices:
						tool.set_normal(normal)
						tool.set_uv(Vector2(vertex.x,vertex.z)/4.0)
						tool.add_vertex(vertex)
		var mesh := tool.commit()
		assert(mesh != null,"Empty path: "+route.name)
		mesh.surface_set_material(0,mats[int(route.lit)])
		result[route.name] = mesh
	return result

func make_material(paved: bool) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = 8031 if paved else 9707
	noise.frequency = .045
	var image := Image.create(512,512,false,Image.FORMAT_RGB8)
	for y in 512:
		for x in 512:
			# Periodic noise blends seamlessly; all relief is color, with no displacement.
			var u := x/512.0
			var v := y/512.0
			var n := lerpf(lerpf(noise.get_noise_2d(x,y),noise.get_noise_2d(x-512,y),u),lerpf(noise.get_noise_2d(x,y-512),noise.get_noise_2d(x-512,y-512),u),v)
			var grain := sin(float(x*157+y*113))*sin(float(x*47-y*73))
			var base := Color("b2aa98") if paved else Color("8b785b")
			var variation := n*.12+grain*.035
			if paved:
				var row := y/256
				var seam_x := posmod(x+(row%2)*128,256)
				var seam_y := y%256
				variation += .018 if posmod(x/256+row,2)==0 else -.012
				if seam_x < 2 or seam_y < 2: variation -= .13
			elif grain > .78: variation += .10
			image.set_pixel(x,y,base.lightened(variation) if variation>=0 else base.darkened(-variation))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var file := OUT+("path_paving_albedo.res" if paved else "path_dirt_albedo.res")
	assert(ResourceSaver.save(texture,file)==OK)
	texture.take_over_path(file)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = .94
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat

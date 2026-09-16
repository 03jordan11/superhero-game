extends RefCounted
## Offline adaptive ground mesh. Preserve the original 4 m color pattern in a texture.
const LAYOUT = preload("res://assets/central-park/tools/park_layout.gd")
const TARGET_TRIANGLES := 23000
const GRID := Vector2i(127, 151)

static func point(p: Vector2) -> Vector3:
	var xz := Vector2(-254, -302) + p * 4.0
	return Vector3(xz.x, LAYOUT.height(xz), xz.y)

static func tiles(candidates: Array[Dictionary], split_count: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for i in candidates.size():
		var tile: Rect2i = candidates[i].tile
		if i < split_count:
			for z in range(tile.position.y, tile.end.y):
				for x in range(tile.position.x, tile.end.x):
					result.append(Rect2i(x,z,1,1))
		else:
			result.append(tile)
	return result

static func boundaries(patches: Array[Rect2i]) -> Array[PackedVector2Array]:
	var corners: Dictionary = {}
	for patch in patches:
		for p in [patch.position,Vector2i(patch.end.x,patch.position.y),patch.end,Vector2i(patch.position.x,patch.end.y)]:
			corners[p] = true
	var result: Array[PackedVector2Array] = []
	for patch in patches:
		var a := Vector2(patch.position)
		var c := Vector2(patch.end)
		var ring := [a,Vector2(c.x,a.y),c,Vector2(a.x,c.y)]
		var polygon := PackedVector2Array()
		for i in 4:
			var p: Vector2 = ring[i]
			var q: Vector2 = ring[(i+1)%4]
			polygon.append(p)
			if p.distance_to(q) > 1.5 and corners.has(Vector2i((p+q)*.5)):
				polygon.append((p+q)*.5)
		result.append(polygon)
	return result

static func count_triangles(polygons: Array[PackedVector2Array]) -> int:
	var result := 0
	for polygon in polygons:
		result += 2 if polygon.size() == 4 else polygon.size()
	return result

static func emit(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	var va := point(a)
	var vb := point(b)
	var vc := point(c)
	var normal := (vc-va).cross(vb-va).normalized()
	for p in [a,b,c]:
		tool.set_normal(normal)
		tool.set_uv(p / Vector2(GRID))
		tool.add_vertex(point(p))

static func build(rng: RandomNumberGenerator) -> Dictionary:
	# Consume exactly the original color RNG sequence, so trees retain their placements.
	var image := Image.create(GRID.x,GRID.y,false,Image.FORMAT_RGB8)
	for z in GRID.y:
		for x in GRID.x:
			var center := Vector2(-254,-302) + Vector2(x+.5,z+.5)*4.0
			var r := LAYOUT.lake_radius(center)
			var color := Color("526e3f").lerp(Color("648247"),rng.randf())
			if r < 1.19:
				color = Color("777b5d").lerp(Color("444c44"),clampf((1.15-r)*2.0,0.0,1.0))
			image.set_pixel(x,z,color)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,"res://assets/central-park/meshes/terrain_albedo.res") == OK)
	texture.take_over_path("res://assets/central-park/meshes/terrain_albedo.res")
	var candidates: Array[Dictionary] = []
	for z in range(0,GRID.y,2):
		for x in range(0,GRID.x,2):
			var tile := Rect2i(x,z,mini(2,GRID.x-x),mini(2,GRID.y-z))
			var a := Vector2(tile.position)
			var c := Vector2(tile.end)
			var ha := point(a).y
			var hb := point(Vector2(c.x,a.y)).y
			var hc := point(c).y
			var hd := point(Vector2(a.x,c.y)).y
			var error := 0.0
			for iz in 5:
				for ix in 5:
					var u := ix/4.0
					var v := iz/4.0
					var coarse := ha*(1-u)+hb*(u-v)+hc*v if u>=v else ha*(1-v)+hc*u+hd*(v-u)
					error = maxf(error,absf(point(a+(c-a)*Vector2(u,v)).y-coarse))
			candidates.append({"tile":tile,"error":error})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.error > b.error)
	# Split the most curved patches first; retain 8 m cells on gentler ground.
	var low := 0
	var high := candidates.size()
	while high-low > 1:
		var middle := (low+high)/2
		if count_triangles(boundaries(tiles(candidates,middle))) <= TARGET_TRIANGLES:
			low = middle
		else:
			high = middle
	var polygons := boundaries(tiles(candidates,low))
	var total := count_triangles(polygons)
	assert(total >= 19177 and total <= 25569,"Ground reduction must stay between one third and one half")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in polygons:
		if polygon.size() == 4:
			emit(tool,polygon[0],polygon[1],polygon[2])
			emit(tool,polygon[0],polygon[2],polygon[3])
		else:
			# Shared edge midpoints prevent cracks between 4 m and 8 m patches.
			var center := Vector2.ZERO
			for p in polygon: center += p
			center /= polygon.size()
			for i in polygon.size(): emit(tool,center,polygon[i],polygon[(i+1)%polygon.size()])
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = .88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mesh.surface_set_material(0,material)
	print("Adaptive ground: %d triangles, %d refined patches; largest unsplit sampled height error %.4f m" % [total,low,candidates[low].error])
	return {"mesh":mesh,"triangles":total,"max_unsplit_error":candidates[low].error}

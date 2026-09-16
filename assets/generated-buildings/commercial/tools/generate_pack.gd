extends SceneTree
## Offline asset builder. Assets 01 and 02 have revision builders and night lighting.
## Run: godot --headless --path . --script res://assets/generated-buildings/commercial/tools/generate_pack.gd

const OUT = "res://assets/generated-buildings/commercial/"
const NAMES = ["MERCER WORKS", "PORTMAN GROUP", "ALDER CAPITAL", "CIVIC EXCHANGE", "ASHFORD HOUSE", "NORTH QUAY", "BRYDEN MEDIA", "FULTON TRUST", "MASON PARTNERS", "WESTBRIDGE", "LARCH & CO", "UNION LEDGER", "RIVET STUDIOS", "HARBORLINE", "GRAYSON TRADE", "STERLING ANNEX", "VECTOR SYSTEMS", "HEXA NETWORK", "AXIOM LABS", "NOVA EXCHANGE"]
const STYLES = ["limestone", "dark_glass", "light_glass", "brick", "concrete", "bronze", "steel", "cyan_glass", "lobby"]
const WALL = ["a69e8a", "354147", "839597", "785348", "99988e", "655d4e", "777f81", "3c555b", "575b58"]
const GLASS = ["38464c", "536a73", "5c7985", "353e43", "414f56", "393f40", "364a57", "507a83", "30434c"]
const SOLIDS = {"roof":"535656", "trim":"9b988c", "metal":"424b50", "accent":"698f91"}

var materials: Dictionary = {}
var surfaces: Dictionary = {}
var manifest: Array = []

func _initialize() -> void:
	for folder in ["materials", "textures", "meshes", "tools", "previews"]:
		DirAccess.make_dir_recursive_absolute(OUT + folder)
	make_materials()
	# Keep the hand-revised asset and its metadata when regenerating the older pack.
	# Rebuild 01/02 explicitly with their revise_skyscraper scripts if needed.
	var existing: Array = JSON.parse_string(FileAccess.get_file_as_string(OUT + "manifest.json"))
	var designs = get_designs()
	for i in range(designs.size()):
		if existing.size() > i and existing[i].has("hvac_triangles") and FileAccess.file_exists(OUT + "commercial_skyscraper_%02d.tscn" % (i + 1)):
			manifest.append(existing[i])
			continue
		make_building(i, designs[i])
	var file = FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	print("Generated %d commercial PackedScenes." % manifest.size())
	quit()

func get_designs() -> Array:
	# Each tier: width, depth, top elevation, facade, optional X/Z offset, corner cut.
	return [
		[[22,20,6,0], [20,18,132,0], [17,15,136,4]],
		[[32,23,8,4], [30,21,104,1], [26,18,110,6]],
		[[26,26,7,0], [24,24,155,2], [20,20,160,6]],
		[[30,24,20,0], [26,21,92,0], [21,17,136,0], [15,13,158,5]],
		[[28,24,7,3], [28,24,68,3], [24,20,78,0]],
		[[32,24,16,4], [22,19,124,2,3,1], [18,16,130,6,3,1]],
		[[20,24,7,4], [18,22,170,6], [15,18,178,1]],
		[[30,25,14,0], [26,21,68,3], [22,18,104,3], [17,14,126,0], [11,10,140,0]],
		[[32,20,6,4], [30,18,82,4], [25,16,88,6]],
		[[28,26,8,5], [26,24,148,5,0,0,3], [22,20,156,1,0,0,3]],
		[[22,22,6,0], [20,20,110,0], [16,16,126,0], [10,10,138,5]],
		[[32,24,10,0], [28,20,100,4], [22,20,126,4,-3,0], [15,17,148,6,-5,0]],
		[[26,24,6,3], [24,22,60,3], [20,18,72,6]],
		[[28,26,12,4], [24,22,188,2,0,0,4], [20,18,202,6,0,0,3]],
		[[32,24,8,0], [30,22,88,5], [24,20,96,0]],
		[[18,22,6,0], [16,20,116,4], [14,18,122,1]],
		[[30,24,14,6], [24,20,176,1,0,0,3], [19,16,190,7,0,0,2]],
		[[28,26,10,4], [25,23,146,7,0,0,5], [21,19,166,6,0,0,4]],
		[[30,24,18,6], [24,19,112,1], [20,17,192,7,2,0], [14,13,210,6,3,0]],
		[[28,24,12,0], [24,20,162,6], [20,18,210,1], [14,13,238,7]]
	]

func save(resource: Resource, path: String) -> void:
	var error = ResourceSaver.save(resource, path)
	assert(error == OK, "Could not save " + path)
	resource.take_over_path(path)

func make_materials() -> void:
	for i in range(STYLES.size()):
		var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
		var wall = Color(WALL[i])
		var glass = Color(GLASS[i])
		img.fill(wall)
		# Four bays / four floors per tile; no per-window geometry.
		for y in range(64):
			for x in range(64):
				var px = x % 16
				var py = y % 16
				var c = wall
				if i == 3 and (y % 4 == 0 or (x + (int(y / 4) % 2) * 4) % 8 == 0):
					c = wall.darkened(0.13)
				var left = 3 if i in [0,3,4] else 1
				var bottom = 11 if i in [0,3,4,5] else 14
				if px >= left and px < 15 - left and py >= 2 and py <= bottom:
					var variation = float((int(x / 16) * 7 + int(y / 16) * 3 + i) % 5) * 0.027
					c = glass.lightened(variation)
					if px == left or py == 2:
						c = c.lightened(0.12)
					if px == 8 and i in [0,3,4,8]:
						c = wall.darkened(0.3)
				if py == 15:
					c = wall.darkened(0.28)
				if i == 6 and px in [0,1,15]:
					c = wall.lightened(0.17)
				img.set_pixel(x,y,c)
		img.generate_mipmaps()
		var tex = ImageTexture.create_from_image(img)
		save(tex, OUT + "textures/" + STYLES[i] + ".res")
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.roughness = 0.87
		save(mat, OUT + "materials/" + STYLES[i] + ".tres")
		materials[STYLES[i]] = mat
	# All untextured roof/trim/mechanical colors share one surface and material.
	var solid = StandardMaterial3D.new()
	solid.vertex_color_use_as_albedo = true
	solid.vertex_color_is_srgb = true
	solid.roughness = 0.92
	save(solid, OUT + "materials/solid.tres")
	materials["solid"] = solid
	make_signs()

func make_signs() -> void:
	var glyphs = {
		"A":"01110100011000111111100011000110001", "B":"11110100011000111110100011000111110",
		"C":"01111100001000010000100001000001111", "D":"11110100011000110001100011000111110",
		"E":"11111100001000011110100001000011111", "F":"11111100001000011110100001000010000",
		"G":"01111100001000010111100011000101111", "H":"10001100011000111111100011000110001",
		"I":"11111001000010000100001000010011111", "J":"00111000100001000010100101001001100",
		"K":"10001100101010011000101001001010001", "L":"10000100001000010000100001000011111",
		"M":"10001110111010110101100011000110001", "N":"10001110011010110011100011000110001",
		"O":"01110100011000110001100011000101110", "P":"11110100011000111110100001000010000",
		"Q":"01110100011000110001101011001001101", "R":"11110100011000111110101001001010001",
		"S":"01111100001000001110000010000111110", "T":"11111001000010000100001000010000100",
		"U":"10001100011000110001100011000101110", "V":"10001100011000110001100010101000100",
		"W":"10001100011000110101101011101110001", "X":"10001100010101000100010101000110001",
		"Y":"10001100010101000100001000010000100", "Z":"11111000010001000100010001000011111",
		"&":"01100100101010001000101011001001101"
	}
	var img = Image.create(256,256,false,Image.FORMAT_RGB8)
	img.fill(Color("232c32"))
	for i in range(20):
		var origin = Vector2i((i % 2) * 128, int(i / 2) * 24)
		var ink = Color("b4c9c9") if i >= 16 else Color("cdc5b0")
		img.fill_rect(Rect2i(origin + Vector2i(5,5),Vector2i(7,14)),ink)
		img.fill_rect(Rect2i(origin + Vector2i(7,7),Vector2i(3,10)),Color("3c5156"))
		for j in range(NAMES[i].length()):
			var letter = NAMES[i][j]
			if not glyphs.has(letter):
				continue
			for py in range(7):
				for px in range(5):
					if glyphs[letter][py * 5 + px] == "1":
						img.set_pixel(origin.x+17+j*6+px,origin.y+8+py,ink)
	# Lower strip: paired lobby doors, metal frames and handles.
	img.fill_rect(Rect2i(0,240,64,16), Color("283b43"))
	for x in [1,30,33,62]:
		img.fill_rect(Rect2i(x,241,1,14),Color("a6a99f"))
	for x in [26,37]:
		img.fill_rect(Rect2i(x,248,1,4),Color("c4c3b3"))
	img.fill_rect(Rect2i(0,240,64,1),Color("b6b8ae"))
	img.generate_mipmaps()
	var tex = ImageTexture.create_from_image(img)
	save(tex,OUT+"textures/signs_and_doors.res")
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	save(mat,OUT+"materials/signs_and_doors.tres")
	materials["signs_and_doors"] = mat

func quad(points: Array, uv: Array, material: String, normal: Vector3) -> void:
	var color = Color.WHITE
	if SOLIDS.has(material):
		color = Color(SOLIDS[material])
		material = "solid"
	if not surfaces.has(material):
		surfaces[material] = [PackedVector3Array(),PackedVector3Array(),PackedVector2Array(),PackedColorArray()]
	var data: Array = surfaces[material]
	# Godot uses clockwise winding viewed from the outside.
	var indices = [0,1,2] if points[0] == points[3] else [0,1,2,0,2,3]
	for index in indices:
		data[0].append(points[index])
		data[1].append(normal)
		data[2].append(uv[index])
		data[3].append(color)

func prism(w: float, d: float, bottom: float, top: float, facade: String, offset := Vector2.ZERO, cut := 0.0) -> void:
	var ring: Array[Vector2] = []
	if cut > 0:
		ring.assign([Vector2(-w/2+cut,-d/2),Vector2(w/2-cut,-d/2),Vector2(w/2,-d/2+cut),Vector2(w/2,d/2-cut),Vector2(w/2-cut,d/2),Vector2(-w/2+cut,d/2),Vector2(-w/2,d/2-cut),Vector2(-w/2,-d/2+cut)])
	else:
		ring.assign([Vector2(-w/2,-d/2),Vector2(w/2,-d/2),Vector2(w/2,d/2),Vector2(-w/2,d/2)])
	for i in range(ring.size()):
		var a = ring[i] + offset
		var b = ring[(i+1)%ring.size()] + offset
		var length = a.distance_to(b)
		var normal = Vector3(b.y-a.y,0,a.x-b.x).normalized()
		var u = maxf(1.0,roundf(length / 2.7)) / 4.0
		var v = maxf(1.0,roundf((top-bottom) / 3.8)) / 4.0
		quad([Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y)], [Vector2(0,v),Vector2(u,v),Vector2(u,0),Vector2.ZERO],facade,normal)
		var center = Vector3(offset.x,top,offset.y)
		quad([center,Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),center], [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],"roof",Vector3.UP)
		if bottom == 0.0:
			quad([Vector3(offset.x,0,offset.y),Vector3(b.x,0,b.y),Vector3(a.x,0,a.y),Vector3(offset.x,0,offset.y)], [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],"roof",Vector3.DOWN)

func sign_quad(w: float, bottom: float, height: float, depth: float, region: Rect2) -> void:
	# Outside viewers on -Z see increasing world X toward their left.
	var uv = [region.end,Vector2(region.position.x,region.end.y),region.position,Vector2(region.end.x,region.position.y)]
	quad([Vector3(-w/2,bottom,-depth/2-0.02),Vector3(w/2,bottom,-depth/2-0.02),Vector3(w/2,bottom+height,-depth/2-0.02),Vector3(-w/2,bottom+height,-depth/2-0.02)],uv,"signs_and_doors",Vector3.FORWARD)
	quad([Vector3(w/2,bottom,depth/2+0.02),Vector3(-w/2,bottom,depth/2+0.02),Vector3(-w/2,bottom+height,depth/2+0.02),Vector3(w/2,bottom+height,depth/2+0.02)],uv,"signs_and_doors",Vector3.BACK)

func make_building(index: int, tiers: Array) -> void:
	surfaces.clear()
	var bottom = 0.0
	for j in range(tiers.size()):
		var t: Array = tiers[j]
		var offset = Vector2(t[4],t[5]) if t.size() > 4 else Vector2.ZERO
		var cut = float(t[6]) if t.size() > 6 else 0.0
		var facade: String = STYLES[t[3]]
		if j == 0:
			prism(t[0],t[1],0,4.2,"lobby")
			bottom = 4.2
		prism(t[0],t[1],bottom,t[2]-0.6,facade,offset,cut)
		prism(t[0],t[1],t[2]-0.6,t[2],"accent" if index >= 16 else "trim",offset,cut)
		bottom = t[2]
	var last: Array = tiers[-1]
	var last_offset = Vector2(last[4],last[5]) if last.size() > 4 else Vector2.ZERO
	prism(last[0]*0.43,last[1]*0.46,bottom,bottom+3.2,"metal",last_offset)
	# A single flat plaque on each street-facing side; all signs remain in the mesh.
	sign_quad(10,4.35,1.5,tiers[0][1],Rect2(float(index%2)*0.5+0.5/256.0,float(int(index/2)*24)/256.0+0.5/256.0,127.0/256.0,23.0/256.0))
	sign_quad(3.4,0.08,3.5,tiers[0][1],Rect2(0.5/256.0,240.5/256.0,63.0/256.0,15.0/256.0))
	var mesh = ArrayMesh.new()
	var triangles = 0
	for key in surfaces:
		var data: Array = surfaces[key]
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data[0]
		arrays[Mesh.ARRAY_NORMAL] = data[1]
		arrays[Mesh.ARRAY_TEX_UV] = data[2]
		arrays[Mesh.ARRAY_COLOR] = data[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,materials[key])
		triangles += int(data[0].size()/3)
	var slug = "commercial_skyscraper_%02d" % (index+1)
	save(mesh,OUT+"meshes/"+slug+".res")
	var body = StaticBody3D.new()
	body.name = slug
	var visual = MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = mesh
	body.add_child(visual)
	visual.owner = body
	var bounds = mesh.get_aabb()
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape = BoxShape3D.new()
	shape.size = bounds.size
	collision.shape = shape
	collision.position = bounds.get_center()
	body.add_child(collision)
	collision.owner = body
	var packed = PackedScene.new()
	assert(packed.pack(body) == OK)
	save(packed,OUT+slug+".tscn")
	manifest.append({"scene":slug+".tscn","name":NAMES[index],"width_m":bounds.size.x,"depth_m":bounds.size.z,"height_m":bounds.size.y,"triangles":triangles,"surfaces":mesh.get_surface_count(),"future_inspired":index>=16})
	body.free()

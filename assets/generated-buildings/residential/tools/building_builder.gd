extends RefCounted
## Offline mesh/texture helpers shared only by the two district generators.
## PackedScenes depend exclusively on resources inside their own district folder.
const FONT = preload("res://assets/generated-buildings/residential/tools/pixel_font.gd")
const SOLID_COLORS = {"roof":"494c4b", "stone":"a49d8e", "dark":"353e42", "metal":"737c7c", "rust":"785047", "glass":"657f87", "wood":"6e6250", "stripe":"b1a06c"}
var out: String
var district: String
var names: Array
var materials: Dictionary = {}
var surfaces: Dictionary = {}
var catalog: Array = []
var floor_height = 3.1

func _init(folder: String, category: String, labels: Array) -> void:
	out = folder
	district = category
	names = labels
	floor_height = 3.1 if district == "residential" else 4.0
	for subfolder in ["materials", "textures", "meshes", "previews"]:
		DirAccess.make_dir_recursive_absolute(out + subfolder)

func save(resource: Resource, path: String) -> void:
	var error = ResourceSaver.save(resource,path)
	assert(error == OK, "Failed saving " + path)
	resource.take_over_path(path)

func make_materials(palette: Array) -> void:
	for definition in palette:
		var key: String = definition[0]
		var wall = Color(definition[1])
		var glass = Color(definition[2])
		var pattern: String = definition[3]
		var img = Image.create(64,64,false,Image.FORMAT_RGB8)
		for y in range(64):
			for x in range(64):
				var px = x % 16
				var py = y % 16
				var c = wall
				if pattern in ["brick", "tenement", "factory", "blank_brick"]:
					if y % 4 == 0 or (x + (int(y/4)%2)*4)%8 == 0:
						c = wall.darkened(0.16)
				elif pattern in ["cladding", "warehouse"]:
					if x % 4 == 0:
						c = wall.darkened(0.17)
				elif pattern == "stone" and (py == 0 or (px == 0 and py > 1)):
					c = wall.darkened(0.12)
				var window = px >= 4 and px <= 11 and py >= 3 and py <= 12
				if pattern == "factory":
					window = px >= 2 and px <= 13 and py >= 3 and py <= 12
				elif pattern == "modern":
					window = px >= 2 and px <= 13 and py >= 2 and py <= 13
				elif pattern in ["warehouse", "cladding"]:
					window = px >= 3 and px <= 12 and py >= 3 and py <= 6
				elif pattern == "blank_brick":
					window = false
				if window:
					var variant = (int(x/16)*3 + int(y/16)*5) % 7
					c = glass.lightened(float(variant)*0.018)
					if district == "residential" and variant == 1 and px >= 8:
						c = Color("9e9d8e") # Curtains, not emissive lighting.
					if px == 4 or py == 3:
						c = wall.lightened(0.13)
					if px == 8 or (py == 8 and pattern in ["factory", "tenement", "brick"]):
						c = wall.darkened(0.33)
				if py == 13 and pattern in ["brick", "tenement", "stone"] and px >= 3 and px <= 12:
					c = wall.lightened(0.22) # Painted lintel/sill, not separate geometry.
				if pattern == "tenement" and int(x/16)%2 == 0 and py in [14,15] and px >= 5 and px <= 10:
					c = Color("6a7270") if py == 14 else Color("3c4445") # Tiny window AC.
				img.set_pixel(x,y,c)
		texture_material(key,img)
	var solid = StandardMaterial3D.new()
	solid.vertex_color_use_as_albedo = true
	solid.vertex_color_is_srgb = true
	solid.roughness = 0.94
	save(solid,out+"materials/solid.tres")
	materials["solid"] = solid
	make_sign_atlas()

func texture_material(key: String, img: Image) -> void:
	img.generate_mipmaps()
	var texture = ImageTexture.create_from_image(img)
	save(texture,out+"textures/"+key+".res")
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.9
	save(material,out+"materials/"+key+".tres")
	materials[key] = material

func make_sign_atlas() -> void:
	var img = Image.create(256,256,false,Image.FORMAT_RGB8)
	img.fill(Color("2c3639"))
	var glyphs: Dictionary = FONT.glyphs()
	for i in range(names.size()):
		var origin = Vector2i((i%2)*128,int(i/2)*20)
		var ink = Color("c4b898") if district == "residential" else Color("cec2a0")
		img.fill_rect(Rect2i(origin+Vector2i(3,4),Vector2i(5,12)),ink)
		for j in range(names[i].length()):
			var letter: String = names[i][j]
			if not glyphs.has(letter):
				continue
			for py in range(7):
				for px in range(5):
					if glyphs[letter][py*5+px] == "1":
						img.set_pixel(origin.x+13+j*6+px,origin.y+6+py,ink)
	# Entry door and industrial roller shutter tiles, each 64 x 48 pixels.
	img.fill_rect(Rect2i(0,208,64,48),Color("493e34") if district == "residential" else Color("454f51"))
	for x in [2,30,33,61]:
		img.fill_rect(Rect2i(x,210,1,44),Color("aeab99"))
	for x in [5,36]:
		img.fill_rect(Rect2i(x,213,23,16),Color("35474e"))
	for x in [25,38]:
		img.fill_rect(Rect2i(x,232,1,8),Color("c1b592"))
	for y in range(208,256):
		for x in range(64,128):
			var c = Color("6a716f") if y%4 != 0 else Color("444d4e")
			if x <= 67 or x >= 124:
				c = Color("a29263") if (x+y)%12 < 6 else Color("343a39")
			img.set_pixel(x,y,c)
	texture_material("signs_and_doors",img)

func begin() -> void:
	surfaces.clear()

func face(points: Array, uv: Array, material: String, normal: Vector3) -> void:
	var color = Color.WHITE
	if SOLID_COLORS.has(material):
		color = Color(SOLID_COLORS[material])
		material = "solid"
	if not surfaces.has(material):
		surfaces[material] = [PackedVector3Array(),PackedVector3Array(),PackedVector2Array(),PackedColorArray()]
	var data: Array = surfaces[material]
	var indices = [0,1,2] if points.size() == 3 else [0,1,2,0,2,3]
	for i in indices:
		data[0].append(points[i])
		data[1].append(normal)
		data[2].append(uv[i])
		data[3].append(color)

func box(w: float, d: float, bottom: float, top: float, material: String, offset := Vector2.ZERO, cap_material := "roof") -> void:
	var ring = [Vector2(-w/2,-d/2),Vector2(w/2,-d/2),Vector2(w/2,d/2),Vector2(-w/2,d/2)]
	for i in range(4):
		var a: Vector2 = ring[i]+offset
		var b: Vector2 = ring[(i+1)%4]+offset
		var u = maxf(1,roundf(a.distance_to(b)/2.6))/4.0
		var v = maxf(1,roundf((top-bottom)/floor_height))/4.0
		face([Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y)],[Vector2(0,v),Vector2(u,v),Vector2(u,0),Vector2.ZERO],material,Vector3(b.y-a.y,0,a.x-b.x).normalized())
	var a = Vector3(-w/2+offset.x,top,-d/2+offset.y)
	var b = Vector3(w/2+offset.x,top,-d/2+offset.y)
	var c = Vector3(w/2+offset.x,top,d/2+offset.y)
	var e = Vector3(-w/2+offset.x,top,d/2+offset.y)
	face([a,b,c,e],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN],cap_material,Vector3.UP)
	if bottom == 0:
		a.y = bottom
		b.y = bottom
		c.y = bottom
		e.y = bottom
		face([e,c,b,a],[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],cap_material,Vector3.DOWN)

func band(w: float, d: float, y: float, material := "stone", offset := Vector2.ZERO, thickness := 0.28) -> void:
	# A thin stone/metal edge with a dark roof membrane above it.
	box(w,d,y,y+thickness,material,offset,"roof")

func gable(w: float, d: float, y: float, rise: float, material := "roof", offset := Vector2.ZERO) -> void:
	var a = Vector3(-w/2+offset.x,y,-d/2+offset.y)
	var b = Vector3(w/2+offset.x,y,-d/2+offset.y)
	var c = Vector3(w/2+offset.x,y,d/2+offset.y)
	var e = Vector3(-w/2+offset.x,y,d/2+offset.y)
	var f = Vector3(offset.x,y+rise,-d/2+offset.y)
	var g = Vector3(offset.x,y+rise,d/2+offset.y)
	face([a,b,f],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE],material,Vector3.FORWARD)
	face([c,e,g],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE],material,Vector3.BACK)
	face([a,f,g,e],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN],material,Vector3(-rise,w/2,0).normalized())
	face([f,b,c,g],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN],material,Vector3(rise,w/2,0).normalized())

func saw_roof(w: float, d: float, y: float, rise: float, bays: int) -> void:
	var step = w/float(bays)
	for i in range(bays):
		var x = -w/2+i*step
		var a = Vector3(x,y,-d/2)
		var b = Vector3(x+step,y,-d/2)
		var c = Vector3(x+step,y+rise,-d/2)
		var e = Vector3(x,y,d/2)
		var f = Vector3(x+step,y,d/2)
		var g = Vector3(x+step,y+rise,d/2)
		face([a,b,c],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE],"metal",Vector3.FORWARD)
		face([f,e,g],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE],"metal",Vector3.BACK)
		face([a,c,g,e],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN],"roof",Vector3(-rise,step,0).normalized())
		face([c,b,f,g],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN],"glass",Vector3.RIGHT)

func cylinder(radius: float, bottom: float, top: float, material: String, offset := Vector2.ZERO, top_radius := -1.0, segments := 8) -> void:
	if top_radius < 0:
		top_radius = radius
	for i in range(segments):
		var angle_a = TAU*i/segments
		var angle_b = TAU*(i+1)/segments
		var a = Vector3(cos(angle_a)*radius+offset.x,bottom,sin(angle_a)*radius+offset.y)
		var b = Vector3(cos(angle_b)*radius+offset.x,bottom,sin(angle_b)*radius+offset.y)
		var c = Vector3(cos(angle_b)*top_radius+offset.x,top,sin(angle_b)*top_radius+offset.y)
		var e = Vector3(cos(angle_a)*top_radius+offset.x,top,sin(angle_a)*top_radius+offset.y)
		var normal = -(b-a).cross(c-a).normalized()
		face([a,b,c,e],[Vector2(0,1),Vector2(1,1),Vector2.RIGHT,Vector2.ZERO],material,normal)
		face([Vector3(offset.x,top,offset.y),e,c],[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],material,Vector3.UP)

func plaque(width: float, bottom: float, height: float, depth: float, rect: Rect2, x := 0.0, back := false) -> void:
	var z = depth/2+0.025
	var uv = [rect.end,Vector2(rect.position.x,rect.end.y),rect.position,Vector2(rect.end.x,rect.position.y)]
	face([Vector3(x-width/2,bottom,-z),Vector3(x+width/2,bottom,-z),Vector3(x+width/2,bottom+height,-z),Vector3(x-width/2,bottom+height,-z)],uv,"signs_and_doors",Vector3.FORWARD)
	if back:
		face([Vector3(x+width/2,bottom,z),Vector3(x-width/2,bottom,z),Vector3(x-width/2,bottom+height,z),Vector3(x+width/2,bottom+height,z)],uv,"signs_and_doors",Vector3.BACK)

func sign(index: int, depth: float, y: float, width: float, x := 0.0) -> void:
	var rect = Rect2(float(index%2)*0.5+0.5/256.0,float(int(index/2)*20)/256.0+0.5/256.0,127.0/256.0,19.0/256.0)
	plaque(width,y,width*0.15,depth,rect,x,true)

func door(depth: float, x := 0.0, y := 0.04, width := 1.6, height := 2.6, shutter := false) -> void:
	var rect = Rect2((64.5 if shutter else 0.5)/256.0,208.5/256.0,63.0/256.0,47.0/256.0)
	plaque(width,y,height,depth,rect,x,true)

func stoop(depth: float, x := 0.0) -> void:
	for i in range(3):
		box(2.0,1.35-float(i)*0.35,float(i)*0.24,float(i+1)*0.24,"stone",Vector2(x,-depth/2-0.55+float(i)*0.15),"stone")

func water_tank(roof_y: float, offset := Vector2.ZERO) -> void:
	box(3.2,3.2,roof_y,roof_y+0.8,"dark",offset,"dark")
	cylinder(1.45,roof_y+0.8,roof_y+3.6,"wood",offset)
	cylinder(1.58,roof_y+3.6,roof_y+4.4,"metal",offset,0.22)

func finish(index: int, description: String) -> void:
	# Bake the horizontal AABB center into vertices, preserving Y=0 and unit transforms.
	var bounds = AABB()
	var first = true
	for key in surfaces:
		for point in surfaces[key][0]:
			if first:
				bounds = AABB(point,Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	var shift = Vector3(bounds.get_center().x,0,bounds.get_center().z)
	var mesh = ArrayMesh.new()
	var triangles = 0
	for key in surfaces:
		var data: Array = surfaces[key]
		for v in range(data[0].size()):
			data[0][v] -= shift
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data[0]
		arrays[Mesh.ARRAY_NORMAL] = data[1]
		arrays[Mesh.ARRAY_TEX_UV] = data[2]
		arrays[Mesh.ARRAY_COLOR] = data[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,materials[key])
		triangles += int(data[0].size()/3)
	var slug = "%s_building_%02d" % [district,index+1]
	save(mesh,out+"meshes/"+slug+".res")
	var body = StaticBody3D.new()
	body.name = slug
	var visual = MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = mesh
	body.add_child(visual)
	visual.owner = body
	bounds = mesh.get_aabb()
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
	save(packed,out+slug+".tscn")
	catalog.append({"scene":slug+".tscn","name":names[index],"design":description,"width_m":bounds.size.x,"depth_m":bounds.size.z,"height_m":bounds.size.y,"triangles":triangles,"surfaces":mesh.get_surface_count()})
	body.free()

func save_catalog() -> void:
	var file = FileAccess.open(out+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog,"\t"))
	print("Generated %d %s PackedScenes." % [catalog.size(),district])

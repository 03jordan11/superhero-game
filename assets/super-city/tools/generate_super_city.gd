extends SceneTree
## Offline authoring of a fixed 3 x 2 km city. No City Crafter/runtime generation.
const MeshBuilder = preload("res://assets/super-city/tools/city_mesh.gd")
const OUT = "res://assets/super-city/"
const SCENE = "res://scenes/super_city.tscn"
const XS = [-1460,-1280,-1100,-920,-740,-560,-380,-200,-20,160,340,520,700,880,1060,1240,1420]
const ZS = [-960,-800,-640,-480,-320,-160,0,160,320,480,640,760]
const CROSSINGS = [-800,-320,160,640,760]
const PARK = Rect2(-546,-302,508,604)
const PARK_BLOCK = Rect2(-560,-320,540,640)
const CITY = Rect2(-1500,-1000,3000,2000)
const PIER = Rect2(1010,780,240,160)
const SPAWN = Vector3(-520,1.4,286)
const RIVER_POINTS = [Vector2(180,-1000),Vector2(250,-720),Vector2(190,-440),Vector2(140,-160),Vector2(240,80),Vector2(360,320),Vector2(320,560),Vector2(180,800)]

var city: Node3D
var groups: Dictionary = {}
var materials: Dictionary = {}
var river: Array[Rect2] = []
var land: Array[Rect2] = []
var roads: Array = []
var walks: Array[Rect2] = []
var walk_sources: Array = []
var buildings: Array = []
var catalogs: Dictionary = {}
var scene_cache: Dictionary = {}
var used_assets: Dictionary = {}
var spatial: Dictionary = {}
var road_spatial: Dictionary = {}
var walk_spatial: Dictionary = {}
var route_rows: Array = []

func _initialize() -> void:
	for folder in ["materials","textures","meshes","prefabs","previews"]:
		DirAccess.make_dir_recursive_absolute(OUT+folder)
	city = Node3D.new()
	city.name = "SuperCity"
	city.set_meta("city_size_m",Vector2(3000,2000))
	city.set_meta("layout_description","West Village / North Heights / Parkside / Civic Center / Financial Quarter / Eastbank / Foundry Ward / Docklands")
	for key in ["Ground","WaterPlaceholders","Roads","Sidewalks","Districts","Landmarks","TraversalStarts"]:
		groups[key] = group(city,key)
	make_materials()
	make_geography()
	make_roads()
	make_alleys()
	remove_isolated_road_fragments()
	make_walks()
	index_transport()
	bake_ground()
	load_catalogs()
	place_city_buildings()
	place_remaining_assets()
	bake_transport()
	make_prefabs()
	make_lighting()
	var packed = PackedScene.new()
	assert(packed.pack(city) == OK)
	assert(ResourceSaver.save(packed,SCENE) == OK)
	write_manifest()
	print("SuperCity: %d buildings, %d road patches, %d sidewalk patches; saved %s" % [buildings.size(),roads.size(),walks.size(),SCENE])
	city.free()
	quit()

func group(parent: Node, node_name: String) -> Node3D:
	var node = Node3D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = city
	return node

func attach(body: Node, parent: Node) -> void:
	parent.add_child(body)
	body.owner = city
	for child in body.get_children():
		child.owner = city

func material(key: String, img: Image) -> Material:
	img.generate_mipmaps()
	var texture = ImageTexture.create_from_image(img)
	assert(ResourceSaver.save(texture,OUT+"textures/"+key+".res") == OK)
	texture.take_over_path(OUT+"textures/"+key+".res")
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.98
	assert(ResourceSaver.save(mat,OUT+"materials/"+key+".tres") == OK)
	mat.take_over_path(OUT+"materials/"+key+".tres")
	materials[key] = mat
	return mat

func make_materials() -> void:
	for width in [6,12,20,28]:
		var img = Image.create(128,128,false,Image.FORMAT_RGB8)
		for y in range(128):
			for x in range(128):
				var noise = float((x*17+y*37+x*y)%13)/650.0
				var c = Color(0.22+noise,0.235+noise,0.24+noise)
				if width > 6:
					if x in [62,65]:
						c = Color("bbae6c")
					if width >= 20 and x in [32,95] and y%64 < 24:
						c = Color("cacbc2")
					if x in [5,122]:
						c = Color("b1b7b1")
				img.set_pixel(x,y,c)
		material("road_%dm" % width,img)
	var sidewalk = Image.create(64,64,false,Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var noise = float((x*13+y*11)%11)/500.0
			var c = Color(0.51+noise,0.52+noise,0.50+noise)
			if x%32 == 0 or y%32 == 0:
				c = Color("636b68")
			sidewalk.set_pixel(x,y,c)
	material("sidewalk",sidewalk)
	for entry in [["ground","656b60"],["park","5c7e48"],["water","416f8b"]]:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(entry[1])
		mat.roughness = 1
		assert(ResourceSaver.save(mat,OUT+"materials/"+entry[0]+".tres") == OK)
		mat.take_over_path(OUT+"materials/"+entry[0]+".tres")
		materials[entry[0]] = mat

func junction_material(width: float, depth: float, arms: int) -> Material:
	var key = "junction_%d_%d_%d" % [width,depth,arms]
	if materials.has(key):
		return materials[key]
	var img = Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var noise = float((x*17+y*37+x*y)%13)/650.0
			var c = Color(0.22+noise,0.235+noise,0.24+noise)
			# Crosswalks belong on the approach streets, outside this junction.
			img.set_pixel(x,y,c)
	return material(key,img)

func street_material(item: Dictionary) -> Material:
	var rect: Rect2 = item.rect
	var length: float = rect.size.x if item.axis == 0 else rect.size.y
	var flags := 0
	if item.kind == "street":
		for junction in roads:
			if junction.kind != "junction":
				continue
			var jr: Rect2 = junction.rect
			if item.axis == 0 and is_equal_approx(jr.position.y,rect.position.y) and is_equal_approx(jr.size.y,rect.size.y):
				if is_equal_approx(jr.end.x,rect.position.x): flags |= 1
				if is_equal_approx(jr.position.x,rect.end.x): flags |= 2
			elif item.axis == 1 and is_equal_approx(jr.position.x,rect.position.x) and is_equal_approx(jr.size.x,rect.size.x):
				if is_equal_approx(jr.end.y,rect.position.y): flags |= 1
				if is_equal_approx(jr.position.y,rect.end.y): flags |= 2
	var key := "approach_%d_%s_%d" % [item.width,str(snappedf(length,0.01)).replace(".","p"),flags]
	if materials.has(key): return materials[key]
	var img := Image.create(128,512,false,Image.FORMAT_RGB8)
	var base: Image = materials["road_%dm" % item.width].albedo_texture.get_image()
	for y in range(512):
		var along := (float(y)+0.5)/512.0*length
		var crossing := (flags&1 and along >= 2 and along <= 5) or (flags&2 and along >= length-5 and along <= length-2)
		for x in range(128):
			var c := base.get_pixel(x,int(along/16.0*128)%128)
			if crossing:
				var across: float = (float(x)+0.5)/128.0*item.width
				c = Color("c3c5bb") if fmod(across,1.2) < 0.6 else Color(0.23,0.245,0.25)
			img.set_pixel(x,y,c)
	return material(key,img)

func river_x(z: float) -> float:
	for i in range(RIVER_POINTS.size()-1):
		var a: Vector2 = RIVER_POINTS[i]
		var b: Vector2 = RIVER_POINTS[i+1]
		if z <= b.y:
			return snappedf(lerpf(a.x,b.x,inverse_lerp(a.y,b.y,z)),10)
	return 180

func make_geography() -> void:
	for z in range(-1000,800,40):
		var center = river_x(z+20)
		var rect = Rect2(center-70,z,140,40)
		river.append(rect)
		land.append(Rect2(-1500,z,rect.position.x+1500,40))
		land.append(Rect2(rect.end.x,z,1500-rect.end.x,40))
	land.append(Rect2(PIER.position.x,800,PIER.size.x,PIER.end.y-800))
	var water_builder = MeshBuilder.new()
	for rect in river:
		water_builder.slab(rect,-1.4,0.1,materials.water)
	water_builder.slab(Rect2(-1500,800,3000,200),-1.4,0.1,materials.water)
	attach(water_builder.body("RiverAndBay_BluePlaceholder",OUT+"meshes/water_placeholder.res"),groups.WaterPlaceholders)
	var park_builder = MeshBuilder.new()
	park_builder.slab(PARK,0.025,0.05,materials.park)
	attach(park_builder.body("CentralPark_GreenPlaceholder",OUT+"meshes/central_park.res",true),groups.Landmarks)
	marker("CentralPark",Vector3(-292,1,0))
	marker("PierEdge",Vector3(1130,1,930))
	marker("RiverMouth",Vector3(180,1,795))

func x_width(x: int) -> float:
	return 28.0 if x in [-740,-20,700] else (12.0 if x in [-1280,1240] else 20.0)

func z_width(z: int) -> float:
	return 28.0 if z in [-320,320,640] else (12.0 if z in [-800,-160] else 20.0)

func subtract_rect(base: Rect2, cut: Rect2) -> Array[Rect2]:
	var intersection = base.intersection(cut)
	if not intersection.has_area():
		return [base]
	var pieces: Array[Rect2] = []
	for rect in [Rect2(base.position,Vector2(base.size.x,intersection.position.y-base.position.y)),Rect2(Vector2(base.position.x,intersection.end.y),Vector2(base.size.x,base.end.y-intersection.end.y)),Rect2(Vector2(base.position.x,intersection.position.y),Vector2(intersection.position.x-base.position.x,intersection.size.y)),Rect2(Vector2(intersection.end.x,intersection.position.y),Vector2(base.end.x-intersection.end.x,intersection.size.y))]:
		if rect.size.x > 0.01 and rect.size.y > 0.01:
			pieces.append(rect)
	return pieces

func subtract_all(pieces: Array[Rect2], cuts: Array) -> Array[Rect2]:
	for cut in cuts:
		var next: Array[Rect2] = []
		for rect in pieces:
			next.append_array(subtract_rect(rect,cut))
		pieces = next
	return pieces

func wet(rect: Rect2, margin := 0.0) -> bool:
	for water in river:
		if rect.grow(margin).intersects(water):
			return true
	return false

func add_road(rect: Rect2, axis: int, width: float, kind: String, bridge := false) -> void:
	var pieces: Array[Rect2] = [rect]
	if not bridge:
		for water in river:
			if not rect.grow(4).intersects(water):
				continue
			# Remove full road-width intervals, never leave half a carriageway at the bank.
			var cut = Rect2(water.position.x-4,rect.position.y,water.size.x+8,rect.size.y) if axis == 0 else Rect2(rect.position.x,water.position.y-4,rect.size.x,water.size.y+8)
			pieces = subtract_all(pieces,[cut])
	for piece in pieces:
		if (piece.size.x if axis == 0 else piece.size.y) >= 6:
			roads.append({"rect":piece,"axis":axis,"width":width,"kind":kind,"bridge":bridge,"arms":0})

func make_roads() -> void:
	for z in ZS:
		for i in range(XS.size()-1):
			var left: int = XS[i]
			var right: int = XS[i+1]
			if z > -320 and z < 320 and left >= -560 and right <= -20:
				continue
			var x0 = left+x_width(left)/2
			var x1 = right-x_width(right)/2
			add_road(Rect2(x0,z-z_width(z)/2,x1-x0,z_width(z)),0,z_width(z),"street",z in CROSSINGS)
	for x in XS:
		for i in range(ZS.size()-1):
			var north: int = ZS[i]
			var south: int = ZS[i+1]
			if x > -560 and x < -20 and north >= -320 and south <= 320:
				continue
			var z0 = north+z_width(north)/2
			var z1 = south-z_width(south)/2
			add_road(Rect2(x-x_width(x)/2,z0,x_width(x),z1-z0),1,x_width(x),"street")
	var edges = roads.duplicate()
	for x in XS:
		for z in ZS:
			var w = x_width(x)
			var d = z_width(z)
			var rect = Rect2(x-w/2,z-d/2,w,d)
			var arms = 0
			for option in [[1,Vector2(x,z-d/2-0.1)],[2,Vector2(x+w/2+0.1,z)],[4,Vector2(x,z+d/2+0.1)],[8,Vector2(x-w/2-0.1,z)]]:
				for edge in edges:
					if edge.rect.has_point(option[1]):
						arms |= option[0]
						break
			if arms == 0 or (wet(rect,4) and not z in CROSSINGS):
				continue
			roads.append({"rect":rect,"axis":0,"width":w,"kind":"junction","bridge":z in CROSSINGS,"arms":arms})
	# A simple extension of the street/sidewalk vocabulary forms the future pier.
	add_road(Rect2(1050,770,20,140),1,20,"pier_access")
	for z in CROSSINGS:
		marker("Crossing_%s" % str(z).replace("-","North"),Vector3(river_x(z),1,z))

func make_alleys() -> void:
	for ix in range(XS.size()-1):
		for iz in range(ZS.size()-1):
			var center = Vector2((XS[ix]+XS[ix+1])/2.0,(ZS[iz]+ZS[iz+1])/2.0)
			if PARK_BLOCK.has_point(center) or (ix+iz)%3 == 0:
				continue
			var rect = Rect2(center.x-3,ZS[iz]+z_width(ZS[iz])/2,6,ZS[iz+1]-ZS[iz]-z_width(ZS[iz])/2-z_width(ZS[iz+1])/2)
			if not wet(rect,15):
				add_road(rect,1,6,"alley")

func walk_source(rect: Rect2, allow_water := false) -> void:
	if rect.has_area():
		walk_sources.append({"rect":rect,"allow_water":allow_water})

func remove_isolated_road_fragments() -> void:
	# A winding bank can isolate a short grid-street remnant between two bends.
	# Keep only the connected street network before adding sidewalks and buildings.
	var reached: Dictionary = {0:true}
	var queue: Array[int] = [0]
	var cursor = 0
	while cursor < queue.size():
		var index = queue[cursor]
		cursor += 1
		for j in range(roads.size()):
			if not reached.has(j) and roads[index].rect.grow(0.04).intersects(roads[j].rect):
				reached[j] = true
				queue.append(j)
	var connected: Array = []
	for i in range(roads.size()):
		if reached.has(i):
			connected.append(roads[i])
	roads = connected

func make_walks() -> void:
	for road in roads:
		var r: Rect2 = road.rect
		if road.kind == "alley":
			continue
		if road.kind != "junction":
			if road.axis == 0:
				walk_source(Rect2(r.position.x,r.position.y-4,r.size.x,4),road.bridge)
				walk_source(Rect2(r.position.x,r.end.y,r.size.x,4),road.bridge)
			else:
				walk_source(Rect2(r.position.x-4,r.position.y,4,r.size.y),road.bridge)
				walk_source(Rect2(r.end.x,r.position.y,4,r.size.y),road.bridge)
		else:
			for x in [r.position.x-4,r.end.x]:
				for z in [r.position.y-4,r.end.y]:
					walk_source(Rect2(x,z,4,4),road.bridge)
			if not road.arms&1:
				walk_source(Rect2(r.position.x-4,r.position.y-4,r.size.x+8,4),road.bridge)
			if not road.arms&4:
				walk_source(Rect2(r.position.x-4,r.end.y,r.size.x+8,4),road.bridge)
			if not road.arms&8:
				walk_source(Rect2(r.position.x-4,r.position.y,4,r.size.y),road.bridge)
			if not road.arms&2:
				walk_source(Rect2(r.end.x,r.position.y,4,r.size.y),road.bridge)
	# Deliberately broad quay and simple concrete pier platform, made from sidewalk mesh.
	walk_source(Rect2(-1500,780,3000,10))
	walk_source(PIER)
	for i in range(river.size()):
		var r = river[i]
		walk_source(Rect2(r.position.x-8,r.position.y,6,r.size.y))
		walk_source(Rect2(r.end.x+2,r.position.y,6,r.size.y))
		if i > 0:
			var previous = river[i-1]
			for edge in [0,1]:
				var a = previous.position.x-8 if edge == 0 else previous.end.x+2
				var b = r.position.x-8 if edge == 0 else r.end.x+2
				walk_source(Rect2(minf(a,b),r.position.y-2,absf(a-b)+6,4))
	for source in walk_sources:
		var pieces: Array[Rect2] = [source.rect]
		if not source.allow_water:
			pieces = subtract_all(pieces,river)
		for road in roads:
			if source.rect.intersects(road.rect):
				pieces = subtract_all(pieces,[road.rect])
		for existing in walks:
			if source.rect.intersects(existing):
				pieces = subtract_all(pieces,[existing])
		walks.append_array(pieces)

func spatial_keys(rect: Rect2) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for x in range(floori(rect.position.x/100),floori(rect.end.x/100)+1):
		for z in range(floori(rect.position.y/100),floori(rect.end.y/100)+1):
			keys.append(Vector2i(x,z))
	return keys

func index_rect(index: Dictionary, rect: Rect2, value: Variant) -> void:
	for key in spatial_keys(rect):
		if not index.has(key):
			index[key] = []
		index[key].append(value)

func index_transport() -> void:
	for road in roads:
		index_rect(road_spatial,road.rect,road.rect)
	for walk in walks:
		index_rect(walk_spatial,walk,walk)

func bake_ground() -> void:
	# Paved/green surfaces replace the earth's top face, rather than fight it in depth.
	var builder = MeshBuilder.new()
	var cuts: Array = [PARK]
	for road in roads:
		cuts.append(road.rect)
	cuts.append_array(walks)
	for region in land:
		var relevant: Array = []
		for cut in cuts:
			if region.intersects(cut):
				relevant.append(cut)
		var pieces = subtract_all([region],relevant)
		for piece in pieces:
			builder.slab(piece,0,2,materials.ground)
	attach(builder.body("GroundMesh",OUT+"meshes/ground.res"),groups.Ground)

func clear_at(rect: Rect2) -> bool:
	if not CITY.encloses(rect) or rect.end.y > 776 or rect.intersects(PARK_BLOCK.grow(1)) or wet(rect,10):
		return false
	for key in spatial_keys(rect.grow(4)):
		for index in [road_spatial,walk_spatial,spatial]:
			for other in index.get(key,[]):
				if rect.grow(2 if index != spatial else 3).intersects(other):
					return false
	return true

func load_catalogs() -> void:
	for category in ["commercial","residential","industrial"]:
		var path = "res://assets/generated-buildings/"+category+"/"
		catalogs[category] = JSON.parse_string(FileAccess.get_file_as_string(path+"manifest.json"))
		for entry in catalogs[category]:
			entry["path"] = path+entry.scene
			scene_cache[entry.path] = load(entry.path)

func district_at(p: Vector2) -> String:
	if p.x > 880 and p.y > 420:
		return "Docklands"
	if p.x > 980 and p.y > -220:
		return "FoundryWard"
	if p.y > 380 and p.x > -450 and p.x < 760:
		return "FinancialQuarter"
	if p.x < -860 and p.y < 350:
		return "WestVillage"
	if p.y < -430:
		return "NorthHeights"
	if p.x > river_x(p.y):
		return "Eastbank"
	if p.x > -780 and p.y < 330:
		return "Parkside"
	return "CivicCenter"

func pick_asset(district: String, p: Vector2, salt: int) -> Dictionary:
	var category = "residential"
	var target = 24.0
	match district:
		"WestVillage": target = 10+float(salt%14)
		"NorthHeights": target = 20+float(salt%42)
		"Parkside":
			target = 35+float(salt%90)
			if salt%7 == 0:
				category = "commercial"
				target = 85
		"CivicCenter":
			category = "commercial" if salt%4 != 0 else "residential"
			target = 75+float(salt%70)
		"FinancialQuarter":
			category = "commercial"
			target = clampf(235-p.distance_to(Vector2(20,570))*0.3,95,235)+float(salt%25)-12
		"Eastbank":
			target = 30+float(salt%62)
			if salt%6 == 0:
				category = "commercial"
				target = 120
		"FoundryWard", "Docklands":
			category = "industrial"
			target = 9+float(salt%22)
	var candidates: Array = catalogs[category].duplicate()
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return absf(a.height_m-target) < absf(b.height_m-target))
	return candidates[salt%mini(4,candidates.size())]

func place_building(entry: Dictionary, position: Vector2, rotation: float, district: String) -> bool:
	var quarter = absi(roundi(rotation/(PI/2)))%2 == 1
	var size = Vector2(entry.depth_m,entry.width_m) if quarter else Vector2(entry.width_m,entry.depth_m)
	var rect = Rect2(position-size/2,size)
	if not clear_at(rect):
		return false
	if not groups.has(district):
		groups[district] = group(groups.Districts,district)
	var instance: Node3D = scene_cache[entry.path].instantiate()
	instance.name = "%s_%04d" % [district,buildings.size()+1]
	instance.position = Vector3(position.x,0,position.y)
	instance.rotation.y = rotation
	groups[district].add_child(instance)
	instance.owner = city
	# Cache-friendly repeated PackedScenes; only per-instance draw distance changes.
	var mesh: MeshInstance3D = instance.get_node("MeshInstance3D")
	mesh.visibility_range_end = 2200 if entry.height_m > 130 else (1500 if entry.height_m > 60 else 850)
	mesh.visibility_range_end_margin = 60
	city.set_editable_instance(instance,true)
	buildings.append({"node":str(city.get_path_to(instance)),"asset":entry.path,"district":district,"position":[position.x,0,position.y],"rotation_y":rotation,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"height_m":entry.height_m})
	used_assets[entry.path] = true
	index_rect(spatial,rect,rect)
	return true

func place_city_buildings() -> void:
	# Fixed frontage runs, not random points: doors face roads and lots share alleys.
	for ix in range(XS.size()-1):
		for iz in range(ZS.size()-1):
			var center = Vector2((XS[ix]+XS[ix+1])/2.0,(ZS[iz]+ZS[iz+1])/2.0)
			if PARK_BLOCK.has_point(center):
				continue
			var district = district_at(center)
			var x0 = XS[ix]+x_width(XS[ix])/2+7
			var x1 = XS[ix+1]-x_width(XS[ix+1])/2-7
			var z0 = ZS[iz]+z_width(ZS[iz])/2+7
			var z1 = ZS[iz+1]-z_width(ZS[iz+1])/2-7
			var salt = ix*113+iz*71
			for side in range(4):
				var cursor = (x0 if side < 2 else z0)+4
				var end = x1 if side < 2 else z1
				var slot = 0
				while cursor < end-12:
					var entry = pick_asset(district,center,salt+side*19+slot*7)
					var frontage: float = entry.width_m
					var depth: float = entry.depth_m
					if cursor+frontage > end:
						break
					var position = Vector2(cursor+frontage/2,z0+depth/2) if side == 0 else Vector2(cursor+frontage/2,z1-depth/2)
					var rotation = 0.0 if side == 0 else PI
					if side >= 2:
						position = Vector2(x0+depth/2,cursor+frontage/2) if side == 2 else Vector2(x1-depth/2,cursor+frontage/2)
						rotation = PI/2 if side == 2 else -PI/2
					place_building(entry,position,rotation,district)
					cursor += frontage+(5 if district == "WestVillage" else 8)
					slot += 1
			# Mews/loft infill addresses the alley, leaving industrial service yards open.
			if not district in ["FoundryWard","Docklands"]:
				var has_alley = false
				for road in roads:
					if road.kind == "alley" and road.rect.has_point(center):
						has_alley = true
						break
				if has_alley:
					for side in [-1,1]:
						var cursor = z0+38
						var slot = 0
						while cursor < z1-38:
							var entry = pick_asset(district,center,salt+slot*13+absi(side+1)*7)
							if cursor+entry.width_m > z1-30:
								break
							var position = Vector2(center.x+side*(6+entry.depth_m/2),cursor+entry.width_m/2)
							place_building(entry,position,PI/2 if side == 1 else -PI/2,district)
							cursor += entry.width_m+7
							slot += 1
	# Explicit traversal progression through low roofs toward the tall bay skyline.
	for route in [["VillageToPark",Vector3(-1040,1,-400)],["ParkToSkyline",SPAWN],["EastbankToDocks",Vector3(720,1,340)],["RiverRun",Vector3(100,1,-320)]]:
		marker(route[0],route[1])
		route_rows.append({"name":route[0],"position":[route[1].x,route[1].y,route[1].z]})

func bake_transport() -> void:
	# 500 m chunks preserve spatial culling and keep the required three-node structure.
	for category in ["Roads","Sidewalks"]:
		var chunks: Dictionary = {}
		var source: Array = roads if category == "Roads" else walks
		for item in source:
			var rect: Rect2 = item.rect if category == "Roads" else item
			for cx in range(floori((rect.position.x+1500)/500),mini(5,floori((rect.end.x+1500-0.001)/500))+1):
				for cz in range(floori((rect.position.y+1000)/500),mini(3,floori((rect.end.y+1000-0.001)/500))+1):
					var tile = Rect2(-1500+cx*500,-1000+cz*500,500,500)
					var piece = rect.intersection(tile)
					if not piece.has_area():
						continue
					var key = Vector2i(cx,cz)
					if not chunks.has(key):
						chunks[key] = MeshBuilder.new()
						chunks[key].origin = Vector3(tile.get_center().x,0,tile.get_center().y)
					var builder: RefCounted = chunks[key]
					if category == "Sidewalks":
						# Flush with the road so movement does not require curb stepping.
						builder.slab(piece,0.03,0.03,materials.sidewalk,piece.size/4,false,piece.position/4)
					else:
						var mat: Material = junction_material(rect.size.x,rect.size.y,item.arms) if item.kind == "junction" else street_material(item)
						var uv_scale = piece.size/rect.size
						var uv_offset = (piece.position-rect.position)/rect.size
						if item.kind != "junction":
							uv_scale = Vector2(piece.size.y/rect.size.y,piece.size.x/rect.size.x) if item.axis == 0 else piece.size/rect.size
							uv_offset = Vector2((piece.position.y-rect.position.y)/rect.size.y,(piece.position.x-rect.position.x)/rect.size.x) if item.axis == 0 else (piece.position-rect.position)/rect.size
						builder.slab(piece,0.03,0.12,mat,uv_scale,item.axis == 0 and item.kind != "junction",uv_offset)
		for key in chunks:
			var slug = "%s_%d_%d" % [category.to_snake_case(),key.x,key.y]
			attach(chunks[key].body(slug,OUT+"meshes/"+slug+".res"),groups[category])

func place_remaining_assets() -> void:
	# Reserve a few infill sites so the complete 50-building library appears in the city.
	for category in catalogs:
		for entry in catalogs[category]:
			if used_assets.has(entry.path):
				continue
			var placed = false
			for z in range(370,720,18):
				if placed:
					break
				for x in range(-700,1350,18):
					var p = Vector2(x,z)
					var district = district_at(p)
					if category == "commercial" and not district in ["CivicCenter","FinancialQuarter"]:
						continue
					if category == "industrial" and not district in ["FoundryWard","Docklands"]:
						continue
					if category == "residential" and district != "Eastbank":
						continue
					if place_building(entry,p,0,district):
						placed = true
						break

func make_prefabs() -> void:
	for definition in [["road_12m",12,40,materials.road_12m,0.03],["road_20m",20,40,materials.road_20m,0.03],["road_28m",28,40,materials.road_28m,0.03],["alley_6m",6,40,materials.road_6m,0.03],["sidewalk_4m",4,40,materials.sidewalk,0.03]]:
		var builder = MeshBuilder.new()
		var width: float = definition[1]
		var length: float = definition[2]
		builder.slab(Rect2(-width/2,-length/2,width,length),definition[4],0.03 if width == 4 else 0.18,definition[3],Vector2(1,length/(4 if width == 4 else 16)))
		var body = builder.body(definition[0],OUT+"meshes/"+definition[0]+".res",true)
		var packed = PackedScene.new()
		assert(packed.pack(body) == OK)
		assert(ResourceSaver.save(packed,OUT+"prefabs/"+definition[0]+".tscn") == OK)
		body.free()

func marker(node_name: String, position: Vector3) -> void:
	var point = Marker3D.new()
	point.name = node_name
	point.position = position
	groups.TraversalStarts.add_child(point)
	point.owner = city

func make_lighting() -> void:
	var environment = WorldEnvironment.new()
	environment.name = "Daylight"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("698999")
	sky_material.sky_horizon_color = Color("b7c8cc")
	sky_material.ground_bottom_color = Color("596369")
	sky_material.ground_horizon_color = Color("b7c8cc")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c2ccd1")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	city.add_child(environment)
	environment.owner = city
	var light = DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-48,-28,0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 300
	city.add_child(light)
	light.owner = city

func rect_row(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func write_manifest() -> void:
	var road_rows: Array = []
	for road in roads:
		road_rows.append({"rect":rect_row(road.rect),"axis":road.axis,"width":road.width,"kind":road.kind,"crossing_corridor":road.bridge,"arms":road.arms})
	var walk_rows: Array = []
	for rect in walks:
		walk_rows.append(rect_row(rect))
	var water_rows: Array = []
	for rect in river:
		water_rows.append(rect_row(rect))
	var file = FileAccess.open(OUT+"layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"city_rect":rect_row(CITY),"park_rect":rect_row(PARK),"pier_rect":rect_row(PIER),"bay_rect":[-1500,800,3000,200],"river_rects":water_rows,"crossings":CROSSINGS,"roads":road_rows,"sidewalks":walk_rows,"buildings":buildings,"used_building_assets":used_assets.keys(),"traversal_starts":route_rows,"suggested_spawn_marker":[SPAWN.x,SPAWN.y,SPAWN.z]},"\t"))

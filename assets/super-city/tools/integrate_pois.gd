extends "res://assets/super-city/tools/generate_super_city.gd"
## One-time, local integration. Generates replacement surfaces; a text patch
## installs them without repacking the user's edited city or its child scenes.
const WORK := "res://artifacts/poi_integration/"
const PATCH_OUT := "res://assets/super-city/poi-integration/"
var layout: Dictionary
var report := {"removed_buildings":[],"removed_roads":[],"surface_replacements":[],"pois":[],"cleared_props":[]}

func _initialize() -> void: integrate.call_deferred()

func rect_of(row: Array) -> Rect2: return Rect2(row[0],row[1],row[2],row[3])

func integrate() -> void:
	DirAccess.make_dir_recursive_absolute(PATCH_OUT)
	layout = JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	assert(not layout.has("poi_integration"),"Integration already applied; do not regenerate from the modified layout.")
	var source: Node3D = load(SCENE).instantiate()
	var specs := [
		["CityHall","city_hall",Vector3(-292,0.1,-404),0.0,Rect2(-414,-470,245,132)],
		["Hospital","hospital",Vector3(-292,0.03,387),PI,Rect2(-370,338,160,98)],
		["PoliceStation","police_station",Vector3(-435,0.03,-356),0.0,Rect2(-460,-376,50,38)],
		["Bank1","bank1",Vector3(-139,0.03,516),PI,Rect2(-164,494,50,44)],
		["Bank2","bank2",Vector3(109,0.03,602),0.0,Rect2(82,575,56,47)],
		["Firehouse","firehouse",Vector3(-616,0.03,507),PI,Rect2(-636,494,40,32)]
	]
	var sites: Array[Rect2] = []
	var envelopes: Array[Rect2] = []
	for spec in specs:
		var asset: String = "res://assets/buildings/%s/%s.tscn"%[spec[1],spec[1]]
		var node: Node3D = load(asset).instantiate()
		node.position = spec[2]
		node.rotation.y = spec[3]
		var bounds := visual_bounds(node)
		var footprint := Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)
		envelopes.append(footprint)
		sites.append(spec[4])
		report.pois.append({"node":spec[0],"asset":asset,"position":[node.position.x,node.position.y,node.position.z],"rotation_y":spec[3],"rect":rect_row(footprint),"site":rect_row(spec[4]),"district":district_at(Vector2(node.position.x,node.position.z))})
		node.free()
	# Close only the two civic-block side streets and the hospital's bisecting alley.
	# Keeping junction order preserves traffic-signal IDs throughout the city.
	for raw in layout.roads:
		var r := rect_of(raw.rect)
		var close: bool = (raw.kind=="street" and raw.axis==1 and is_equal_approx(r.position.y,-470) and (is_equal_approx(r.get_center().x,-380) or is_equal_approx(r.get_center().x,-200))) or (raw.kind=="alley" and is_equal_approx(r.get_center().x,-290) and is_equal_approx(r.position.y,334))
		if close:
			report.removed_roads.append(raw)
			continue
		var row: Dictionary = raw.duplicate(true)
		row.rect = r
		roads.append(row)
	for row in roads:
		if row.kind!="junction": continue
		var r: Rect2 = row.rect
		var arms := 0
		for option in [[1,Vector2(r.get_center().x,r.position.y-0.1)],[2,Vector2(r.end.x+0.1,r.get_center().y)],[4,Vector2(r.get_center().x,r.end.y+0.1)],[8,Vector2(r.position.x-0.1,r.get_center().y)]]:
			for street in roads:
				if street.kind=="street" and street.rect.has_point(option[1]): arms|=option[0]; break
		row.arms = arms
	# Remove old pavement inside complete POI envelopes. New perimeter aprons join
	# existing sidewalks; closed roads are paved so there are no old ground holes.
	for row in layout.sidewalks: walks.append_array(subtract_all([rect_of(row)],envelopes))
	var paving: Array[Rect2] = sites.duplicate()
	for road in report.removed_roads: paving.append(rect_of(road.rect))
	var cuts: Array = envelopes.duplicate()
	for road in roads: cuts.append(road.rect)
	for area in paving:
		var pieces := subtract_all([area],cuts)
		pieces = subtract_all(pieces,walks)
		walks.append_array(pieces)
	# Remove actual current instances intersecting reserved sites, including any
	# user-edited building dimensions, and update their manifest rows accordingly.
	var kept: Array = []
	for building in layout.buildings:
		var node: Node3D = source.get_node_or_null(building.node)
		if node==null: continue
		var b := visual_bounds(node)
		var footprint := Rect2(b.position.x,b.position.z,b.size.x,b.size.z)
		var remove := false
		for site in sites:
			if footprint.intersects(site.grow(2)): remove=true; break
		if remove: report.removed_buildings.append(building.node)
		else: kept.append(building)
	layout.buildings=kept
	layout.landmarks=report.pois
	layout.poi_integration="September 2026 civic, medical, financial and emergency-service sites"
	layout.roads=[]
	for road in roads:
		var row: Dictionary=road.duplicate()
		row.rect=rect_row(road.rect)
		layout.roads.append(row)
	layout.sidewalks=walks.map(func(r):return rect_row(r))
	FileAccess.open(PATCH_OUT+"layout.json",FileAccess.WRITE).store_string(JSON.stringify(layout,"\t"))
	# Generate all meshes into the task folder. Only changed chunks are installed.
	city=Node3D.new()
	for key in ["Roads","Sidewalks","Ground"]: groups[key]=group(city,key)
	for width in [6,12,20,28]: materials["road_%dm"%width]=load(OUT+"materials/road_%dm.tres"%width)
	materials.sidewalk=load(OUT+"materials/sidewalk.tres")
	materials.ground=load(OUT+"materials/ground.tres")
	# bake_transport writes the familiar resource names; baseline copies made by
	# the caller protect the original meshes. Collision files are explicit here.
	bake_transport()
	for category in ["Roads","Sidewalks"]:
		for body in groups[category].get_children():
			if not str(body.name).ends_with("_2_1") and not str(body.name).ends_with("_2_2") and not str(body.name).ends_with("_2_3") and not str(body.name).ends_with("_3_3") and not str(body.name).ends_with("_1_3") and not str(body.name).ends_with("_1_2"): continue
			var shape_path:=PATCH_OUT+str(body.name)+"_collision.res"
			assert(ResourceSaver.save(body.get_node("CollisionShape3D").shape,shape_path)==OK)
			report.surface_replacements.append({"node":category+"/"+str(body.name)+"/CollisionShape3D","shape":shape_path})
	# Recut the base ground against the new pavement while retaining river/bay gaps.
	for row in layout.river_rects:
		var r:=rect_of(row)
		land.append(Rect2(-1500,r.position.y,r.position.x+1500,r.size.y))
		land.append(Rect2(r.end.x,r.position.y,1500-r.end.x,r.size.y))
	land.append(Rect2(PIER.position.x,800,PIER.size.x,PIER.end.y-800))
	bake_ground()
	var ground_shape:=PATCH_OUT+"ground_collision.res"
	assert(ResourceSaver.save(groups.Ground.get_child(0).get_node("CollisionShape3D").shape,ground_shape)==OK)
	report.surface_replacements.append({"node":"Ground/GroundMesh/CollisionShape3D","shape":ground_shape})
	# Identify movable street furniture inside the new sites; keep unrelated trees,
	# scenery and controls. Surface graph validation includes their remaining bodies.
	var life: Node3D=source.get_node("CityLife")
	for name in ["Diners","HotdogStands","Benches","BusStops","Hydrants","Grates"]:
		for prop in life.get_node(name).get_children():
			var b:=visual_bounds(prop)
			if b.size==Vector3.ZERO: continue
			var r:=Rect2(b.position.x,b.position.z,b.size.x,b.size.z)
			for site in sites:
				if r.intersects(site): report.cleared_props.append(str(life.get_path_to(prop))); break
	FileAccess.open(PATCH_OUT+"integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("POI_PLAN: ",report.removed_buildings.size()," building instances removed; ",report.removed_roads.size()," roads closed; ",report.cleared_props.size()," conflicting props cleared.")
	source.free()
	city.free()
	quit()

func visual_bounds(node: Node3D) -> AABB:
	var bounds:=AABB()
	var first:=true
	var nodes: Array[Node]=[node]
	nodes.append_array(node.find_children("*","MeshInstance3D",true,false))
	for mesh in nodes:
		if not mesh is MeshInstance3D or mesh.mesh==null: continue
		var pose: Transform3D=mesh.transform
		var ancestor=mesh.get_parent()
		while ancestor!=null and ancestor!=city:
			if ancestor is Node3D: pose=ancestor.transform*pose
			ancestor=ancestor.get_parent()
		var b: AABB=pose*mesh.mesh.get_aabb()
		bounds=b if first else bounds.merge(b)
		first=false
	return bounds

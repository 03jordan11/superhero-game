extends SceneTree
## Offline authoring; never regenerates or restructures the existing city.
const OUT := "res://assets/waterfront/"
const ISLAND := Vector3(300, 0, 2400)
const SEA_LEVEL := -1.4
var scene: Node3D
var mats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var layout: Dictionary

func _initialize() -> void: generate.call_deferred()

func generate() -> void:
	rng.seed = 28417
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	DirAccess.make_dir_recursive_absolute(OUT+"meshes")
	scene = Node3D.new()
	scene.name = "Waterfront"
	scene.set_script(load("res://scripts/waterfront.gd"))
	for label in ["Water", "Riverbanks", "Harbor", "PrisonIsland", "Boats", "Navigation"]: add(Node3D.new(),scene,label)
	for pair in [["stone","596269"],["concrete","898a80"],["wood","665342"],["iron","29353c"],["rust","925f42"],["white","d5d7ce"],["glass","294e5f"],["red","a94736"],["yellow","d4a547"],["roof","45545a"],["grass","505e43"],["court","486358"]]:
		mats[pair[0]] = material(Color(pair[1]))
	mats.vertex = material(Color.WHITE)
	mats.vertex.vertex_color_use_as_albedo = true
	mats.vertex.vertex_color_is_srgb = true
	mats.warm = glowing(Color("ffbc72"),2.7)
	mats.cool = glowing(Color("a2d2e8"),2.0)
	mats.redlight = glowing(Color("ff593c"),2.0)
	mats.greenlight = glowing(Color("50f5a1"),2.0)
	mats.foam = ShaderMaterial.new()
	mats.foam.shader = load(OUT+"foam.gdshader")
	mats.deck = ShaderMaterial.new()
	mats.deck.shader = load(OUT+"deck.gdshader")
	make_water()
	make_riverbanks()
	make_harbor()
	make_island()
	make_boats()
	make_navigation()
	preload("res://assets/super-city/tools/regional_geometry.gd").prison(scene.get_node("PrisonIsland"))
	scene.set_meta("island_center",ISLAND)
	scene.set_meta("boat_count",scene.get_node("Boats").get_child_count())
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/waterfront.tscn")==OK)
	print("Waterfront authored: river, ocean, harbor, Blackwater prison island and %d boats."%scene.get_meta("boat_count"))
	scene.free()
	quit()

func add(node: Node, parent: Node, label: String) -> Node:
	node.name=label
	parent.add_child(node,true)
	node.owner=scene
	return node

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=0.82
	return mat

func glowing(color: Color, energy: float) -> StandardMaterial3D:
	var mat := material(color*0.3)
	mat.emission_enabled=true
	mat.emission=color
	mat.emission_energy_multiplier=0
	mat.set_meta("night_glow",energy)
	return mat

func visual(mesh: Mesh, parent: Node, label: String, position: Vector3, mat: Material = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.position=position
	node.material_override=mat
	add(node,parent,label)
	return node

func collision(mesh: MeshInstance3D) -> void:
	var body := add(StaticBody3D.new(),mesh,"Solid")
	var shape := CollisionShape3D.new()
	shape.shape=mesh.mesh.create_trimesh_shape()
	add(shape,body,"CollisionShape3D")

func box(parent: Node, label: String, size: Vector3, position: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	var node := visual(mesh,parent,label,position,mat)
	if solid:
		var body := add(StaticBody3D.new(),node,"Solid")
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size=size
		shape.shape=bounds
		add(shape,body,"CollisionShape3D")
	return node

func cylinder(radius: float, height: float, top := -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=radius
	mesh.top_radius=radius if top<0 else top
	mesh.height=height
	mesh.radial_segments=10
	mesh.rings=1
	return mesh

func rod(parent: Node, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var node := visual(cylinder(radius,a.distance_to(b)),parent,label,(a+b)*0.5,mat)
	var direction := (b-a).normalized()
	var helper := Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.98 else Vector3.UP
	var x := helper.cross(direction).normalized()
	node.basis=Basis(x,direction,x.cross(direction).normalized())
	return node

func tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color := Color.WHITE) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for p in [a,b,c]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(p)

func surface(label: String, tool: SurfaceTool, parent: Node, mat: Material, solid := false) -> MeshInstance3D:
	var mesh := tool.commit()
	var path := OUT+"meshes/"+label.to_snake_case()+".res"
	assert(ResourceSaver.save(mesh,path)==OK)
	mesh.take_over_path(path)
	var node := visual(mesh,parent,label,Vector3.ZERO,mat)
	if solid: collision(node)
	return node

func plane(tool: SurfaceTool, rect: Rect2, y: float, color := Color.WHITE) -> void:
	var a := Vector3(rect.position.x,y,rect.position.y)
	var b := Vector3(rect.end.x,y,rect.position.y)
	var c := Vector3(rect.end.x,y,rect.end.y)
	var d := Vector3(rect.position.x,y,rect.end.y)
	tri(tool,a,b,c,color)
	tri(tool,a,c,d,color)

func new_surface() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func water_material(river: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=load(OUT+"water.gdshader")
	mat.set_shader_parameter("river",river)
	return mat

func make_water() -> void:
	var river := new_surface()
	for row in layout.river_rects: plane(river,Rect2(row[0],row[1],row[2],row[3]),SEA_LEVEL)
	surface("River",river,scene.get_node("Water"),water_material(true))
	var ocean := new_surface()
	plane(ocean,Rect2(-45000,800,90000,60000),SEA_LEVEL)
	surface("Ocean",ocean,scene.get_node("Water"),water_material(false))
	# A submerged floor preserves traversal recovery without treating water as solid.
	var floor_tool := new_surface()
	for row in layout.river_rects: plane(floor_tool,Rect2(row[0],row[1],row[2],row[3]),-12.0)
	plane(floor_tool,Rect2(-45000,800,90000,60000),-32.0)
	surface("Seabed",floor_tool,scene.get_node("Water"),mats.stone,true)

func near_crossing(z: float, margin := 24.0) -> bool:
	for crossing in layout.crossings:
		if absf(z-float(crossing))<margin: return true
	return false

func bank_wall(parent: Node, a: Vector2, b: Vector2) -> void:
	var delta := b-a
	var length := delta.length()
	if length<0.01: return
	var wall := box(parent,"QuayWall",Vector3(0.75,10,length),Vector3((a.x+b.x)*0.5,-5,(a.y+b.y)*0.5),mats.stone,true)
	wall.rotation.y=atan2(delta.x,delta.y)
	box(wall,"Coping",Vector3(1.1,0.18,length),Vector3(0,5.01,0),mats.concrete)
	# Masonry courses read as a retaining wall from river level.
	for y in [-1.6,-3.2,-4.8]:
		box(wall,"StoneCourse",Vector3(0.79,0.055,length),Vector3(0,y+5,0),mats.iron)
	if not near_crossing((a.y+b.y)*0.5,42):
		wall.set_meta("railing_length",length)

func make_riverbanks() -> void:
	var group := scene.get_node("Riverbanks")
	var foam := new_surface()
	for i in layout.river_rects.size():
		var row: Array=layout.river_rects[i]
		var left: float=row[0]
		var right: float=row[0]+row[2]
		var z: float=row[1]
		for x in [left,right]: bank_wall(group,Vector2(x,z),Vector2(x,z+40))
		if i>0:
			var previous: Array=layout.river_rects[i-1]
			bank_wall(group,Vector2(previous[0],z),Vector2(left,z))
			bank_wall(group,Vector2(previous[0]+previous[2],z),Vector2(right,z))
		plane(foam,Rect2(left+0.5,z,1.4,40),SEA_LEVEL+0.035,Color(1,1,1,0.6))
		plane(foam,Rect2(right-1.9,z,1.4,40),SEA_LEVEL+0.035,Color(1,1,1,0.6))
		if i%3==0 and not near_crossing(z+20):
			for side in [-1,1]:
				var x: float=left-1.4 if side<0 else right+1.4
				lamp(group,Vector3(x,0,z+20),5.5,false)
	# South seawall leaves the mouth open and frames the existing waterfront walk.
	bank_wall(group,Vector2(-1500,800),Vector2(120,800))
	bank_wall(group,Vector2(260,800),Vector2(1010,800))
	bank_wall(group,Vector2(1250,800),Vector2(1500,800))
	# Existing road decks stay in place; give the five crossings structural piers.
	for z in layout.crossings:
		var row: Array=layout.river_rects[clampi(int((float(z)+1000)/40),0,44)]
		for fraction in [0.2,0.8]:
			box(group,"BridgePier",Vector3(4,10,12),Vector3(row[0]+140*fraction,-5,float(z)),mats.concrete,true)
	surface("RiverFoam",foam,group,mats.foam)
	var railings := preload("res://assets/waterfront/tools/riverbank_railings.gd").build(group)
	railings.owner = scene

func lamp(parent: Node, p: Vector3, height: float, cool: bool) -> void:
	var root_node := add(Node3D.new(),parent,"HarborLamp") as Node3D
	root_node.position=p
	visual(cylinder(0.11,height),root_node,"Post",Vector3(0,height*0.5,0),mats.iron)
	box(root_node,"Housing",Vector3(1.1,0.18,0.7),Vector3(0,height,0),mats.iron)
	box(root_node,"Lens",Vector3(0.9,0.08,0.55),Vector3(0,height-0.1,0),mats.cool if cool else mats.warm)
	var light := OmniLight3D.new()
	light.position=Vector3(0,height-0.3,0)
	light.light_color=Color("add5ee") if cool else Color("ffc688")
	light.light_energy=3.5
	light.omni_range=19.0
	light.distance_fade_enabled=true
	light.distance_fade_begin=150
	light.distance_fade_length=100
	add(light,root_node,"Light")

func bollard(parent: Node, p: Vector3) -> void:
	visual(cylinder(0.28,0.7),parent,"Bollard",p+Vector3.UP*0.35,mats.iron)
	box(parent,"MooringBar",Vector3(0.85,0.15,0.2),p+Vector3.UP*0.6,mats.iron)

func pier(parent: Node, name: String, rect: Rect2, top: float) -> void:
	var node := add(Node3D.new(),parent,name) as Node3D
	box(node,"Deck",Vector3(rect.size.x,0.7,rect.size.y),Vector3(rect.get_center().x,top-0.35,rect.get_center().y),mats.deck,true)
	for z in range(int(rect.position.y)+4,int(rect.end.y),16):
		for x in [rect.position.x+0.9,rect.end.x-0.9]:
			visual(cylinder(0.4,11),node,"Piling",Vector3(x,top-5.4,z),mats.wood)
			bollard(node,Vector3(x,top,z))
		box(node,"DeckSeam",Vector3(rect.size.x,0.013,0.06),Vector3(rect.get_center().x,top+0.01,z),mats.iron)
	for z in range(int(rect.position.y)+18,int(rect.end.y),50):
		lamp(node,Vector3(rect.position.x+1.8,top,z),6,true)

func make_harbor() -> void:
	var harbor := scene.get_node("Harbor")
	# The existing concrete apron is retained. New timber fingers begin at its edge.
	pier(harbor,"WestCargoPier",Rect2(1055,936,25,270),0.035)
	pier(harbor,"EastCargoPier",Rect2(1190,936,25,270),0.035)
	pier(harbor,"OuterBoardwalk",Rect2(1055,1190,160,16),0.035)
	pier(harbor,"FishingFinger",Rect2(1080,1032,69,12),0.035)
	pier(harbor,"FerryFinger",Rect2(1130,1110,60,14),0.035)
	# Expose believable retaining walls around the old apron instead of a floating slab.
	bank_wall(harbor,Vector2(1010,800),Vector2(1010,940))
	bank_wall(harbor,Vector2(1250,800),Vector2(1250,940))
	for x in [1020,1110,1238]:
		lamp(harbor,Vector3(x,0.03,902),10,true)
	for i in 18:
		var p := Vector3(1038+(i%6)*10,1.5,820+int(i/6)*19)
		shipping_container(harbor,p,i)
		if i%3==0: shipping_container(harbor,p+Vector3.UP*3.0,i+1)
	crane(harbor,Vector3(1042,0,915),-1)
	crane(harbor,Vector3(1226,0,913),1)
	var shed := add(Node3D.new(),harbor,"HarborOffice") as Node3D
	shed.position=Vector3(1200,0,842)
	box(shed,"Building",Vector3(36,9,23),Vector3(0,4.5,0),mats.concrete,true)
	box(shed,"Roof",Vector3(38,0.7,25),Vector3(0,9.2,0),mats.roof,true)
	for x in [-12,-6,0,6,12]: box(shed,"OfficeWindow",Vector3(3,2.2,0.08),Vector3(x,5,11.55),mats.warm)
	label(shed,"HARBOR AUTHORITY",Vector3(0,7.7,11.7),0.025,0)
	box(harbor,"PierSign",Vector3(30,2.6,0.4),Vector3(1130,5,933),mats.roof)
	for x in [1116,1144]: box(harbor,"SignPost",Vector3(0.24,6.3,0.24),Vector3(x,3.15,933),mats.iron)
	label(harbor,"SOUTH HARBOR  /  PIER 07",Vector3(1130,5,933.23),0.031,0)
	for p in [Vector3(1090,0,927),Vector3(1167,0,920),Vector3(1234,0,885)]:
		for i in 4: box(harbor,"CargoCrate",Vector3(1.6,1.6,1.6),p+Vector3(i%2*1.8,0.8,int(i/2)*1.8),mats.wood,true)

func shipping_container(parent: Node, p: Vector3, index: int) -> void:
	var mat: Material=[mats.rust,mats.roof,mats.red,mats.white,mats.yellow][index%5]
	var container := box(parent,"Container",Vector3(6,3,12),p,mat,true)
	for z in range(-5,6,2):
		for x in [-3.03,3.03]: box(container,"Corrugation",Vector3(0.08,2.75,0.13),Vector3(x,0,z),mats.iron)
	for x in [-1.5,1.5]: box(container,"DoorLock",Vector3(0.08,2.6,0.09),Vector3(x,0,6.05),mats.iron)

func crane(parent: Node, p: Vector3, side: int) -> void:
	var node := add(Node3D.new(),parent,"DockCrane") as Node3D
	node.position=p
	box(node,"Foot",Vector3(12,2,12),Vector3(0,1,0),mats.concrete,true)
	for x in [-3,3]:
		box(node,"Tower",Vector3(0.8,41,0.8),Vector3(x,22,0),mats.yellow,true)
		for y in range(4,42,6): rod(node,"Lattice",Vector3(-3,y,0),Vector3(3,y+6,0),0.12,mats.yellow)
	box(node,"Boom",Vector3(38,1.0,1.3),Vector3(side*12,43,0),mats.yellow)
	box(node,"Cab",Vector3(5,4,4),Vector3(side*4,40,0),mats.roof,true)
	box(node,"CabGlass",Vector3(4,2,0.1),Vector3(side*4,40,2.05),mats.glass)
	rod(node,"Stay",Vector3(0,48,0),Vector3(side*29,43,0),0.1,mats.iron)
	rod(node,"Cable",Vector3(side*27,43,0),Vector3(side*27,11,0),0.075,mats.iron)
	visual(cylinder(0.7,1.8),node,"Hook",Vector3(side*27,10.5,0),mats.iron)

func label(parent: Node, text: String, p: Vector3, pixels: float, yaw: float) -> void:
	var sign := Label3D.new()
	sign.text=text
	sign.font_size=64
	sign.pixel_size=pixels
	sign.modulate=Color("e0d9b9")
	sign.outline_size=6
	sign.no_depth_test=false
	sign.position=p
	sign.rotation.y=yaw
	add(sign,parent,"Sign")

func island_point(angle: float, radius: float, y: float) -> Vector3:
	var rough := 1.0+0.055*sin(angle*5.0)+0.035*cos(angle*9.0)
	if is_equal_approx(y,11.0): y += sin(angle*11.0)*1.8+cos(angle*17.0)*0.8
	if is_equal_approx(y,2.0): y += sin(angle*7.0)*0.8
	return Vector3(cos(angle)*310*radius*rough,y,sin(angle)*240*radius*rough)

func make_island() -> void:
	var island := scene.get_node("PrisonIsland") as Node3D
	island.position=ISLAND
	var tool := new_surface()
	var rings := [[0.0,15.0],[0.66,15.0],[0.8,11.0],[0.94,2.0],[1.06,-3.0],[1.25,-15.0]]
	for r in rings.size()-1:
		for i in 80:
			var a := float(i)/80*TAU
			var b := float(i+1)/80*TAU
			var p0 := island_point(a,rings[r][0],rings[r][1])
			var p1 := island_point(b,rings[r][0],rings[r][1])
			var p2 := island_point(b,rings[r+1][0],rings[r+1][1])
			var p3 := island_point(a,rings[r+1][0],rings[r+1][1])
			var color := Color("5b6650") if r==0 else Color("626c6b").lerp(Color("89908a"),rng.randf()*0.5)
			tri(tool,p0,p2,p1,color)
			tri(tool,p0,p3,p2,color)
	surface("IslandTerrain",tool,island,mats.vertex,true)
	var foam := new_surface()
	for i in 120:
		var a:=float(i)/120*TAU
		var b:=float(i+1)/120*TAU
		var p0:=island_point(a,1.035,SEA_LEVEL+0.045)
		var p1:=island_point(b,1.035,SEA_LEVEL+0.045)
		var p2:=island_point(b,1.067,SEA_LEVEL+0.045)
		var p3:=island_point(a,1.067,SEA_LEVEL+0.045)
		tri(foam,p0,p2,p1,Color(1,1,1,0.8))
		tri(foam,p0,p3,p2,Color(1,1,1,0.8))
	surface("IslandSurf",foam,island,mats.foam)
	# Scattered outcrops break up the cliff silhouette and provide landing perches.
	for i in 30:
		var angle:=float(i)/30*TAU
		if absf(angle-PI*1.5)<0.18: continue
		var rock_mesh:=SphereMesh.new()
		rock_mesh.radius=1
		rock_mesh.height=2
		rock_mesh.radial_segments=7
		rock_mesh.rings=3
		var rock:=visual(rock_mesh,island,"CoastalOutcrop",island_point(angle,0.96,0.0),mats.stone)
		rock.scale=Vector3(rng.randf_range(6,13),rng.randf_range(3,7),rng.randf_range(5,11))
		collision(rock)
	var prison := add(Node3D.new(),island,"BlackwaterPenitentiary") as Node3D
	prison.position.y=15
	box(prison,"Yard",Vector3(246,0.16,216),Vector3(0,0.04,0),mats.concrete,true)
	for x in [-125,125]: box(prison,"PerimeterWall",Vector3(3,9,223),Vector3(x,4.5,0),mats.concrete,true)
	box(prison,"SouthWall",Vector3(253,9,3),Vector3(0,4.5,110),mats.concrete,true)
	for x in [-68,68]: box(prison,"NorthWall",Vector3(114,9,3),Vector3(x,4.5,-110),mats.concrete,true)
	box(prison,"GateLintel",Vector3(22,3,3),Vector3(0,9,-110),mats.concrete,true)
	for x in [-10,10]: box(prison,"GatePillar",Vector3(2,11,4),Vector3(x,5.5,-110),mats.stone,true)
	label(prison,"BLACKWATER PENITENTIARY",Vector3(0,9,-112.1),0.018,PI)
	# Open gate and clear center corridor allow traversal through the compound.
	for x in [-66,66]: cell_block(prison,Vector3(x,0,-8))
	box(prison,"Administration",Vector3(68,13,27),Vector3(0,6.5,77),mats.stone,true)
	box(prison,"AdminRoof",Vector3(70,0.7,29),Vector3(0,13.2,77),mats.roof,true)
	for x in range(-28,29,7): box(prison,"AdminWindow",Vector3(2,2,0.08),Vector3(x,8,63.45),mats.warm)
	box(prison,"ExerciseCourt",Vector3(27,0.045,45),Vector3(0,0.15,0),mats.court)
	for x in [-12,12]: box(prison,"CourtLine",Vector3(0.15,0.02,42),Vector3(x,0.18,0),mats.white)
	for z in [-21,0,21]: box(prison,"CourtLine",Vector3(24,0.02,0.15),Vector3(0,0.18,z),mats.white)
	for z in [-23,23]:
		rod(prison,"HoopPost",Vector3(0,0,z),Vector3(0,4,z),0.12,mats.iron)
		box(prison,"Backboard",Vector3(2.3,1.3,0.15),Vector3(0,3.8,z),mats.white)
	for x in [-125,125]:
		for z in [-110,110]: guard_tower(prison,Vector3(x,0,z))
	for x in [-123,123]:
		box(prison,"WallWalk",Vector3(5,0.4,213),Vector3(x,9,0),mats.stone,true)
		for y in [9.8,10.2,10.6]: rod(prison,"SecurityWire",Vector3(x,y,-104),Vector3(x,y,104),0.035,mats.iron)
	for z in [-109,109]:
		for y in [9.8,10.2,10.6]: rod(prison,"SecurityWire",Vector3(-119,y,z),Vector3(119,y,z),0.035,mats.iron)
	for x in [-25,25]:
		for z in [-84,49]: lamp(prison,Vector3(x,0,z),8,true)
	# A northern landing, sloping access road and gate make the island approachable.
	pier(island,"PrisonLanding",Rect2(-13,-355,26,114),2.0)
	var ramp := new_surface()
	tri(ramp,Vector3(-7,2,-244),Vector3(7,2,-244),Vector3(7,15.205,-156))
	tri(ramp,Vector3(-7,2,-244),Vector3(7,15.205,-156),Vector3(-7,15.205,-156))
	surface("IslandAccessRamp",ramp,island,mats.concrete,true)
	box(island,"GateApproach",Vector3(14,0.25,48),Vector3(0,15.08,-132),mats.concrete,true)
	lighthouse(island,Vector3(216,8,35))
	var marker := Marker3D.new()
	marker.position=Vector3(0,18,-82)
	add(marker,island,"PrisonArrival")

func cell_block(parent: Node, p: Vector3) -> void:
	var node := add(Node3D.new(),parent,"CellBlock") as Node3D
	node.position=p
	box(node,"Building",Vector3(38,22,112),Vector3(0,11,0),mats.concrete,true)
	box(node,"Roof",Vector3(40,0.8,114),Vector3(0,22.3,0),mats.roof,true)
	for side in [-1,1]:
		for level in [5,11,17]:
			for z in range(-48,49,8):
				box(node,"CellWindow",Vector3(0.1,2.0,1.5),Vector3(side*19.08,level,z),mats.warm)
				for offset in [-0.45,0.0,0.45]: box(node,"WindowBar",Vector3(0.14,2.1,0.075),Vector3(side*19.16,level,z+offset),mats.iron)
	for z in [-35,20]: box(node,"RoofVent",Vector3(4,2.5,6),Vector3(0,23.6,z),mats.iron,true)

func guard_tower(parent: Node, p: Vector3) -> void:
	var tower := add(Node3D.new(),parent,"GuardTower") as Node3D
	tower.position=p
	box(tower,"Shaft",Vector3(7,19,7),Vector3(0,9.5,0),mats.stone,true)
	box(tower,"ObservationRoom",Vector3(11,4.5,11),Vector3(0,20.8,0),mats.concrete,true)
	for side in [-1,1]:
		box(tower,"Glass",Vector3(9,1.8,0.09),Vector3(0,21.3,side*5.55),mats.cool)
		box(tower,"Glass",Vector3(0.09,1.8,9),Vector3(side*5.55,21.3,0),mats.cool)
	box(tower,"Roof",Vector3(13,0.8,13),Vector3(0,23.5,0),mats.roof,true)
	searchlight(tower,Vector3(0,24.5,0),atan2(p.x,p.z),140)

func searchlight(parent: Node, p: Vector3, yaw: float, distance: float) -> void:
	var pivot := add(Node3D.new(),parent,"SearchlightPivot") as Node3D
	pivot.position=p
	pivot.rotation.y=yaw
	box(pivot,"Housing",Vector3(1.2,0.8,1.6),Vector3.ZERO,mats.iron)
	box(pivot,"Lens",Vector3(0.9,0.6,0.06),Vector3(0,0,-0.83),mats.cool)
	var light := SpotLight3D.new()
	light.rotation.x=-0.45
	light.light_color=Color("c7dcf3")
	light.light_energy=7.0
	light.spot_range=distance
	light.spot_angle=23
	light.spot_attenuation=0.7
	light.distance_fade_enabled=true
	light.distance_fade_begin=350
	light.distance_fade_length=200
	light.set_meta("searchlight",true)
	add(light,pivot,"Searchlight")

func lighthouse(parent: Node, p: Vector3) -> void:
	var tower := add(Node3D.new(),parent,"IslandBeacon") as Node3D
	tower.position=p
	var shaft := visual(cylinder(5,34,3.5),tower,"Tower",Vector3(0,17,0),mats.white)
	collision(shaft)
	visual(cylinder(4.35,4,4.15),tower,"RedBand",Vector3(0,22,0),mats.red)
	visual(cylinder(5,1),tower,"LanternDeck",Vector3(0,34,0),mats.iron)
	visual(cylinder(3.4,4),tower,"Lantern",Vector3(0,36,0),mats.warm)
	visual(cylinder(5,4,0),tower,"Roof",Vector3(0,40,0),mats.roof)
	searchlight(tower,Vector3(0,36,0),0,280)

func hull_mesh(width: float, length: float) -> ArrayMesh:
	var tool:=new_surface()
	var outline: Array[Vector2]=[Vector2(-0.35,-0.5),Vector2(0.35,-0.5),Vector2(0.5,-0.28),Vector2(0.47,0.28),Vector2(0.23,0.46),Vector2(0,0.56),Vector2(-0.23,0.46),Vector2(-0.47,0.28),Vector2(-0.5,-0.28)]
	for i in outline.size():
		var j: int=(i+1)%outline.size()
		var a:=Vector3(outline[i].x*width,1.6,outline[i].y*length)
		var b:=Vector3(outline[j].x*width,1.6,outline[j].y*length)
		var c:=Vector3(outline[j].x*width*0.72,-1.4,outline[j].y*length*0.85)
		var d:=Vector3(outline[i].x*width*0.72,-1.4,outline[i].y*length*0.85)
		tri(tool,a,d,c)
		tri(tool,a,c,b)
		tri(tool,Vector3(0,1.6,0),a,b)
		tri(tool,Vector3(0,-1.4,0),c,d)
	return tool.commit()

func boat(name: String, kind: String, p: Vector3, yaw: float) -> void:
	var root_node := AnimatableBody3D.new()
	root_node.sync_to_physics=false
	root_node.position=p
	root_node.rotation.y=yaw
	add(root_node,scene.get_node("Boats"),name)
	root_node.set_meta("kind",kind)
	var width: float=10 if kind=="ferry" else (7 if kind=="tug" else 4.5)
	var length: float=36 if kind=="ferry" else (19 if kind=="tug" else 14)
	var hull:=hull_mesh(width,length)
	var hull_mat: Material=mats.red if kind=="tug" else (mats.roof if kind=="fishing" else mats.white)
	visual(hull,root_node,"Hull",Vector3.ZERO,hull_mat)
	var shape:=CollisionShape3D.new()
	shape.shape=hull.create_convex_shape()
	add(shape,root_node,"HullCollision")
	box(root_node,"Deck",Vector3(width*0.77,0.13,length*0.72),Vector3(0,1.7,0),mats.wood)
	if kind=="sail":
		rod(root_node,"Mast",Vector3(0,1.8,0),Vector3(0,19,0),0.12,mats.iron)
		rod(root_node,"Boom",Vector3(0,3,0),Vector3(0,3,-5.5),0.09,mats.iron)
		var sail:=new_surface()
		tri(sail,Vector3(0,18,0),Vector3(0,3,-5.7),Vector3(0,3,0))
		tri(sail,Vector3(0,16,0.4),Vector3(0,3,0.4),Vector3(0,3,6))
		var cloth: StandardMaterial3D=mats.white.duplicate()
		cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
		visual(sail.commit(),root_node,"Sails",Vector3.ZERO,cloth)
		box(root_node,"Cabin",Vector3(2.8,1.2,4.5),Vector3(0,2.25,-1),mats.white)
	else:
		var cabin_z: float=2 if kind=="fishing" else -2
		var cabin:=box(root_node,"Wheelhouse",Vector3(width*0.7,3.3,length*0.27),Vector3(0,3.4,cabin_z),mats.white)
		box(cabin,"FrontGlass",Vector3(width*0.57,1.1,0.06),Vector3(0,0.5,length*0.135+0.04),mats.glass)
		for side in [-1,1]: box(cabin,"SideGlass",Vector3(0.06,1.1,length*0.2),Vector3(side*width*0.35,0.5,0),mats.glass)
		box(root_node,"Roof",Vector3(width*0.78,0.25,length*0.31),Vector3(0,5.2,cabin_z),mats.roof)
		rod(root_node,"Antenna",Vector3(0,5.2,cabin_z),Vector3(0,8,cabin_z),0.07,mats.iron)
		if kind=="ferry":
			box(root_node,"PassengerDeck",Vector3(8,2.4,13),Vector3(0,3,-10),mats.white)
			for z in range(-15,-4,2):
				for x in [-4.05,4.05]: box(root_node,"PassengerWindow",Vector3(0.06,1.2,1.3),Vector3(x,3.4,z),mats.warm)
		elif kind=="tug":
			visual(cylinder(0.65,3),root_node,"Exhaust",Vector3(0,6,-4),mats.red)
			for z in [-6,-2,2,6]:
				for side in [-1,1]:
					var tire := TorusMesh.new()
					tire.inner_radius=0.4
					tire.outer_radius=0.75
					tire.rings=12
					tire.ring_segments=6
					var fender:=visual(tire,root_node,"TireFender",Vector3(side*3.5,1,z),mats.iron)
					fender.rotation.z=PI*0.5
		else:
			for x in [-1.5,1.5]: rod(root_node,"FishingRig",Vector3(x,2,-4),Vector3(x,7,-4),0.08,mats.iron)
			rod(root_node,"RigCrossbar",Vector3(-1.5,7,-4),Vector3(1.5,7,-4),0.08,mats.iron)
			for z in [-4,-2]: box(root_node,"FishCrate",Vector3(1.2,0.8,1.2),Vector3(0,2.15,z),mats.yellow)
	for side in [-1,1]:
		var light_mat: Material=mats.redlight if side<0 else mats.greenlight
		box(root_node,"NavigationLens",Vector3(0.15,0.14,0.3),Vector3(side*width*0.4,2.1,1),light_mat)
		rod(root_node,"Rail",Vector3(side*width*0.38,2.5,-length*0.36),Vector3(side*width*0.38,2.5,length*0.27),0.04,mats.iron)
		for z in [-length*0.36,0,length*0.27]: rod(root_node,"Stanchion",Vector3(side*width*0.38,1.7,z),Vector3(side*width*0.38,2.5,z),0.035,mats.iron)

func make_boats() -> void:
	boat("HarborTug","tug",Vector3(1091,SEA_LEVEL,980),0)
	boat("FishingTrawler","fishing",Vector3(1120,SEA_LEVEL,1021),PI*0.5)
	boat("PassengerFerry","ferry",Vector3(1150,SEA_LEVEL,1137),PI*0.5)
	boat("SloopAtMooring","sail",Vector3(1227,SEA_LEVEL,1110),0.2)
	boat("OuterHarborSailboat","sail",Vector3(760,SEA_LEVEL,1470),-0.6)
	boat("AnchoredCoaster","ferry",Vector3(-170,SEA_LEVEL,1750),0.6)
	boat("PrisonLaunch","tug",ISLAND+Vector3(28,SEA_LEVEL,-318),0)
	# Short boats are moored between crossings, never beneath the low road decks.
	boat("RiverFishingBoat","fishing",Vector3(132,SEA_LEVEL,-228),0.1)
	boat("RiverSloop","sail",Vector3(295,SEA_LEVEL,470),-0.2)

func make_navigation() -> void:
	var group:=scene.get_node("Navigation")
	for i in 8:
		var side:=1 if i%2==0 else -1
		var p:=Vector3(180+side*(95+i*7),SEA_LEVEL,850+i*75)
		var buoy:=add(Node3D.new(),group,"ChannelBuoy") as Node3D
		buoy.position=p
		var mat: Material=mats.red if side<0 else mats.grass
		visual(cylinder(1.3,0.6),buoy,"Float",Vector3(0,0.25,0),mat)
		visual(cylinder(0.6,2.5,0.35),buoy,"Tower",Vector3(0,1.7,0),mat)
		visual(cylinder(0.17,0.35),buoy,"Beacon",Vector3(0,3.15,0),mats.redlight if side<0 else mats.greenlight)

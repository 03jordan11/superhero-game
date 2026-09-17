extends "res://assets/waterfront/tools/generate_waterfront.gd"
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
const REGION_OUT:="res://assets/coastal-airport/"
const LAND=preload("res://scripts/coastal_landscape.gd")
var airport: Node3D
var trees_total:=0

func generate() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run with a graphics renderer to preserve MultiMesh buffers.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(REGION_OUT+"meshes")
	DirAccess.make_dir_recursive_absolute(REGION_OUT+"textures")
	rng.seed=49783
	scene=Node3D.new()
	scene.name="CoastalRegion"
	scene.set_script(load("res://scripts/coastal_airport.gd"))
	for pair in [["concrete","9aabaf"],["asphalt","303a40"],["white","e5e4d8"],["blue","227d98"],["red","b73834"],["glass","234958"],["iron","303c40"],["sand","aea389"],["grass","506a45"],["black","142125"],["yellow","e3b948"]]: mats[pair[0]]=material(Color(pair[1]))
	mats.vertex=material(Color.WHITE)
	mats.vertex.vertex_color_use_as_albedo=true
	mats.vertex.vertex_color_is_srgb=true
	for entry in [["warm","ffe0a8",3.0],["cool","85dce9",3.0],["runway","e7eddf",5.0],["taxi","3188ff",4.0],["green","63f4aa",4.0],["redlight","ff5140",4.0]]:
		mats[entry[0]]=glowing(Color(entry[1]),entry[2])
	make_land()
	make_forests()
	make_horizon()
	airport=group(scene,"Airport",Vector3.ZERO)
	make_airfield()
	make_terminal()
	make_airplanes()
	make_access_road()
	for batch in scene.find_children("*","MultiMeshInstance3D",true,false): assert(not batch.multimesh.buffer.is_empty(),"Empty batch: "+batch.name)
	var restored := TREES.restore_saved_layout(scene,"res://scenes/coastal_region.tscn")
	if restored >= 0: trees_total = restored
	scene.set_meta("tree_count",trees_total)
	var packed:=PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/coastal_region.tscn")==OK)
	print("Coastal region: airport, 2 scheduled flights, 2 parked jets, %d trees, 60 km terrain and panorama horizon."%trees_total)
	scene.free()
	quit()

func group(parent: Node, node_name: String, p: Vector3) -> Node3D:
	var node:=add(Node3D.new(),parent,node_name) as Node3D
	node.position=p
	return node

func surface(node_name: String, tool: SurfaceTool, parent: Node, mat: Material, solid := false) -> MeshInstance3D:
	var mesh:=tool.commit()
	var path:=REGION_OUT+"meshes/"+node_name.to_snake_case()+".res"
	assert(ResourceSaver.save(mesh,path)==OK)
	mesh.take_over_path(path)
	var node:=visual(mesh,parent,node_name,Vector3.ZERO,mat)
	if solid: collision(node)
	return node

func land_point(x: float,z: float) -> Vector3: return Vector3(x,LAND.height_at(x,z),z)

func land_quad(tool: SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3) -> void:
	var center: Vector3=(a+b+c+d)*0.25
	var color:=Color("516443").lerp(Color("657449"),(0.5+sin(center.x/180)*cos(center.z/240)*0.35)*0.35)
	if LAND.coast_z(center.x)-center.z<100: color=Color("b6ab8f")
	tri(tool,a,b,c,color)
	tri(tool,a,c,d,color)

func make_land() -> void:
	var terrain:=group(scene,"Landscape",Vector3.ZERO)
	var xs: Array[float]=[]
	var zs: Array[float]=[]
	for x in range(-30000,30001,1000):
		if abs(x)>8000: xs.append(float(x))
	for x in range(-8000,8001,100): xs.append(float(x))
	# Match the access road's samples through the airport plateau transition.
	for x in range(-3300,-1459,20):
		if float(x) not in xs: xs.append(float(x))
	for z in range(-30000,-5000,1000): zs.append(float(z))
	for z in range(-5000,801,100): zs.append(float(z))
	for z in [-489.0,-480.0,-471.0,-460.0]: zs.append(z)
	xs.sort()
	zs.sort()
	var tool:=new_surface()
	for i in xs.size()-1:
		var a: float=xs[i]
		var b: float=xs[i+1]
		for j in zs.size()-1:
			if a>=-1500 and b<=1500 and zs[j]>=-1000: continue
			land_quad(tool,land_point(a,zs[j]),land_point(b,zs[j]),land_point(b,zs[j+1]),land_point(a,zs[j+1]))
		if a>=-1500 and b<=1500: continue
		var ca: float=LAND.coast_z(a)
		var cb: float=LAND.coast_z(b)
		var weights: Array[float]=[0,0.25,0.5,0.75,0.9,0.96,1]
		for j in weights.size()-1:
			land_quad(tool,land_point(a,lerpf(800,ca,weights[j])),land_point(b,lerpf(800,cb,weights[j])),land_point(b,lerpf(800,cb,weights[j+1])),land_point(a,lerpf(800,ca,weights[j+1])))
		var p0:=land_point(a,ca)
		var p1:=land_point(b,cb)
		tri(tool,p0,Vector3(a,-5,ca),Vector3(b,-5,cb),Color("807c66"))
		tri(tool,p0,Vector3(b,-5,cb),p1,Color("807c66"))
	surface("CoastalTerrain",tool,terrain,mats.vertex,true)
	var beach:=new_surface()
	for x in range(-14000,14000,100):
		if abs(x)<1900: continue
		var a:=Vector3(x,-1.35,LAND.coast_z(x)-23)
		var b:=Vector3(x+100,-1.35,LAND.coast_z(x+100)-23)
		tri(beach,a,b,b+Vector3(0,0,5))
		tri(beach,a,b+Vector3(0,0,5),a+Vector3(0,0,5))
	var foam:=material(Color("95b9bd"))
	foam.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.albedo_color.a=0.35
	surface("BeachWash",beach,terrain,foam)

func make_forests() -> void:
	var batches: Dictionary={}
	for i in 15000:
		var x:=rng.randf_range(-10500,10500)
		var z:=rng.randf_range(-6500,2100)
		var p:=Vector2(x,z)
		if Rect2(-1580,-1080,3160,1950).has_point(p) or LAND.OLD_NORTH.grow(70).has_point(p): continue
		if LAND.AIRPORT.grow(100).has_point(p): continue
		if x>-3300 and x< -1450 and absf(z+480)<28: continue
		if z>LAND.coast_z(x)-130: continue
		if rng.randf()>0.45+0.5*sin(x/370)*cos(z/310): continue
		var key:=Vector3i(floori(x/350),floori(z/350),i%3)
		if not batches.has(key): batches[key]=[]
		var size:=rng.randf_range(1.1,2.7)
		batches[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),land_point(x,z)))
	for key in batches:
		var species: String = "pine" if key.z!=0 else "oak"
		TREES.group(scene,scene,"CoastalForest",species,batches[key],12000,0,false)
		trees_total+=batches[key].size()

func batch(parent: Node,node_name: String,mesh:Mesh,poses:Array,mat:Material,view_distance:=0.0) -> void:
	var node:=MultiMeshInstance3D.new()
	node.multimesh=MultiMesh.new()
	node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	node.multimesh.mesh=mesh
	node.multimesh.instance_count=poses.size()
	for i in poses.size(): node.multimesh.set_instance_transform(i,poses[i])
	node.material_override=mat
	node.visibility_range_end=view_distance
	add(node,parent,node_name)

func make_horizon() -> void:
	# Original transparent landscape image: three distant ridges baked into one panorama.
	var panorama:=Image.create(2048,512,false,Image.FORMAT_RGBA8)
	panorama.fill(Color.TRANSPARENT)
	for x in 2048:
		var u:=float(x)/2048
		var cell:=floorf(u*61)
		var a:=fposmod(sin(cell*91.37)*43758.5,1.0)
		var b:=fposmod(sin((cell+1)*91.37)*43758.5,1.0)
		var fade:=smoothstep(0,0.07,u)*(1.0-smoothstep(0.93,1,u))
		var ridge:=(0.20+absf(sin(u*27+0.3))*0.20+lerpf(a,b,fposmod(u*61,1.0))*0.22)*fade
		var near_ridge:=(0.10+absf(sin(u*38))*0.13)*fade
		var forest:=(0.02+absf(sin(u*1379))*0.009)*fade
		for y in 512:
			var h:=1.0-float(y)/511
			if h>ridge: continue
			panorama.set_pixel(x,y,Color(0.9,0.9,0.9,1) if h>near_ridge else (Color(0.45,0.45,0.45,1) if h>forest else Color(0.1,0.1,0.1,1)))
	assert(panorama.save_png(REGION_OUT+"textures/distant_landscape.png")==OK)
	var texture:=ImageTexture.create_from_image(panorama)
	assert(ResourceSaver.save(texture,REGION_OUT+"textures/distant_landscape.res")==OK)
	texture.take_over_path(REGION_OUT+"textures/distant_landscape.res")
	var tool:=new_surface()
	for i in 128:
		var a:=PI+float(i)/128*PI
		var b:=PI+float(i+1)/128*PI
		var pa:=Vector3(cos(a)*24000,-120,sin(a)*24000-1000)
		var pb:=Vector3(cos(b)*24000,-120,sin(b)*24000-1000)
		var verts: Array[Vector3]=[pa,pa+Vector3.UP*2500,pb+Vector3.UP*2500,pa,pb+Vector3.UP*2500,pb]
		var uvs: Array[Vector2]=[Vector2(float(i)/128,1),Vector2(float(i)/128,0),Vector2(float(i+1)/128,0),Vector2(float(i)/128,1),Vector2(float(i+1)/128,0),Vector2(float(i+1)/128,1)]
		for j in 6:
			tool.set_normal(Vector3.UP)
			tool.set_uv(uvs[j])
			tool.add_vertex(verts[j])
	var mat:=ShaderMaterial.new()
	mat.shader=load(REGION_OUT+"horizon.gdshader")
	mat.set_shader_parameter("panorama",texture)
	var horizon:=surface("DistantLandscape",tool,scene,mat)
	horizon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func slab(parent: Node,node_name:String,area:Rect2,y:float,mat:Material,solid:=false) -> void:
	box(parent,node_name,Vector3(area.size.x,0.12,area.size.y),Vector3(area.get_center().x,y-0.06,area.get_center().y),mat,solid)

func make_airfield() -> void:
	var field:=group(airport,"Airfield",Vector3.ZERO)
	slab(field,"Runway09_27",Rect2(-4440,174,1880,52),6.10,mats.asphalt,true)
	slab(field,"ParallelTaxiway",Rect2(-4425,30,1560,32),6.10,mats.asphalt,true)
	for x in [-4410,-2880]: slab(field,"RunwayConnector",Rect2(x-16,30,32,171),6.10,mats.asphalt,true)
	slab(field,"Apron",Rect2(-3520,-180,675,226),6.10,mats.concrete,true)
	for z in [176.0,224.0]: box(field,"RunwayEdge",Vector3(1840,0.014,0.22),Vector3(-3500,6.112,z),mats.white)
	for x in range(-4360,-2600,50): box(field,"CenterStripe",Vector3(25,0.014,0.35),Vector3(x,6.114,200),mats.white)
	for side in [-1,1]:
		var x: float=-3500+side*830
		for z in [-19,-15,-11,-7,7,11,15,19]: box(field,"ThresholdStripe",Vector3(32,0.014,2),Vector3(x,6.114,200+z),mats.white)
		label(field,"09" if side<0 else "27",Vector3(x-side*55,6.125,200),0.20,0)
		var number:=field.get_child(field.get_child_count()-1) as Label3D
		number.modulate=Color.WHITE
		number.basis=Basis(Vector3.UP,side*PI*0.5)*Basis(Vector3.RIGHT,-PI*0.5)
	for x in range(-4360,-2890,30): box(field,"TaxiStripe",Vector3(19,0.014,0.22),Vector3(x,6.114,46),mats.yellow)
	var white: Array=[]
	var blue: Array=[]
	var green: Array=[]
	var red: Array=[]
	for x in range(-4440,-2540,40):
		for z in [172,228]: white.append(Transform3D(Basis.IDENTITY,Vector3(x,6.22,z)))
	for x in range(-4420,-2840,35):
		for z in [28,64]: blue.append(Transform3D(Basis.IDENTITY,Vector3(x,6.22,z)))
	for z in range(178,225,4):
		green.append(Transform3D(Basis.IDENTITY,Vector3(-4438,6.22,z)))
		red.append(Transform3D(Basis.IDENTITY,Vector3(-2562,6.22,z)))
	for x in range(-4780,-4440,30):
		for z in [196,200,204]: white.append(Transform3D(Basis.IDENTITY,Vector3(x,6.3,z)))
	var lamp:=SphereMesh.new()
	lamp.radius=0.45
	lamp.height=0.9
	lamp.radial_segments=6
	lamp.rings=3
	for entry in [[white,mats.runway],[blue,mats.taxi],[green,mats.green],[red,mats.redlight]]: batch(field,"AirfieldLights",lamp,entry[0],entry[1])
	for p in [Vector3(-4420,6,90),Vector3(-2590,6,90)]:
		rod(field,"WindsockPole",p,p+Vector3.UP*9,0.06,mats.iron)
		var sock:=visual(cylinder(0.65,4,0.25),field,"Windsock",p+Vector3(1.6,9,0),mats.red)
		sock.rotation.z=PI*0.42
	for x in [-4460,-2540]:
		box(field,"RunwaySign",Vector3(5,1.4,0.16),Vector3(x,6.9,142),mats.red)
		label(field,"09 — 27",Vector3(x,6.9,142.1),0.014,0)

func light(parent:Node,p:Vector3,energy:=3.0,reach:=45.0) -> void:
	var node:=OmniLight3D.new()
	node.position=p
	node.light_color=Color("d5e8f1")
	node.light_energy=energy
	node.omni_range=reach
	node.distance_fade_enabled=true
	node.distance_fade_begin=300
	node.distance_fade_length=150
	add(node,parent,"ApronLight")

func make_terminal() -> void:
	var buildings:=group(airport,"Terminal",Vector3(-3200,6,-285))
	box(buildings,"TerminalHall",Vector3(190,12,62),Vector3(0,6,0),mats.concrete,true)
	box(buildings,"GlassFront",Vector3(185,8,0.2),Vector3(0,6,-31.2),mats.cool)
	box(buildings,"FloatingRoof",Vector3(206,1.2,78),Vector3(0,12.6,0),mats.white,true)
	for x in range(-90,100,15): box(buildings,"WindowMullion",Vector3(0.45,8,0.45),Vector3(x,6,-31.5),mats.white)
	box(buildings,"Concourse",Vector3(500,7,30),Vector3(-35,3.5,85),mats.concrete,true)
	box(buildings,"ConcourseWindows",Vector3(495,4,0.15),Vector3(-35,4.3,100.15),mats.cool)
	box(buildings,"HallConnector",Vector3(30,6,65),Vector3(0,3,45),mats.glass,true)
	label(buildings,"COASTAL INTERNATIONAL",Vector3(0,16,-10),0.072,PI)
	buildings.get_child(buildings.get_child_count()-1).double_sided=false
	label(buildings,"COASTAL INTERNATIONAL",Vector3(0,16,10),0.072,0)
	buildings.get_child(buildings.get_child_count()-1).double_sided=false
	label(buildings,"ARRIVALS    •    DEPARTURES",Vector3(0,5,-31.5),0.045,PI)
	for x in [-3390,-3220,-3050]:
		box(airport,"JetBridge",Vector3(4,3,62),Vector3(x+12,11,-160),mats.concrete,true)
		box(airport,"GateHead",Vector3(15,3,5),Vector3(x+6,11,-128),mats.glass,true)
		label(airport,"GATE "+str(int((x+3390)/170)+1),Vector3(x+12,14,-170),0.023,0)
		for z in range(-110,20,15): box(airport,"GateGuide",Vector3(0.18,0.014,8),Vector3(x,6.114,z),mats.yellow)
	for x in [-3500,-3280,-2850]:
		rod(airport,"ApronMast",Vector3(x,6,-170),Vector3(x,31,-170),0.2,mats.iron)
		box(airport,"Floodlights",Vector3(5,0.8,1),Vector3(x,31,-170),mats.runway)
		light(airport,Vector3(x,27,-120),6,100)
	var tower:=group(airport,"ControlTower",Vector3(-3550,6,-310))
	box(tower,"TowerStem",Vector3(7,29,7),Vector3(0,14.5,0),mats.concrete,true)
	box(tower,"ControlCab",Vector3(15,6,13),Vector3(0,31,0),mats.cool,true)
	box(tower,"CabRoof",Vector3(18,1,16),Vector3(0,34.5,0),mats.white,true)
	rod(tower,"Antenna",Vector3(0,35,0),Vector3(0,44,0),0.09,mats.iron)
	strobe(tower,Vector3(0,44,0),0.0)
	for x in [-3890,-3750]:
		var hangar:=group(airport,"Hangar",Vector3(x,6,-340))
		for side in [-1,1]: box(hangar,"SideWall",Vector3(1,14,75),Vector3(side*44,7,0),mats.concrete,true)
		box(hangar,"RearWall",Vector3(88,14,1),Vector3(0,7,-37),mats.concrete,true)
		var roof:=new_surface()
		for i in 16:
			var a:=float(i)/16*PI
			var b:=float(i+1)/16*PI
			var p0:=Vector3(cos(a)*45,14+sin(a)*13,-38)
			var p1:=Vector3(cos(b)*45,14+sin(b)*13,-38)
			tri(roof,p0,p1+Vector3(0,0,76),p1)
			tri(roof,p0,p0+Vector3(0,0,76),p1+Vector3(0,0,76))
		surface("HangarRoof%d"%abs(x),roof,hangar,mats.white,true)
		label(hangar,"COASTAL  •  MAINTENANCE",Vector3(0,19,38.1),0.045,0)
	slab(airport,"ParkingLot",Rect2(-3440,-450,480,100),6.10,mats.asphalt,true)
	for x in range(-3420,-2950,14):
		for z in [-430,-375]:
			box(airport,"ParkingStripe",Vector3(0.12,0.014,14),Vector3(x,6.114,z),mats.white)
			if rng.randf()>0.45:
				box(airport,"ParkedCar",Vector3(2.3,1,4.8),Vector3(x+5,6.8,z),mats.blue if x%3==0 else mats.white)
				box(airport,"CarCabin",Vector3(2,0.8,2.5),Vector3(x+5,7.6,z),mats.glass)
	for x in [-3460,-3350,-2920]:
		box(airport,"ServiceTruck",Vector3(2.4,2,6),Vector3(x,7.1,-40),mats.yellow,true)
		box(airport,"TruckCab",Vector3(2.2,2,2.2),Vector3(x,7.1,-35.9),mats.white)

func strobe(parent: Node,p:Vector3,phase:float) -> void:
	var bulb:=SphereMesh.new()
	bulb.radius=0.3
	bulb.height=0.6
	bulb.radial_segments=6
	bulb.rings=3
	var mat:=glowing(Color("fff2d8"),9)
	var node:=visual(bulb,parent,"Strobe",p,mat)
	node.set_meta("strobe",phase)

func make_airplanes() -> void:
	var moving:=group(airport,"AirTraffic",Vector3.ZERO)
	for i in 2:
		var plane:=airliner(moving,"Flight%d"%(i+1),true)
		plane.set_meta("phase",18.0+i*100)
	for i in 2:
		var plane:=airliner(airport,"ParkedJet%d"%i,false)
		plane.position=Vector3(-3390+i*170,10,-90)
		plane.rotation.y=PI

func airliner(parent:Node,node_name:String,moving:bool) -> Node3D:
	var plane: Node3D=AnimatableBody3D.new() if moving else StaticBody3D.new()
	# Movement is already applied from the region's physics tick. Avoid deferred
	# transform synchronization undoing a scripted position/basis update.
	if moving: plane.sync_to_physics=false
	add(plane,parent,node_name)
	var fuselage:=SphereMesh.new()
	fuselage.radius=1
	fuselage.height=2
	fuselage.radial_segments=20
	fuselage.rings=10
	visual(fuselage,plane,"Fuselage",Vector3.ZERO,mats.white).scale=Vector3(2.8,2.8,24)
	visual(fuselage,plane,"Cockpit",Vector3(0,0.65,22.4),mats.glass).scale=Vector3(1.7,0.9,1.2)
	var wing:=new_surface()
	for side in [-1,1]:
		var vertices: Array[Vector3]=[Vector3(side*2.3,-0.6,6),Vector3(side*22,-0.3,-4),Vector3(side*23,-0.3,-8),Vector3(side*2.3,-0.6,-5)]
		for i in [1,2]:
			if side<0: tri(wing,vertices[0],vertices[i+1],vertices[i])
			else: tri(wing,vertices[0],vertices[i],vertices[i+1])
		for i in 4:
			var a:=vertices[i]
			var b:=vertices[(i+1)%4]
			tri(wing,a,b,b+Vector3.DOWN*0.35)
			tri(wing,a,b+Vector3.DOWN*0.35,a+Vector3.DOWN*0.35)
		var engine:=visual(cylinder(1.25,5.3),plane,"Engine",Vector3(side*8,-2,0),mats.blue)
		engine.rotation.x=PI*0.5
		var intake:=visual(cylinder(0.95,0.08),plane,"EngineIntake",Vector3(side*8,-2,2.72),mats.black)
		intake.rotation.x=PI*0.5
		var tail:=box(plane,"Tailplane",Vector3(13,0.25,5),Vector3(side*5,0.7,-18),mats.blue)
		tail.rotation.y=side*0.25
		for z in range(-14,18,2):
			var x: float=side*(2.8*sqrt(1.0-float(z*z)/(24*24))+0.04)
			box(plane,"CabinWindow",Vector3(0.08,0.45,0.6),Vector3(x,0.65,z),mats.glass)
		label(plane,"COASTAL",Vector3(side*2.87,1.3,1),0.023,side*PI*0.5)
		strobe(plane,Vector3(side*23,-0.1,-7),0.0 if side<0 else 0.12)
		var nav:=glowing(Color("ff4737") if side<0 else Color("49e891"),3)
		nav.remove_meta("night_glow")
		nav.emission_energy_multiplier=3
		visual(cylinder(0.2,0.5),plane,"NavigationLight",Vector3(side*22,-0.1,-4),nav)
	var wing_mat: StandardMaterial3D=mats.white.duplicate()
	wing_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual(wing.commit(),plane,"Wings",Vector3.ZERO,wing_mat)
	var fin:=new_surface()
	tri(fin,Vector3(0,1,-14),Vector3(0,10,-21),Vector3(0,1,-24))
	var fin_mat: StandardMaterial3D=mats.blue.duplicate()
	fin_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual(fin.commit(),plane,"TailFin",Vector3.ZERO,fin_mat)
	strobe(plane,Vector3(0,10,-21),0.75)
	var gear:=group(plane,"LandingGear",Vector3.ZERO)
	for p in [Vector3(-2,-2.4,-3),Vector3(2,-2.4,-3),Vector3(0,-2.4,16)]:
		rod(gear,"Strut",p,p+Vector3.DOWN,0.12,mats.iron)
		var wheel:=visual(cylinder(0.5,0.6),gear,"Wheel",p+Vector3.DOWN,mats.black)
		wheel.rotation.z=PI*0.5
	for entry in [[Vector3(4.8,4.8,42),Vector3.ZERO],[Vector3(40,0.35,6),Vector3(0,-0.6,-3)]]:
		var shape:=CollisionShape3D.new()
		var bounds:=BoxShape3D.new()
		bounds.size=entry[0]
		shape.shape=bounds
		shape.position=entry[1]
		add(shape,plane,"AircraftCollision")
	return plane

func make_access_road() -> void:
	var road:=new_surface()
	var paint:=new_surface()
	for i in 87:
		var x0: float=-1460-i*20
		var x1: float=-1460-(i+1)*20
		var a:=land_point(x0,-480)+Vector3.UP*lerpf(0.05,0.5,smoothstep(0,60,i*20))
		var b:=land_point(x1,-480)+Vector3.UP*0.5
		tri(road,a+Vector3(0,0,-9),b+Vector3(0,0,9),b+Vector3(0,0,-9))
		tri(road,a+Vector3(0,0,-9),a+Vector3(0,0,9),b+Vector3(0,0,9))
		for z in [-8.4,8.4]:
			tri(paint,a+Vector3(0,0.015,z),b+Vector3(0,0.015,z+0.15),b+Vector3(0,0.015,z))
			tri(paint,a+Vector3(0,0.015,z),a+Vector3(0,0.015,z+0.15),b+Vector3(0,0.015,z+0.15))
		if i%2==0: box(airport,"AccessCenterStripe",Vector3(11,0.015,0.18),(a+b)*0.5+Vector3.UP*0.02,mats.yellow)
	surface("AirportAccessRoad",road,airport,mats.asphalt,true)
	surface("AccessRoadEdges",paint,airport,mats.white)
	slab(airport,"TerminalApproach",Rect2(-3210,-489,20,130),6.12,mats.asphalt,true)
	box(airport,"AirportRoadSign",Vector3(0.2,4,12),Vector3(-1760,9,-494),mats.blue)
	label(airport,"AIRPORT\n← TERMINAL",Vector3(-1759.8,9,-494),0.026,PI*0.5)


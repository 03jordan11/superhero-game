extends "res://assets/waterfront/tools/generate_waterfront.gd"
## Reuses only the offline primitive/mesh authoring helpers; runtime is independent.
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
const FOREST_BOUNDARY = preload("res://assets/trees/tools/forest_boundary_clip.gd")
const LIFE_OUT := "res://assets/city-life/"
const NIGHT_LAYOUT = preload("res://scripts/city_night_lights.gd")
var locations: Dictionary
var occupied: Array[Rect2] = []
var walkways: Array[Rect2] = []
var fixtures: Array[Dictionary] = []
var counts: Dictionary = {}
var placement_rows: Array[Dictionary] = []

func generate() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("City dressing needs a graphics renderer to preserve MultiMesh buffers. Omit --headless.")
		quit(1)
		return
	rng.seed=618902
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	locations=JSON.parse_string(FileAccess.get_file_as_string(LIFE_OUT+"locations.json"))
	scene=Node3D.new()
	scene.name="CityLife"
	scene.set_script(load("res://scripts/city_life.gd"))
	for group in ["Baseball","Highway","Blimp"]: add(Node3D.new(),scene,group)
	for pair in [["red","b92d2c"],["cream","e3dfbd"],["iron","293135"],["chrome","a5b4b5"],["glass","416374"],["wood","786045"],["white","e5e4d9"],["yellow","eab93d"],["asphalt","373d40"],["green","385348"],["soil","a77751"],["grass","526e41"],["black","101a20"]]: mats[pair[0]]=material(Color(pair[1]))
	mats.chrome.metallic=0.75
	mats.chrome.roughness=0.28
	mats.vertex=material(Color.WHITE)
	mats.vertex.vertex_color_use_as_albedo=true
	mats.vertex.vertex_color_is_srgb=true
	mats.warm=glowing(Color("ffc981"),2.2)
	mats.neon=glowing(Color("ff4837"),4)
	mats.cool=glowing(Color("8ae4ef"),2.8)
	mats.fence=ShaderMaterial.new()
	mats.fence.shader=load(LIFE_OUT+"fence.gdshader")
	for building in layout.buildings:
		if building.node not in locations.field.get("cleared_buildings",[]): occupied.append(rect(building.rect))
	for row in layout.sidewalks: walkways.append(rect(row))
	fixtures=NIGHT_LAYOUT.build_fixture_layout(layout,72.0)
	make_baseball()
	advance_former_furniture_rng()
	make_blimp()
	make_highway()
	for node in scene.find_children("*","MultiMeshInstance3D",true,false): assert(not node.multimesh.buffer.is_empty(),"Empty batch: "+node.name)
	var restored := TREES.restore_saved_layout(scene,"res://scenes/city_life.tscn")
	if restored >= 0: counts.background_trees = restored
	var forest_chunks: Node3D = load("res://assets/trees/chunks/northern.tscn").instantiate()
	scene.get_node("Highway").add_child(forest_chunks)
	forest_chunks.owner = scene
	scene.set_meta("counts",counts)
	var packed:=PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/city_life.tscn")==OK)
	var file:=FileAccess.open(LIFE_OUT+"placements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"counts":counts,"props":placement_rows,"cleared_buildings":locations.field.cleared_buildings},"\t"))
	print("City life authored: ",counts)
	scene.free()
	quit()

func rect(row: Array) -> Rect2: return Rect2(row[0],row[1],row[2],row[3])

func surface(label_name: String, tool: SurfaceTool, parent: Node, mat: Material, solid := false) -> MeshInstance3D:
	var mesh:=tool.commit()
	if label_name == "NorthernGround" and FileAccess.file_exists(FOREST_BOUNDARY.CONFIG):
		mesh = FOREST_BOUNDARY.clip_mesh(mesh, FOREST_BOUNDARY.saved_planes())
	var path:=LIFE_OUT+"meshes/"+label_name.to_snake_case()+".res"
	assert(ResourceSaver.save(mesh,path)==OK)
	mesh.take_over_path(path)
	var node:=visual(mesh,parent,label_name,Vector3.ZERO,mat)
	if solid: collision(node)
	return node

func group_at(parent: Node, name_tag: String, p: Vector3, yaw := 0.0) -> Node3D:
	var group:=add(Node3D.new(),parent,name_tag) as Node3D
	group.position=p
	group.rotation.y=yaw
	return group

func glow_lamp(parent: Node, p: Vector3, color: Color, energy := 2.0, reach := 12.0) -> void:
	var light:=OmniLight3D.new()
	light.position=p
	light.light_color=color
	light.light_energy=energy
	light.omni_range=reach
	light.distance_fade_enabled=true
	light.distance_fade_begin=100
	light.distance_fade_length=80
	add(light,parent,"WarmLight")

func footprint(p: Vector2, size: Vector2, yaw: float) -> Rect2:
	var extents:=Vector2(absf(cos(yaw))*size.x+absf(sin(yaw))*size.y,absf(sin(yaw))*size.x+absf(cos(yaw))*size.y)
	return Rect2(p-extents*0.5,extents)

func free_space(area: Rect2, sidewalk := true) -> bool:
	for other in occupied:
		if area.grow(0.15).intersects(other): return false
	if sidewalk:
		for point in [area.position,area.position+Vector2(area.size.x,0),area.end,area.position+Vector2(0,area.size.y)]:
			var supported:=false
			for walk in walkways:
				if walk.grow(0.04).has_point(point): supported=true; break
			if not supported: return false
	for lamp in fixtures:
		var p: Vector3=lamp.transform.origin
		if area.grow(0.65).has_point(Vector2(p.x,p.z)): return false
	return true

func wall_quad(tool: SurfaceTool,a:Vector3,b:Vector3,height:float) -> void:
	tri(tool,a,b,b+Vector3.UP*height)
	tri(tool,a,b+Vector3.UP*height,a+Vector3.UP*height)

func advance_former_furniture_rng() -> void:
	# Keep terrain colors and subsequent procedural placements stable after bench removal.
	var candidates: Array[Dictionary]=[]
	for road in layout.roads:
		if road.kind!="street" or road.crossing_corridor: continue
		var area:=rect(road.rect)
		var horizontal:=int(road.axis)==0
		var length:=area.size.x if horizontal else area.size.y
		if length<35: continue
		for fraction in [0.24,0.71]:
			for side in [-1,1]:
				var p:=Vector2(area.position.x+length*fraction,area.position.y-2.75 if side<0 else area.end.y+2.75) if horizontal else Vector2(area.position.x-2.75 if side<0 else area.end.x+2.75,area.position.y+length*fraction)
				var yaw: float=(0.0 if side<0 else PI) if horizontal else (PI*0.5 if side<0 else -PI*0.5)
				candidates.append({"p":p,"yaw":yaw})
	# Deterministic Fisher-Yates; global RNG remains untouched.
	for i in range(candidates.size()-1,0,-1):
		var j:=rng.randi_range(0,i)
		var hold: Dictionary=candidates[i]
		candidates[i]=candidates[j]
		candidates[j]=hold

func make_baseball() -> void:
	var area:=rect(locations.field.rect)
	occupied.append(area)
	var field:=scene.get_node("Baseball") as Node3D
	field.position=Vector3(area.get_center().x,0.04,area.get_center().y)
	field.set_meta("rect",area)
	box(field,"SandlotGrass",Vector3(68,0.02,62),Vector3.ZERO,mats.grass)
	var home:=Vector3(0,0.035,25)
	var dirt:=new_surface()
	for i in 32:
		var a: float=lerpf(-PI*0.25,PI*0.25,float(i)/32)
		var b: float=lerpf(-PI*0.25,PI*0.25,float(i+1)/32)
		tri(dirt,home,home+Vector3(sin(a)*28,0,-cos(a)*28),home+Vector3(sin(b)*28,0,-cos(b)*28))
	surface("SandlotInfield",dirt,field,mats.soil)
	var diamond:=new_surface()
	var bases: Array[Vector3]=[home,home+Vector3(12.93,0,-12.93),home+Vector3(0,0,-25.86),home+Vector3(-12.93,0,-12.93)]
	var center:=home+Vector3(0,0,-12.93)
	for i in 4:
		var a: Vector3=center+(bases[i]-center)*0.81+Vector3.UP*0.015
		var b: Vector3=center+(bases[(i+1)%4]-center)*0.81+Vector3.UP*0.015
		tri(diamond,center+Vector3.UP*0.015,b,a)
	surface("InfieldGrassDiamond",diamond,field,mats.grass)
	for base in bases:
		var bag:=box(field,"Base",Vector3(0.48,0.05,0.48),base+Vector3.UP*0.035,mats.white)
		bag.rotation.y=PI*0.25
	visual(cylinder(1.4,0.18),field,"PitchersMound",center+Vector3.UP*0.07,mats.soil)
	box(field,"PitchersRubber",Vector3(0.6,0.03,0.15),center+Vector3.UP*0.18,mats.white)
	for side in [-1,1]:
		var end:=home+Vector3(side*32.53,0,-32.53)
		rod(field,"FoulLine",home+Vector3.UP*0.02,end+Vector3.UP*0.02,0.055,mats.white)
		rod(field,"FoulPole",end, end+Vector3.UP*7,0.08,mats.yellow)
	for i in 18:
		var a: float=lerpf(-PI*0.25,PI*0.25,float(i)/18)
		var b: float=lerpf(-PI*0.25,PI*0.25,float(i+1)/18)
		var p0:=home+Vector3(sin(a)*46,0,-cos(a)*46)
		var p1:=home+Vector3(sin(b)*46,0,-cos(b)*46)
		fence_segment(field,p0,p1,2.5)
	for segment in [[Vector3(-10,0,29),Vector3(10,0,29)],[Vector3(-10,0,29),Vector3(-16,0,22)],[Vector3(10,0,29),Vector3(16,0,22)]]: fence_segment(field,segment[0],segment[1],4.3)
	for side in [-1,1]:
		for tier in 3:
			box(field,"BleacherSeat",Vector3(9,0.15,0.9),Vector3(side*25,0.7+tier*0.5,15+tier*1.4),mats.chrome,true)
		for z in [-27,23]:
			var p:=Vector3(side*31,0,z)
			rod(field,"FloodlightMast",p,p+Vector3.UP*13,0.13,mats.iron)
			box(field,"Floodlight",Vector3(2,0.7,0.4),p+Vector3.UP*13,mats.warm)
			glow_lamp(field,p+Vector3.UP*12,Color("ffe2b3"),3.2,30)
	box(field,"Scoreboard",Vector3(12,4,0.3),Vector3(0,5.5,-26),mats.green)
	for x in [-5,5]: box(field,"ScoreboardPost",Vector3(0.2,5,0.2),Vector3(x,2.5,-26),mats.iron)
	label(field,"ALLEY CATS  |  VISITORS\n00        00\nWEST VILLAGE SANDLOT",Vector3(0,5.5,-25.78),0.012,0)
	counts.baseball_diamonds=1

func fence_segment(parent: Node,a:Vector3,b:Vector3,height:float) -> void:
	var tool:=new_surface()
	wall_quad(tool,a,b,height)
	var mesh:=visual(tool.commit(),parent,"ChainLink",Vector3.ZERO,mats.fence)
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	collision(mesh)
	rod(parent,"FencePost",a,a+Vector3.UP*height,0.055,mats.iron)
	rod(parent,"FenceRail",a+Vector3.UP*height,b+Vector3.UP*height,0.04,mats.iron)

func make_blimp() -> void:
	var blimp:=scene.get_node("Blimp") as Node3D
	blimp.position=Vector3(960,360,350)
	var balloon:=SphereMesh.new()
	balloon.radius=1
	balloon.height=2
	balloon.radial_segments=32
	balloon.rings=16
	var skin:=material(Color("c5d1c7"))
	skin.metallic=0.2
	var hull:=visual(balloon,blimp,"Envelope",Vector3.ZERO,skin)
	hull.scale=Vector3(15,13,52)
	for side in [-1,1]:
		box(blimp,"AdPanel",Vector3(0.3,12,58),Vector3(side*15.2,0,0),mats.green)
		var sign:=Label3D.new()
		sign.name="AdText"
		sign.text="ROADSTAR TIRES"
		sign.font_size=96
		sign.pixel_size=0.047
		sign.modulate=Color("fff0bd")
		sign.position=Vector3(side*15.4,1.1,0)
		sign.rotation.y=side*PI*0.5
		add(sign,blimp,"AdText")
		label(blimp,"ROADSTAR  â€¢  LEGENDARY GRIP",Vector3(side*15.4,-3.1,0),0.031,side*PI*0.5)
		var fin:=box(blimp,"TailFin",Vector3(18,0.5,14),Vector3(side*9,0,-43),mats.red)
		fin.rotation.y=side*0.18
		var engine:=visual(cylinder(1.5,5),blimp,"Engine",Vector3(side*10,-12,-15),mats.chrome)
		engine.rotation.x=PI*0.5
		var prop:=group_at(blimp,"Propeller",Vector3(side*10,-12,-18))
		box(prop,"Blade",Vector3(0.25,5.8,0.12),Vector3.ZERO,mats.black)
		box(prop,"Blade",Vector3(5.8,0.25,0.12),Vector3.ZERO,mats.black)
	box(blimp,"TailRudder",Vector3(0.5,21,15),Vector3(0,7,-42),mats.red)
	box(blimp,"Gondola",Vector3(7,4,18),Vector3(0,-14,4),mats.cream)
	box(blimp,"CockpitGlass",Vector3(6,2,0.3),Vector3(0,-13.5,13.2),mats.glass)
	for entry in [[Vector3(0,0,51),0.0],[Vector3(0,13,0),0.0],[Vector3(0,-16,0),0.8],[Vector3(-17,0,-43),0.8],[Vector3(17,0,-43),0.0]]:
		var lens:=OmniLight3D.new()
		lens.position=entry[0]
		lens.light_color=Color("ffe6bd")
		lens.light_energy=3.0
		lens.omni_range=8.0
		lens.shadow_enabled=false
		lens.distance_fade_enabled=true
		lens.distance_fade_begin=300.0
		lens.distance_fade_length=100.0
		add(lens,blimp,"Strobe")
		lens.set_meta("blink",entry[1])
	var audio_player:=AudioStreamPlayer3D.new()
	var stream:=AudioStreamWAV.load_from_file(LIFE_OUT+"audio/roadstar_ad.wav")
	assert(stream!=null and stream.get_length()>5,"Blimp ad audio must be generated first")
	ResourceSaver.save(stream,LIFE_OUT+"audio/roadstar_ad.res")
	stream.take_over_path(LIFE_OUT+"audio/roadstar_ad.res")
	audio_player.stream=stream
	audio_player.position=Vector3(0,-16,0)
	audio_player.bus=&"Voice"
	audio_player.volume_db=-12
	audio_player.unit_size=230
	audio_player.max_distance=1000
	add(audio_player,blimp,"Advertisement")
	counts.blimps=1

func highway_point(z: float) -> Vector3:
	var knots: Array[Vector2]=[Vector2(-740,-960),Vector2(-740,-1180),Vector2(-830,-1500),Vector2(-1040,-1900),Vector2(-1100,-2300),Vector2(-1100,-2845)]
	for i in knots.size()-1:
		if z>=knots[i+1].y:
			var t:=smoothstep(knots[i].y,knots[i+1].y,z)
			return Vector3(lerpf(knots[i].x,knots[i+1].x,t),0.055+smoothstep(-1000,-2000,z)*13,z)
	return Vector3(-1100,13.055,z)

func make_highway() -> void:
	var highway:=scene.get_node("Highway")
	var earth:=new_surface()
	for z in range(-4500,-1000,100):
		for x in range(-4200,2200,100): plane(earth,Rect2(x,z,100,100),-0.09,Color("516443").lerp(Color("657449"),rng.randf()*0.35))
	# Continue land past the mountain silhouettes so elevated views have a horizon.
	for area in [Rect2(-12000,-16000,24000,11500),Rect2(-12000,-4500,7800,3500),Rect2(2200,-4500,9800,3500)]:
		plane(earth,area,-0.09,Color("516443"))
	surface("NorthernGround",earth,highway,mats.vertex,true)
	var road:=new_surface()
	var paint:=new_surface()
	var slopes:=new_surface()
	var rails:=new_surface()
	var length:=1885.0
	for i in 189:
		var z0: float=-960-minf(i*10,length)
		var z1: float=-960-minf((i+1)*10,length)
		var a:=highway_point(z0)
		var b:=highway_point(z1)
		var aside: Vector3=Vector3.UP.cross((highway_point(z0-1)-highway_point(z0+1)).normalized()).normalized()
		var bside: Vector3=Vector3.UP.cross((highway_point(z1-1)-highway_point(z1+1)).normalized()).normalized()
		road_strip(road,a,b,aside,bside,-14,14,0)
		for offset in [-12.4,12.4,-1.3,1.3]: road_strip(paint,a,b,aside,bside,offset-0.075,offset+0.075,0.025)
		if i%3==0:
			for offset in [-7.0,7.0]: road_strip(paint,a,b,aside,bside,offset-0.09,offset+0.09,0.025)
		for side in [-1,1]:
			var p0: Vector3=a+aside*14*side
			var p1: Vector3=b+bside*14*side
			var p2: Vector3=b+bside*34*side; p2.y=-0.075
			var p3: Vector3=a+aside*34*side; p3.y=-0.075
			if side<0:
				tri(slopes,p0,p1,p2,Color("647253")); tri(slopes,p0,p2,p3,Color("647253"))
			else:
				tri(slopes,p0,p2,p1,Color("647253")); tri(slopes,p0,p3,p2,Color("647253"))
			var r0: Vector3=a+aside*13.4*side+Vector3.UP*0.5
			var r1: Vector3=b+bside*13.4*side+Vector3.UP*0.5
			wall_quad(rails,r0,r1,0.28)
			wall_quad(rails,r1,r0,0.28)
		if i%4==0:
			for side in [-1,1]:
				var p: Vector3=a+aside*side*13.4
				rod(highway,"GuardrailPost",p,p+Vector3.UP*0.9,0.055,mats.chrome)
			var end:=highway_point(z0-40)
			var barrier:=box(highway,"MedianBarrier",Vector3(0.6,0.8,a.distance_to(end)+0.2),(a+end)*0.5+Vector3.UP*0.4,mats.chrome,true)
			barrier.rotation.y=atan2(end.x-a.x,end.z-a.z)
	surface("CountyHighway",road,highway,mats.asphalt,true)
	surface("HighwayMarkings",paint,highway,mats.white)
	surface("HighwayEmbankments",slopes,highway,mats.vertex,true)
	surface("HighwayGuardrails",rails,highway,mats.chrome,true)
	for z in [-1100,-1720,-2440]:
		var p:=highway_point(z)
		for side in [-1,1]: rod(highway,"GantryPost",p+Vector3(side*15,0,0),p+Vector3(side*15,9,0),0.17,mats.chrome)
		rod(highway,"SignGantry",p+Vector3(-15,9,0),p+Vector3(15,9,0),0.18,mats.chrome)
		for side in [-1,1]:
			box(highway,"HighwaySign",Vector3(10,3.2,0.3),p+Vector3(side*7,7.5,0),mats.green)
			label(highway,"NORTH  7\nPINE PASS" if side<0 else "COUNTY LINE\nKEEP RIGHT",p+Vector3(side*7,7.5,0.19),0.015,0)
	make_mountains(highway)
	make_northern_forest(highway)
	make_tunnel(highway)
	counts.highway_length_m=1885

func road_strip(tool: SurfaceTool,a:Vector3,b:Vector3,aside:Vector3,bside:Vector3,left:float,right:float,lift:float) -> void:
	var p0:=a+aside*left+Vector3.UP*lift
	var p1:=a+aside*right+Vector3.UP*lift
	var p2:=b+bside*right+Vector3.UP*lift
	var p3:=b+bside*left+Vector3.UP*lift
	tri(tool,p0,p1,p2)
	tri(tool,p0,p2,p3)

func make_mountains(parent: Node) -> void:
	var tool:=new_surface()
	var peaks: Array=[Vector4(-2550,-2850,680,800),Vector4(-2700,-3850,920,1300),Vector4(-1600,-3900,840,1000),Vector4(-1000,-3750,880,820),Vector4(50,-3400,720,850),Vector4(1000,-2900,660,850),Vector4(1900,-3650,890,1200)]
	for peak in peaks:
		var origin:=Vector3(peak.x,0,peak.y)
		for ring in 3:
			var inner: float=[0.0,0.34,0.7][ring]
			var outer: float=[0.34,0.7,1.0][ring]
			for i in 18:
				var points: Array[Vector3]=[]
				for pair in [[i,inner],[i+1,inner],[i+1,outer],[i,outer]]:
					var angle: float=pair[0]/18.0*TAU
					var r: float=pair[1]
					var irregular:=1.0+sin(angle*5+peak.x)*0.16+cos(angle*3)*0.08
					var y: float=peak.z*pow(1.0-r,1.35)*(1.0+sin(angle*4)*r*0.25)
					points.append(origin+Vector3(cos(angle)*peak.w*r*irregular,y,sin(angle)*peak.w*r*irregular))
				var color:=Color("a9b7b3") if ring==0 else Color("65736c").lerp(Color("82918a"),rng.randf()*0.5)
				tri(tool,points[0],points[2],points[1],color)
				tri(tool,points[0],points[3],points[2],color)
	surface("PinePassMountains",tool,parent,mats.vertex,true)

func make_northern_forest(parent: Node) -> void:
	var batches: Dictionary={}
	for i in 5000:
		var p:=Vector3(rng.randf_range(-3200,1600),0,rng.randf_range(-3080,-1050))
		if i%2==0: p.x=highway_point(p.z).x+(-1 if i%4==0 else 1)*rng.randf_range(50,550)
		if absf(p.x-highway_point(p.z).x)<48: continue
		var key:=Vector3i(floori(p.x/250),floori(p.z/250),int(i%3==0))
		if not batches.has(key): batches[key]=[]
		var size:=rng.randf_range(1.0,2.4)
		batches[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),p))
	var tree_count:=0
	for key in batches:
		var species: String = "pine" if key.z==0 else "oak"
		TREES.group(parent,scene,"NorthernForest_%s"%str(key).replace(" ",""),species,batches[key],4500,0,false)
		tree_count+=batches[key].size()
	counts.background_trees=tree_count

func make_tunnel(parent: Node) -> void:
	var p:=highway_point(-2780)
	var tunnel:=group_at(parent,"PinePassTunnel",p)
	var tool:=new_surface()
	for i in 24:
		var a:=float(i)/24*PI
		var b:=float(i+1)/24*PI
		var p0:=Vector3(cos(a)*15,4+sin(a)*11,0)
		var p1:=Vector3(cos(b)*15,4+sin(b)*11,0)
		var p2:=Vector3(cos(b)*28,4+sin(b)*23,0)
		var p3:=Vector3(cos(a)*28,4+sin(a)*23,0)
		tri(tool,p0,p1,p2);tri(tool,p0,p2,p3)
		tri(tool,p0,p0+Vector3(0,0,-64),p1+Vector3(0,0,-64))
		tri(tool,p0,p1+Vector3(0,0,-64),p1)
		tri(tool,p3,p2,p2+Vector3(0,0,-64))
		tri(tool,p3,p2+Vector3(0,0,-64),p3+Vector3(0,0,-64))
	surface("TunnelArch",tool,tunnel,mats.chrome,true)
	for side in [-1,1]:
		box(tunnel,"PortalPier",Vector3(13,5,8),Vector3(side*21.5,1.5,-3),mats.chrome,true)
		box(tunnel,"TunnelWall",Vector3(1,5,64),Vector3(side*15.5,1.5,-32),mats.asphalt,true)
	var end_cap:=new_surface()
	for i in 24:
		var a:=float(i)/24*PI
		var b:=float(i+1)/24*PI
		tri(end_cap,Vector3(0,0,-62),Vector3(cos(b)*15,4+sin(b)*11,-62),Vector3(cos(a)*15,4+sin(a)*11,-62))
	tri(end_cap,Vector3(0,0,-62),Vector3(15,4,-62),Vector3(15,0,-62))
	tri(end_cap,Vector3(0,0,-62),Vector3(-15,0,-62),Vector3(-15,4,-62))
	surface("TunnelDarkness",end_cap,tunnel,mats.black,true)
	label(tunnel,"PINE PASS\nCOUNTY LINE",Vector3(0,22.5,0.2),0.025,0)
	for z in [-8,-25,-42]:
		for side in [-1,1]:
			box(tunnel,"TunnelLamp",Vector3(0.2,0.3,2),Vector3(side*14.7,3.5,z),mats.warm)
			glow_lamp(tunnel,Vector3(side*14,3,z),Color("ffc57e"),1.8,12)

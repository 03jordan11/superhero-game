extends "res://assets/generated-buildings/commercial/tools/generate_pack.gd"
const PROP="res://assets/props/rooftop_hvac/"
const SLUG="commercial_skyscraper_01"
func _initialize() -> void: revise.call_deferred()
func revise() -> void:
	DirAccess.make_dir_recursive_absolute(PROP)
	make_hvac()
	materials.solid=load(OUT+"materials/solid.tres")
	materials.signs_and_doors=load(OUT+"materials/signs_and_doors.tres")
	# Dedicated podium texture: limestone joints, with no painted windows.
	var stone:=Image.create(64,64,false,Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var c:=Color("a69e8a").lightened(float((x*13+y*7)%7)*.003)
			if y%32==0 or (x+(32 if y>=32 else 0))%64==0:c=c.darkened(.10)
			stone.set_pixel(x,y,c)
	stone.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(stone);save(texture,OUT+"textures/"+SLUG+"_podium_albedo.res")
	var base:=StandardMaterial3D.new();base.albedo_texture=texture;base.roughness=.9
	base.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	save(base,OUT+"materials/"+SLUG+"_podium.tres");materials.podium=base
	# Emission exactly follows the existing facade tile's window pixels and mullions.
	var emission:=Image.create(64,64,false,Image.FORMAT_RGB8);emission.fill(Color.BLACK)
	for y in 64:
		for x in 64:
			var px:=x%16;var py:=y%16;var bay:=x/16;var floor_id:=y/16
			var lit:=((int(bay)*3+int(floor_id)*5)%7)<4
			if lit and px>=3 and px<12 and px!=8 and py>=2 and py<=11:emission.set_pixel(x,y,Color("ffd6a0"))
	emission.save_png(OUT+"textures/"+SLUG+"_emission.png")
	emission.generate_mipmaps();var glow:=ImageTexture.create_from_image(emission)
	save(glow,OUT+"textures/"+SLUG+"_emission.res")
	var facade: StandardMaterial3D=load(OUT+"materials/limestone.tres").duplicate()
	facade.emission_enabled=true;facade.emission=Color.WHITE;facade.emission_texture=glow;facade.emission_energy_multiplier=0
	facade.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
	facade.set_meta("glow_energy",2.0) # Dashboard preview; runtime still starts with emission off.
	save(facade,OUT+"materials/"+SLUG+"_facade.tres");materials.facade_01=facade
	surfaces.clear()
	walls(22,20,0,5.4,"podium",Vector2(2,1))
	walls(22,20,5.4,6,"trim")
	# Four exposed terrace strips, rather than hidden caps through the tower.
	horizontal(-11,-10,11,-9,6,"roof");horizontal(-11,9,11,10,6,"roof")
	horizontal(-11,-9,-10,9,6,"roof");horizontal(10,-9,11,9,6,"roof")
	walls(20,18,6,131.4,"facade_01")
	walls(20,18,131.4,132,"trim")
	horizontal(-10,-9,10,9,132,"roof")
	quad([Vector3(-11,0,-10),Vector3(-11,0,10),Vector3(11,0,10),Vector3(11,0,-10)],[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],"roof",Vector3.DOWN)
	sign_quad(3.4,.08,3.5,20,Rect2(.5/256,240.5/256,63./256,15./256))
	var mesh:=ArrayMesh.new();var total:=0
	for key in surfaces:
		var a: Array=[];a.resize(Mesh.ARRAY_MAX);var d: Array=surfaces[key]
		a[Mesh.ARRAY_VERTEX]=d[0];a[Mesh.ARRAY_NORMAL]=d[1];a[Mesh.ARRAY_TEX_UV]=d[2];a[Mesh.ARRAY_COLOR]=d[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);mesh.surface_set_material(mesh.get_surface_count()-1,materials[key]);total+=d[0].size()/3
	save(mesh,OUT+"meshes/"+SLUG+".res")
	var body:=StaticBody3D.new();body.name=SLUG;body.set_script(load(OUT+"commercial_skyscraper_01.gd"))
	var visual:=MeshInstance3D.new();visual.name="MeshInstance3D";visual.mesh=mesh;body.add_child(visual);visual.owner=body
	shape(body,"CollisionShape3D",Vector3(22,6,20.04),Vector3(0,3,0))
	shape(body,"TowerCollision",Vector3(20,126,18),Vector3(0,69,0))
	var hvac: Node3D=load(PROP+"rooftop_hvac.tscn").instantiate();hvac.name="RooftopHVAC";hvac.position=Vector3(0,132,0);body.add_child(hvac);hvac.owner=body
	var packed:=PackedScene.new();assert(packed.pack(body)==OK);save(packed,OUT+SLUG+".tscn")
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest.json"))
	catalog[0].name=SLUG;catalog[0].height_m=134.8;catalog[0].triangles=total+48;catalog[0].surfaces=mesh.get_surface_count()+hvac.get_node("MeshInstance3D").mesh.get_surface_count()
	catalog[0].roof_height_m=132;catalog[0].building_triangles=total;catalog[0].hvac_triangles=48;catalog[0].night_illumination=true
	FileAccess.open(OUT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t"))
	print("Revised skyscraper: ",total," building + 48 HVAC = ",total+48," triangles (before 108).")
	body.free();quit()

func walls(w: float,d: float,bottom: float,top: float,mat: String,custom_uv:=Vector2.ZERO) -> void:
	var ring:=[Vector2(-w/2,-d/2),Vector2(w/2,-d/2),Vector2(w/2,d/2),Vector2(-w/2,d/2)]
	for i in 4:
		var a: Vector2=ring[i];var b: Vector2=ring[(i+1)%4]
		var u:=maxf(1,roundf(a.distance_to(b)/2.7))/4;var v:=maxf(1,roundf((top-bottom)/3.8))/4
		if custom_uv!=Vector2.ZERO:u=custom_uv.x;v=custom_uv.y
		quad([Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y)],[Vector2(0,v),Vector2(u,v),Vector2(u,0),Vector2.ZERO],mat,Vector3(b.y-a.y,0,a.x-b.x).normalized())
func horizontal(x: float,z: float,xx: float,zz: float,y: float,mat: String) -> void:
	quad([Vector3(x,y,z),Vector3(xx,y,z),Vector3(xx,y,zz),Vector3(x,y,zz)],[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],mat,Vector3.UP)
func shape(parent: Node,label: String,size: Vector3,center: Vector3) -> void:
	var node:=CollisionShape3D.new();node.name=label;var box:=BoxShape3D.new();box.size=size;node.shape=box;node.position=center;parent.add_child(node);node.owner=parent
func make_hvac() -> void:
	var hospital: Node=load("res://assets/buildings/hospital/hospital.tscn").instantiate()
	var source: Mesh=hospital.get_node("Model/Roof equipment").mesh
	var mesh:=ArrayMesh.new();var total:=0
	for s in source.get_surface_count():
		var a: Array=source.surface_get_arrays(s);var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count:=0
		for i in range(0,ids.size(),3):
			var keep:=true
			for k in 3:
				var v: Vector3=a[Mesh.ARRAY_VERTEX][ids[i+k]]
				if v.x < -18 or v.x > -8 or v.y<128 or v.z < -21.3 or v.z > -14.7:keep=false
			if not keep:continue
			for k in 3:
				var index:=ids[i+k];st.set_normal(a[Mesh.ARRAY_NORMAL][index]);st.set_uv(a[Mesh.ARRAY_TEX_UV][index]);st.add_vertex(a[Mesh.ARRAY_VERTEX][index]-Vector3(-13,129,-18));count+=1
		if count>0:st.set_material(source.surface_get_material(s));st.commit(mesh);total+=count/3
	assert(total==48,"Extract the complete hospital unit without other roof equipment")
	save(mesh,PROP+"rooftop_hvac.res")
	var body:=StaticBody3D.new();body.name="RooftopHVAC";body.set_meta("source","hospital / Roof equipment / unit at (-13, 129, -18)")
	var visual:=MeshInstance3D.new();visual.name="MeshInstance3D";visual.mesh=mesh;visual.visibility_range_end=100;body.add_child(visual);visual.owner=body
	var bounds:=mesh.get_aabb();shape(body,"CollisionShape3D",bounds.size,bounds.get_center())
	var packed:=PackedScene.new();assert(packed.pack(body)==OK);save(packed,PROP+"rooftop_hvac.tscn")
	body.free();hospital.free()

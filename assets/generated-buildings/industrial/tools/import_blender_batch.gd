extends "res://assets/generated-buildings/commercial/tools/import_blender_batch.gd"
const INDUSTRIAL := "res://assets/generated-buildings/industrial/"
const BATCH := "res://artifacts/industrial_batch/"
func save(resource: Resource, path: String) -> void:
	var destination:=path
	if path.begins_with(INDUSTRIAL) and ("/meshes/" in path or path.ends_with(".tscn")):
		destination=BATCH+"staged/"+path.get_file()
		DirAccess.make_dir_recursive_absolute(BATCH+"staged")
	assert(ResourceSaver.save(resource,destination)==OK)
	resource.take_over_path(path)
func make_smoke() -> void:
	var particles:=GPUParticles3D.new(); particles.name="StackSmoke"
	particles.set_script(load("res://assets/effects/stack_smoke/stack_smoke.gd"))
	particles.amount=18; particles.lifetime=8; particles.preprocess=4
	particles.fixed_fps=15; particles.emitting=false; particles.local_coords=false
	particles.visibility_aabb=AABB(Vector3(-12,-2,-12),Vector3(24,30,24))
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=ParticleProcessMaterial.new()
	process.direction=Vector3.UP; process.spread=15
	process.initial_velocity_min=.9; process.initial_velocity_max=1.5
	process.gravity=Vector3(.18,.12,.06)
	process.scale_min=.6; process.scale_max=1.1
	var scale_curve:=Curve.new(); scale_curve.add_point(Vector2(0,.3)); scale_curve.add_point(Vector2(1,1))
	var scale_texture:=CurveTexture.new(); scale_texture.curve=scale_curve; process.scale_curve=scale_texture
	var fade:=Gradient.new(); fade.offsets=PackedFloat32Array([0,.15,.55,1])
	fade.colors=PackedColorArray([Color(.45,.46,.47,0),Color(.45,.46,.47,.26),Color(.5,.51,.52,.2),Color(.52,.53,.54,0)])
	var fade_texture:=GradientTexture1D.new(); fade_texture.gradient=fade; process.color_ramp=fade_texture
	particles.process_material=process
	var radial:=Gradient.new(); radial.offsets=PackedFloat32Array([0,.35,1])
	radial.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,0)])
	var texture:=GradientTexture2D.new(); texture.gradient=radial; texture.width=32; texture.height=32
	texture.fill=GradientTexture2D.FILL_RADIAL; texture.fill_from=Vector2(.5,.5); texture.fill_to=Vector2(1,.5)
	var material:=StandardMaterial3D.new(); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true; material.albedo_texture=texture
	material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var quad:=QuadMesh.new(); quad.size=Vector2(3,3); quad.material=material
	particles.draw_pass_1=quad
	var packed:=PackedScene.new(); assert(packed.pack(particles)==OK)
	save(packed,"res://assets/effects/stack_smoke/stack_smoke.tscn"); particles.free()
func run() -> void:
	make_smoke()
	var albedo:=Image.load_from_file(INDUSTRIAL+"textures/foundry_windows.png"); albedo.generate_mipmaps()
	var albedo_texture:=ImageTexture.create_from_image(albedo); save(albedo_texture,INDUSTRIAL+"textures/foundry_windows.res")
	var foundry: StandardMaterial3D=load(INDUSTRIAL+"materials/brick_wall.tres").duplicate()
	foundry.albedo_texture=albedo_texture; save(foundry,INDUSTRIAL+"materials/foundry_windows.tres")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BATCH+"edited_meshes.json"))
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string(INDUSTRIAL+"manifest.json"))
	var audit:=[]
	for slug: String in data.buildings:
		var entry: Dictionary=data.buildings[slug]
		var mesh:=make_mesh(entry.surfaces)
		for surface in mesh.get_surface_count():
			var material:=mesh.surface_get_material(surface) as StandardMaterial3D
			var style:=material.resource_path.get_file().get_basename()
			if style in ["solid","signs_and_doors","brick_wall"]: continue
			var image:=Image.load_from_file(INDUSTRIAL+"textures/"+slug+"_"+style+"_emission.png"); image.generate_mipmaps()
			var texture:=ImageTexture.create_from_image(image)
			save(texture,INDUSTRIAL+"textures/"+slug+"_"+style+"_emission.res")
			material=material.duplicate(); material.emission_enabled=true; material.emission=Color.WHITE
			material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY; material.emission_energy_multiplier=0
			material.emission_texture=texture
			save(material,INDUSTRIAL+"materials/"+slug+"_"+style+".tres")
			mesh.surface_set_material(surface,material)
		var body: StaticBody3D=load(INDUSTRIAL+slug+".tscn").instantiate()
		body.set_script(load(INDUSTRIAL+"industrial_building.gd")); body.get_node("MeshInstance3D").mesh=mesh
		for old in body.get_children():
			if old.name not in [&"MeshInstance3D",&"CollisionShape3D"]: old.free()
		for i in entry.colliders.size():
			var c: Dictionary=entry.colliders[i]
			var node: CollisionShape3D=body.get_node("CollisionShape3D") if i==0 else CollisionShape3D.new()
			if i>0: node.name="SolidCollision%d"%i; body.add_child(node); node.owner=body
			node.transform=Transform3D.IDENTITY
			if c.type=="box":
				node.shape=BoxShape3D.new(); node.shape.size=Vector3(c.size[0],c.size[1],c.size[2])
				node.position=Vector3(c.center[0],c.center[1],c.center[2])
			else:
				var points:=PackedVector3Array()
				for p in c.points: points.append(Vector3(p[0],p[1],p[2]))
				node.shape=ConvexPolygonShape3D.new(); node.shape.points=points
		for p in entry.smoke:
			var smoke: GPUParticles3D=load("res://assets/effects/stack_smoke/stack_smoke.tscn").instantiate()
			smoke.position=Vector3(p[0],p[1],p[2]); body.add_child(smoke); smoke.owner=body
		var document:=GLTFDocument.new(); var state:=GLTFState.new()
		assert(document.append_from_file(BATCH+slug+".glb",state)==OK)
		var glb:=document.generate_scene(state); var count:=0
		for node in glb.find_children("*","MeshInstance3D",true,false): count+=node.mesh.get_faces().size()/3
		glb.free(); assert(count==int(entry.triangles) and count<10000)
		save(mesh,INDUSTRIAL+"meshes/"+slug+".res")
		var packed:=PackedScene.new(); assert(packed.pack(body)==OK); save(packed,INDUSTRIAL+slug+".tscn")
		var row: Dictionary=catalog[int(slug.right(2))-1]
		row.name=slug; row.triangles=count; row.collision_solids=entry.colliders.size()
		row.emission=true; row.smoke_emitters=entry.smoke.size(); row.blender_source="blender/industrial_01_10.blend"
		audit.append({"scene":slug,"glb_triangles":count,"godot_triangles":mesh.get_faces().size()/3,"solid_colliders":entry.colliders.size(),"smoke_emitters":entry.smoke.size(),"max_smoke_triangles":36*entry.smoke.size()})
		body.free()
	FileAccess.open(BATCH+"staged/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t"))
	FileAccess.open(BATCH+"audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	print("INDUSTRIAL_IMPORT_PASS: 10 Blender meshes, fitted solid collision, sparse emissions and three smoke models")
	quit()

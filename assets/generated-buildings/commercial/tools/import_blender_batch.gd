extends SceneTree
## Import the evaluated Blender edits into the existing Godot resource paths.
const OUT := "res://assets/generated-buildings/commercial/"
const WORK := "res://artifacts/commercial_batch/"
const PROP := "res://assets/props/rooftop_hvac/"
func _initialize() -> void:
	run.call_deferred()
func make_mesh(rows: Array, slug := "") -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for row in rows:
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array(); var normals := PackedVector3Array()
		var uvs := PackedVector2Array(); var colors := PackedColorArray()
		for v in row.vertices: vertices.append(Vector3(v[0],v[1],v[2]))
		for n in row.normals: normals.append(Vector3(n[0],n[1],n[2]))
		for uv in row.uv: uvs.append(Vector2(uv[0],uv[1]))
		for c in row.colors: colors.append(Color(c[0],c[1],c[2],c[3]))
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material: StandardMaterial3D
		if "::" in row.material:
			var source: Mesh=load(row.material.split("::")[0])
			for surface in source.get_surface_count():
				if source.surface_get_material(surface).resource_path==row.material:
					material=source.surface_get_material(surface)
		else:
			material=load(row.material)
		assert(material!=null,"Missing source material: "+row.material)
		var style: String = row.material.get_file().get_basename()
		if not slug.is_empty() and style not in ["solid","signs_and_doors","lobby"]:
			material = material.duplicate()
			material.emission_enabled=true; material.emission=Color.WHITE
			material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
			material.emission_energy_multiplier=0; material.set_meta("glow_energy",2.0)
			material.emission_texture=load(OUT+"textures/"+slug+"_emission.res")
			save(material,OUT+"materials/"+slug+"_"+style+".tres")
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	return mesh
func save(resource: Resource, path: String) -> void:
	# Stage existing scene/mesh replacements; copy after Godot releases loaded files.
	var destination:=path
	if path.begins_with(OUT) and ("/meshes/" in path or path.ends_with(".tscn")):
		destination=WORK+"staged/"+path.get_file()
		DirAccess.make_dir_recursive_absolute(WORK+"staged")
	assert(ResourceSaver.save(resource,destination)==OK,"Could not save "+destination)
	resource.take_over_path(path)
func add_box(parent: Node3D, name_string: String, size: Vector3, center: Vector3) -> void:
	var node := CollisionShape3D.new(); node.name=name_string
	node.shape=BoxShape3D.new(); node.shape.size=size; node.position=center
	parent.add_child(node); node.owner=parent
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK+"edited_meshes.json"))
	var hvac_mesh:=make_mesh(data.hvac)
	assert(hvac_mesh.get_faces().size()/3==22)
	save(hvac_mesh,PROP+"rooftop_hvac_lowpoly.res")
	var hvac: StaticBody3D=load(PROP+"rooftop_hvac.tscn").instantiate()
	hvac.get_node("MeshInstance3D").mesh=hvac_mesh
	var hvac_collision: CollisionShape3D=hvac.get_node("CollisionShape3D")
	hvac_collision.shape=BoxShape3D.new(); hvac_collision.shape.size=hvac_mesh.get_aabb().size
	hvac_collision.position=hvac_mesh.get_aabb().get_center()
	hvac.set_meta("source","Blender budget variant of the stock hospital HVAC: hidden caps removed, top panels flattened")
	var packed:=PackedScene.new(); assert(packed.pack(hvac)==OK)
	save(packed,PROP+"rooftop_hvac_lowpoly.tscn"); hvac.free()
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest.json"))
	var audit:=[]
	for slug: String in data.buildings:
		var entry: Dictionary=data.buildings[slug]
		# Verify actual Blender GLB export, not just polygon estimates.
		var document:=GLTFDocument.new(); var state:=GLTFState.new()
		assert(document.append_from_file(WORK+slug+".glb",state)==OK)
		var imported:=document.generate_scene(state)
		var exported_count:=0
		for node: MeshInstance3D in imported.find_children("*","MeshInstance3D",true,false):
			exported_count+=node.mesh.get_faces().size()/3
		assert(exported_count==int(entry.triangles) and exported_count<110,slug+" GLB budget mismatch")
		imported.free()
		var mask:=Image.load_from_file(OUT+"textures/"+slug+"_emission.png")
		mask.generate_mipmaps()
		save(ImageTexture.create_from_image(mask),OUT+"textures/"+slug+"_emission.res")
		var mesh:=make_mesh(entry.surfaces,slug)
		var body: StaticBody3D=load(OUT+slug+".tscn").instantiate()
		body.set_script(load(OUT+"commercial_skyscraper_01.gd"))
		body.get_node("MeshInstance3D").mesh=mesh
		# Preserve the original primary collision node and update its bounds.
		var first: Array=entry.tiers[0]
		var collision: CollisionShape3D=body.get_node("CollisionShape3D")
		collision.shape=BoxShape3D.new(); collision.shape.size=Vector3(first[0],first[2],first[1]+.04)
		collision.position=Vector3(0,first[2]/2,0)
		for old in body.get_children():
			if old.name not in [&"MeshInstance3D",&"CollisionShape3D"]: old.free()
		var bottom: float=first[2]
		for j in range(1,entry.tiers.size()):
			var t: Array=entry.tiers[j]
			var center:=Vector3(t[4] if t.size()>4 else 0,(bottom+t[2])/2,t[5] if t.size()>4 else 0)
			add_box(body,"TierCollision%d"%j,Vector3(t[0],t[2]-bottom,t[1]),center)
			bottom=t[2]
		var unit: StaticBody3D=load(PROP+("rooftop_hvac_lowpoly.tscn" if entry.lowpoly_hvac else "rooftop_hvac.tscn")).instantiate()
		unit.name="RooftopHVAC"; var pos: Array=entry.hvac_position
		unit.position=Vector3(pos[0],pos[1],pos[2]); body.add_child(unit); unit.owner=body
		var equipment: Mesh=unit.get_node("MeshInstance3D").mesh
		var actual_count:=mesh.get_faces().size()/3+equipment.get_faces().size()/3
		assert(actual_count==exported_count and actual_count<110)
		save(mesh,OUT+"meshes/"+slug+".res")
		packed=PackedScene.new(); assert(packed.pack(body)==OK); save(packed,OUT+slug+".tscn")
		var catalog_entry: Dictionary=catalog[int(slug.right(2))-1]
		catalog_entry.name=slug; catalog_entry.triangles=actual_count
		catalog_entry.building_triangles=mesh.get_faces().size()/3
		catalog_entry.hvac_triangles=equipment.get_faces().size()/3
		catalog_entry.roof_height_m=pos[1]; catalog_entry.height_m=pos[1]+equipment.get_aabb().end.y
		catalog_entry.night_illumination=true; catalog_entry.blender_source="blender/commercial_03_20.blend"
		catalog_entry.surfaces=mesh.get_surface_count()+equipment.get_surface_count()
		audit.append({"scene":slug,"triangles":actual_count,"blender_glb_triangles":exported_count,"building":catalog_entry.building_triangles,"hvac":catalog_entry.hvac_triangles})
		body.free()
	FileAccess.open(WORK+"staged/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t"))
	FileAccess.open(WORK+"triangle_audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	print("BLENDER_IMPORT_PASS: 18 buildings; actual GLB and Godot triangle counts match; all under 110")
	quit()

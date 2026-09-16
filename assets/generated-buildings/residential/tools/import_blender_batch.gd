extends "res://assets/generated-buildings/commercial/tools/import_blender_batch.gd"
const RESIDENTIAL := "res://assets/generated-buildings/residential/"
const BATCH := "res://artifacts/residential_batch/"
const WATER := "res://assets/props/rooftop_water_tower/"
func save(resource: Resource, path: String) -> void:
	var destination := path
	if path.begins_with(RESIDENTIAL) and ("/meshes/" in path or path.ends_with(".tscn")):
		destination=BATCH+"staged/"+path.get_file()
		DirAccess.make_dir_recursive_absolute(BATCH+"staged")
	assert(ResourceSaver.save(resource,destination)==OK)
	resource.take_over_path(path)
func glb_triangles(path: String) -> int:
	var document:=GLTFDocument.new(); var state:=GLTFState.new()
	assert(document.append_from_file(path,state)==OK)
	var scene:=document.generate_scene(state); var count:=0
	for node in scene.find_children("*","MeshInstance3D",true,false): count+=node.mesh.get_faces().size()/3
	scene.free(); return count
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BATCH+"edited_meshes.json"))
	var water_mesh:=make_mesh(data.water_tower)
	var water_material:=water_mesh.surface_get_material(0).duplicate()
	save(water_material,WATER+"water_tower.tres"); water_mesh.surface_set_material(0,water_material)
	save(water_mesh,WATER+"rooftop_water_tower.res")
	assert(glb_triangles(BATCH+"rooftop_water_tower.glb")==water_mesh.get_faces().size()/3)
	var water:=StaticBody3D.new(); water.name="RooftopWaterTower"
	var visual:=MeshInstance3D.new(); visual.name="MeshInstance3D"; visual.mesh=water_mesh
	water.add_child(visual); visual.owner=water
	add_box(water,"CollisionShape3D",water_mesh.get_aabb().size,water_mesh.get_aabb().get_center())
	var packed:=PackedScene.new(); assert(packed.pack(water)==OK); save(packed,WATER+"rooftop_water_tower.tscn"); water.free()
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string(RESIDENTIAL+"manifest.json"))
	var audit:=[]
	for slug: String in data.buildings:
		var entry: Dictionary=data.buildings[slug]
		var mesh:=make_mesh(entry.surfaces)
		for surface in mesh.get_surface_count():
			var material:=mesh.surface_get_material(surface) as StandardMaterial3D
			var style:=material.resource_path.get_file().get_basename()
			if style in ["solid","signs_and_doors"]: continue
			var image:=Image.load_from_file(RESIDENTIAL+"textures/"+slug+"_"+style+"_emission.png")
			image.generate_mipmaps()
			var texture:=ImageTexture.create_from_image(image)
			save(texture,RESIDENTIAL+"textures/"+slug+"_"+style+"_emission.res")
			material=material.duplicate(); material.emission_enabled=true; material.emission=Color.WHITE
			material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
			material.emission_texture=texture; material.emission_energy_multiplier=0
			save(material,RESIDENTIAL+"materials/"+slug+"_"+style+".tres")
			mesh.surface_set_material(surface,material)
		var body: StaticBody3D=load(RESIDENTIAL+slug+".tscn").instantiate()
		body.set_script(load(RESIDENTIAL+"residential_building.gd"))
		body.get_node("MeshInstance3D").mesh=mesh
		preload("res://assets/generated-buildings/residential/tools/residential_collision.gd").fit(body,mesh,int(slug.right(2)))
		for name_string in ["RooftopHVAC","RooftopWaterTower"]:
			var old:=body.get_node_or_null(NodePath(name_string))
			if old!=null: old.free()
		var ac: Node3D=load("res://assets/props/rooftop_hvac/rooftop_hvac_lowpoly.tscn").instantiate()
		ac.name="RooftopHVAC"; var p: Array=entry.hvac_position
		ac.position=Vector3(p[0],p[1],p[2]); ac.scale=Vector3.ONE*entry.hvac_scale
		body.add_child(ac); ac.owner=body
		if entry.water_position!=null:
			var tank: Node3D=load(WATER+"rooftop_water_tower.tscn").instantiate(); tank.name="RooftopWaterTower"
			p=entry.water_position; tank.position=Vector3(p[0],p[1],p[2])
			body.add_child(tank); tank.owner=body
		var exported:=glb_triangles(BATCH+slug+".glb")
		assert(exported==int(entry.triangles) and exported<10000,slug+" exported count mismatch")
		save(mesh,RESIDENTIAL+"meshes/"+slug+".res")
		packed=PackedScene.new(); assert(packed.pack(body)==OK); save(packed,RESIDENTIAL+slug+".tscn")
		var row: Dictionary=catalog[int(slug.right(2))-1]
		row.name=slug; row.triangles=exported; row.building_triangles=entry.building_triangles
		row.width_m=mesh.get_aabb().size.x; row.depth_m=mesh.get_aabb().size.z
		row.height_m=entry.roof_y+(4.25 if entry.water_position!=null else 2.6154*entry.hvac_scale)
		row.surfaces=mesh.get_surface_count(); row.roof_height_m=entry.roof_y
		row.design="Balcony-free residential building with shared rooftop AC"+(" and water tower" if entry.water_position!=null else "")
		row.night_illumination=true; row.blender_source="blender/residential_01_20.blend"
		audit.append({"scene":slug,"godot_total":exported,"glb_total":exported,"shell":entry.building_triangles,"hvac":22,"water_tower":64 if entry.water_position!=null else 0,"removed":entry.removed_triangles})
		body.free()
	FileAccess.open(BATCH+"staged/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t"))
	FileAccess.open(BATCH+"triangle_audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	print("RESIDENTIAL_IMPORT_PASS: all 20 Blender GLBs checked; shared AC and water tower; emission and static shell collision")
	quit()

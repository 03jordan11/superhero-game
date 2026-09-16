extends SceneTree
const BASE := "res://assets/generated-buildings/residential/"
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)
func run() -> void:
	var library:=root.get_node("CityWindows"); library.set_city_seed(12345)
	var audit: Array=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/residential_batch/triangle_audit.json"))
	var edits: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/residential_batch/edited_meshes.json")).buildings
	var world:=Node3D.new(); root.add_child(world)
	var lit_total:=0; var off_total:=0; var tanks:=0
	var collection: Array[PackedScene]=[]
	for i in range(1,21):
		var slug:="residential_building_%02d"%i
		var scene: PackedScene=load(BASE+slug+".tscn"); collection.append(scene)
		var building: StaticBody3D=scene.instantiate(); building.position.x=i*100
		building.follow_day_night_cycle=false; world.add_child(building); building.apply_night(1)
		var source: Mesh=building._original_mesh
		var mesh: Mesh=building.get_node("MeshInstance3D").mesh
		check(source.get_faces()==mesh.get_faces(),slug+" seeded mesh geometry changed")
		var count:=mesh.get_faces().size()/3
		for prop in ["RooftopHVAC","RooftopWaterTower"]:
			var node:=building.get_node_or_null(NodePath(prop))
			if node==null: continue
			check(node.scene_file_path.begins_with("res://assets/props/"),"Props must be shared instances")
			count+=node.get_node("MeshInstance3D").mesh.get_faces().size()/3
			if prop=="RooftopWaterTower": tanks+=1
		check(count==int(audit[i-1].glb_total) and count<10000,slug+" exported triangle mismatch")
		check(building.has_node("RooftopHVAC"),slug+" AC missing")
		var collision: CollisionShape3D=building.get_node("CollisionShape3D")
		check(collision.shape is BoxShape3D,"Building must use solid box collision")
		for surface in source.get_surface_count():
			var material:=source.surface_get_material(surface) as StandardMaterial3D
			var arrays:=source.surface_get_arrays(surface)
			if material.resource_path.ends_with("signs_and_doors.tres"):
				for uv in arrays[Mesh.ARRAY_TEX_UV]: check(uv.y>.8,"Nameplate remains")
			if i in [10,12,14] and material.resource_path.ends_with("solid.tres"):
				for vertex in arrays[Mesh.ARRAY_VERTEX]:
					check(not (vertex.y>3.5 and vertex.z<float(edits[slug].front)-.2),"Balcony geometry remains")
			if not material.emission_enabled: continue
			var original:=material.emission_texture.get_image()
			for variant in 6:
				var image: Image=library.texture_for(source,surface,variant).get_image()
				var lit:=0; var off:=0
				for y in image.get_height()/16:
					for x in image.get_width()/16:
						if original.get_pixel((x*16+5)%64,(y*16+5)%64).r<=.1: continue
						lit+=1
						if image.get_pixel(x*16+5,y*16+5).r<.1: off+=1
				lit_total+=lit; off_total+=off
				# Small roof faces have integer-window rounding; large facades should reach target.
				check(absf(off-roundi(lit*library.reduction_for(variant,true)))<=2,"Residential occupancy target missed: "+slug+" v"+str(variant)+" "+str(off)+"/"+str(lit))
				for y in image.get_height():
					for x in image.get_width():
						var a:=original.get_pixel(x%64,y%64); var b:=image.get_pixel(x,y)
						if b.r>a.r+.001 or b.g>a.g+.001 or b.b>a.b+.001: check(false,"Emission spilled outside original windows"); break
		for mat in building._night_materials: check(mat.emission_energy_multiplier==2 and mat.emission_on_uv2,"Night emission missing")
		building.apply_night(0)
		for mat in building._night_materials: check(mat.emission_energy_multiplier==0,"Daytime windows lit")
	check(tanks==3,"Expected three water-tower models")
	var sample: Node=world.get_child(17)
	var stable: PackedByteArray=sample._night_materials[0].emission_texture.get_image().get_data()
	library.set_city_seed(54321)
	check(stable!=sample._night_materials[0].emission_texture.get_image().get_data(),"Residential seeds should differ")
	library.restore_data({"seed":12345})
	check(stable==sample._night_materials[0].emission_texture.get_image().get_data(),"Residential load must restore exact patterns")
	await physics_frame; await physics_frame
	# Roof/AC collisions and the space where the balcony used to be.
	for building in world.get_children():
		var ac: Node3D=building.get_node("RooftopHVAC")
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ac.global_position+Vector3.UP*6,ac.global_position-Vector3.UP))
		check(not hit.is_empty() and hit.collider==ac,"Shared AC collision must be solid")
		var i:=int(building.name.right(2))
		if i in [10,12,14]:
			var slug:="residential_building_%02d"%i
			var at: Vector3=building.global_position+Vector3(-7,6.4,float(edits[slug].front)-.6)
			var clear:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP))
			check(clear.is_empty(),"Invisible balcony collider remains")
	var city: Node=load("res://scenes/super_city.tscn").instantiate(); var placements:=0
	for node in city.find_children("*","StaticBody3D",true,false):
		if node.scene_file_path.begins_with(BASE): placements+=1
	check(placements>0,"Residential scenes must be used in the actual city")
	city.free(); world.free()
	print("RESIDENTIAL_PASS: models=20 placements=",placements," water-models=",tanks," off fraction=",float(off_total)/lit_total," failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
const OUT := "res://assets/generated-buildings/commercial/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var clock: Node=load("res://scripts/day_night_cycle.gd").new()
	clock.cycle_running=false
	var env:=WorldEnvironment.new(); env.name="Daylight"; world.add_child(env)
	for label in ["Sun","Moon"]:
		var light:=DirectionalLight3D.new(); light.name=label; world.add_child(light)
	world.add_child(clock)
	var buildings:=[]
	var counts: Dictionary={}
	for i in range(3,21):
		var slug:="commercial_skyscraper_%02d"%i
		var building: StaticBody3D=load(OUT+slug+".tscn").instantiate()
		building.position.x=(i-3)*100; world.add_child(building); buildings.append(building)
		var mesh: Mesh=building.get_node("MeshInstance3D").mesh
		var hvac: Mesh=building.get_node("RooftopHVAC/MeshInstance3D").mesh
		var total:=mesh.get_faces().size()/3+hvac.get_faces().size()/3
		assert(total<110,slug+" exceeds complete budget")
		counts[slug]=total
		var doors:=0
		for s in mesh.get_surface_count():
			var material: StandardMaterial3D=mesh.surface_get_material(s)
			assert(material!=null)
			if material.resource_path.ends_with("signs_and_doors.tres"):
				var a:=mesh.surface_get_arrays(s)
				for v: Vector3 in a[Mesh.ARRAY_VERTEX]: assert(v.y<3.6,"Nameplate geometry remains")
				doors+=a[Mesh.ARRAY_VERTEX].size()/3
		assert(doors==4,"Both original doors remain")
		var image:=Image.load_from_file(OUT+"textures/"+slug+"_emission.png")
		assert(image!=null and image.get_size()==Vector2i(64,64))
		var lit:=0
		for y in 64:
			for x in 64:
				if image.get_pixel(x,y).r>.1:
					lit+=1
					assert(x%16>=3 and x%16<12 and x%16!=8 and y%16>=2 and y%16<=11)
		assert(lit>0 and lit<1280)
	await process_frame
	await process_frame
	clock.set_time(0)
	for building in buildings:
		assert(not building._night_materials.is_empty())
		for material in building._night_materials:
			assert(is_equal_approx(material.emission_energy_multiplier,2.0))
			assert(material.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY)
	clock.set_time(12)
	for building in buildings:
		for material in building._night_materials: assert(is_zero_approx(material.emission_energy_multiplier))
	await physics_frame
	await physics_frame
	for building in buildings:
		var hvac: Node3D=building.get_node("RooftopHVAC")
		var mesh: Mesh=hvac.get_node("MeshInstance3D").mesh
		var top:=hvac.global_position+mesh.get_aabb().get_center()
		top.y=hvac.global_position.y+mesh.get_aabb().end.y
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top+Vector3.UP*5,top-Vector3.UP*5))
		assert(not hit.is_empty() and is_equal_approx(hit.position.y,top.y))
	var city: Node=load("res://scenes/super_city.tscn").instantiate()
	var placements:=0
	for node in city.find_children("*","StaticBody3D",true,false):
		var slug: String=node.scene_file_path.get_file().get_basename()
		if not counts.has(slug): continue
		placements+=1
		assert(node.has_node("RooftopHVAC") and node.has_node("TierCollision1"))
		assert(node.get_node("CollisionShape3D").shape.size.y<node.get_node("RooftopHVAC").position.y)
	assert(placements==308)
	city.free(); world.free()
	print("COMMERCIAL_BATCH_PASS: 18 assets, 308 city instances, <110 triangles each, no plaques, doors retained, masks/clock and rooftop collision verified.")
	quit()

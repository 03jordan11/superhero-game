extends SceneTree
const BASE := "res://assets/generated-buildings/industrial/"
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)
func run() -> void:
	var windows:=root.get_node("CityWindows"); windows.set_city_seed(12345)
	var world:=Node3D.new(); root.add_child(world)
	var audit: Array=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/industrial_batch/audit.json"))
	var emitter_count:=0; var shape_count:=0
	for i in range(1,11):
		var body: StaticBody3D=load(BASE+"industrial_building_%02d.tscn"%i).instantiate()
		body.position.x=i*100; body.follow_day_night_cycle=false; world.add_child(body)
		body.apply_night(1)
		var mesh: Mesh=body._original_mesh
		check(mesh.get_faces().size()/3==int(audit[i-1].glb_triangles),"GLB/Godot geometry mismatch")
		check(body.get_node("CollisionShape3D").shape is BoxShape3D,"Primary wall volume must be a solid box")
		for node in body.get_children():
			if node is CollisionShape3D:
				shape_count+=1
				check(node.shape is BoxShape3D or node.shape is ConvexPolygonShape3D,"Hollow collision must never return")
			if node is GPUParticles3D:
				emitter_count+=1
				check(i in [3,7,9] and node.amount==18,"Smoke must be limited to selected stacks")
		check(not body._night_materials.is_empty(),"Every industrial asset needs real window emission")
		for surface in mesh.get_surface_count():
			var material:=mesh.surface_get_material(surface) as StandardMaterial3D
			if material.resource_path.ends_with("signs_and_doors.tres"):
				for uv in mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]: check(uv.y>.8,"Nameplate remains")
			if not material.emission_enabled: continue
			# Full mask/percentage coverage lives in test_seeded_city_windows.gd.

		for mat in body._night_materials: check(mat.get_shader_parameter("emission_energy")==2,"Night intensity wrong")
		body.apply_night(0)
		for mat in body._night_materials: check(mat.get_shader_parameter("emission_energy")==0,"Day windows stayed lit")
	check(emitter_count==3,"Expected three smokestack models")
	var sample: Node=world.get_child(5)
	var first: PackedByteArray=sample._night_materials[0].get_shader_parameter("room_data").get_image().get_data()
	windows.set_city_seed(54321); check(first!=sample._night_materials[0].get_shader_parameter("room_data").get_image().get_data(),"New seeds must differ")
	windows.restore_data({"seed":12345}); check(first==sample._night_materials[0].get_shader_parameter("room_data").get_image().get_data(),"Reload must restore windows")
	var runner:=CharacterBody3D.new(); runner.collision_layer=2; runner.collision_mask=1
	var capsule:=CollisionShape3D.new(); capsule.shape=CapsuleShape3D.new(); runner.add_child(capsule); world.add_child(runner)
	await physics_frame; await physics_frame
	var query:=PhysicsShapeQueryParameters3D.new(); query.shape=SphereShape3D.new(); query.shape.radius=.05; query.collision_mask=1
	for body in world.get_children():
		if body==runner: continue
		# Every exported visual vertex must meet a solid, within thin trim tolerance.
		query.shape.radius=.25
		for vertex in body._original_mesh.get_faces():
			query.transform.origin=body.global_position+vertex
			check(not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Visible geometry lies outside fitted collision: "+str(body.name))
		query.shape.radius=.05
		for node in body.get_children():
			if not node is CollisionShape3D: continue
			var center:=Vector3.ZERO
			if node.shape is BoxShape3D: center=node.global_position
			else:
				for p in node.shape.points: center+=p
				center=body.global_position+center/node.shape.points.size()
			query.transform.origin=center
			check(not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Solid interior overlap failed")
		var wall: CollisionShape3D=body.get_node("CollisionShape3D")
		var front: Vector3=wall.global_position-Vector3(0,0,wall.shape.size.z/2)
		runner.position=front+Vector3(0,0,-.501)
		for step in 12:
			runner.velocity=Vector3(0,12,1); runner.move_and_slide()
			check(runner.position.z<=front.z-.45,"Wall-run probe entered industrial wall")
		var roof: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body.global_position+Vector3(0,45,0),body.global_position+Vector3(0,1,0)))
		check(not roof.is_empty(),"Roof landing ray missed")
	world.free()
	# Smoke is capped and releases its slots when out of range or freed.
	world=Node3D.new(); root.add_child(world)
	var camera:=Camera3D.new(); world.add_child(camera); camera.make_current()
	for i in 20:
		var smoke: GPUParticles3D=load("res://assets/effects/stack_smoke/stack_smoke.tscn").instantiate(); world.add_child(smoke); smoke.update_emission()
	var active:=0
	for node in world.get_children():
		if node is GPUParticles3D and node.emitting: active+=1
	check(active==12,"Smoke emitter cap failed")
	camera.position.x=2000
	for node in world.get_children():
		if node is GPUParticles3D: node.update_emission(); check(not node.emitting,"Far smoke must stop")
	world.free()
	var city: Node=load("res://scenes/super_city.tscn").instantiate(); var placements:=0
	for node in city.find_children("*","StaticBody3D",true,false):
		if node.scene_file_path.begins_with(BASE): placements+=1
	city.free()
	print("INDUSTRIAL_PASS: 10 assets, ",placements," placements, ",shape_count," solids, 3 smoke models, failures=",failures)
	quit(1 if failures else 0)

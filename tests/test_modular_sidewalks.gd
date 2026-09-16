extends SceneTree
const KIT := "res://assets/super-city/modular-sidewalks/"
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("SaveManager")._save_path=OS.get_environment("TEMP").path_join("sidewalk_test_%d.json"%OS.get_process_id())
	var scene: Node3D=load("res://scenes/previews/modular_sidewalk_test.tscn").instantiate()
	root.add_child(scene); current_scene=scene
	await process_frame
	check(scene.get_script()!=null,"Preview controller loads without parse errors")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(KIT+"manifest.json"))
	check(manifest.modules.size()==8,"Exactly eight requested kit variants")
	var shared_material: Material=null
	var triangle_total:=0
	for definition: Dictionary in manifest.modules:
		var piece: Node3D=load(KIT+definition.id+".tscn").instantiate()
		var mesh: MeshInstance3D=piece.get_node("Mesh")
		check(mesh.mesh.get_surface_count()==1,"One material surface: "+definition.id)
		var triangles:=int(mesh.mesh.surface_get_array_len(0)/3)
		check(triangles==int(definition.triangles),"Actual exported triangle count: "+definition.id)
		check(is_equal_approx(mesh.get_aabb().end.y,0.03),"City-compatible flush height: "+definition.id)
		if shared_material==null: shared_material=mesh.mesh.surface_get_material(0)
		check(mesh.mesh.surface_get_material(0)==shared_material,"Modules share one material")
		check(piece.get_node("Sockets").get_child_count()==int(definition.sockets),"Expected socket count")
		check(piece.find_children("*","CollisionShape3D",true,false).size()==int(definition.collision_shapes),"Collision belongs to each piece")
		piece.free()
	var pieces: Array[Node]=scene.get_node("AssembledExample").get_children()
	var sockets: Array[Node3D]=[]
	for piece: Node3D in pieces:
		check(not piece.scene_file_path.is_empty() and piece.owner==scene,"Placed modules remain individually editable scene instances")
		triangle_total+=int(piece.get_node("Mesh").mesh.surface_get_array_len(0)/3)
		for socket: Node3D in piece.get_node("Sockets").get_children(): sockets.append(socket)
	check(triangle_total<10000,"Complete assembled example below POI geometry limit")
	for socket in sockets:
		var matches:=0
		for other in sockets:
			if other==socket:continue
			if socket.global_position.distance_to(other.global_position)<0.001:
				matches+=1
				check(socket.global_basis.z.dot(other.global_basis.z)<-0.999,"Mated sockets face opposite directions")
		check(matches==1,"Every example socket joins exactly one matching socket: "+String(socket.get_parent().get_parent().name)+"/"+String(socket.name))
	await physics_frame; await physics_frame
	var space:=scene.get_world_3d().direct_space_state
	for socket in sockets:
		for distance in [-0.08,0.0,0.08]:
			var at: Vector3=socket.global_position+socket.global_basis.z*distance
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP,1))
			check(not hit.is_empty() and absf(hit.position.y-0.03)<0.001,"No collision gap or height step at joined ends: %s %s hit=%s"%[socket.get_parent().get_parent().name,at,hit.get("position",Vector3.INF)])
	# Missing corners must remain empty rather than using one bounding-box collider.
	var corner: Node3D=scene.get_node("LoosePieces/CornerL")
	var empty_point:=corner.to_global(Vector3(4,2,-4))
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(empty_point,empty_point-Vector3.UP*3,1))
	check(not hit.is_empty() and hit.collider==scene.get_node("TestGround"),"L corner has no invisible collision in its cutout")
	# Mesh and collision move together when a scene instance is rearranged.
	var loose: Node3D=scene.get_node("LoosePieces/Straight4m")
	var old_position:=loose.global_position
	loose.position+=Vector3(0,0,8)
	await physics_frame; await physics_frame
	hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(old_position+Vector3.UP*2,old_position-Vector3.UP,1))
	check(not hit.is_empty() and hit.collider==scene.get_node("TestGround"),"Moving a piece removes its old collision")
	hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(loose.global_position+Vector3.UP*2,loose.global_position-Vector3.UP,1))
	check(not hit.is_empty() and hit.collider==loose,"Collision follows moved instance")
	loose.global_position=old_position
	# Walk the actual hero across corner -> straight -> cross at normal speed.
	scene._set_walk_mode(true)
	var player: PlayerCharacter=scene.get_node("Player")
	player.position=Vector3(28,1.25,6); player.rotation=Vector3.ZERO; player.spring_arm.rotation=Vector3.ZERO
	player.ground_facing_yaw=0; player.velocity=Vector3.ZERO
	for tick in 45: await physics_frame
	var settled_y:=player.position.y
	Input.action_press("move_forward")
	for tick in 180: await physics_frame
	Input.action_release("move_forward")
	check(player.position.z<-15,"Actual player traverses several modules without getting stuck")
	check(absf(player.position.y-settled_y)<0.15 and player.is_on_floor(),"Seam traversal stays grounded")
	scene._set_walk_mode(false)
	if "--render" in OS.get_cmdline_user_args():
		for tick in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/modular_sidewalk_overview.png")
		scene._set_walk_mode(true)
		player.global_transform=scene.get_node("PlayerStart").global_transform
		player.velocity=Vector3.ZERO
		player.spring_arm.rotation_degrees=Vector3(-18,-45,0)
		for tick in 90: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/modular_sidewalk_walk.png")
	print("MODULAR_SIDEWALKS_PASS failures=",failures," assembled_triangles=",triangle_total," matched_socket_ends=",sockets.size())
	scene.free(); quit(1 if failures else 0)

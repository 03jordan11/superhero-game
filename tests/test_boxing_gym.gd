extends SceneTree
const BASE := "res://assets/interiors/boxing_gym/"
var failures: Array[String] = []
var gym: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return gym.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b))

func walk(start: Vector3, direction: Vector3, ticks: int, expected: Vector3, label: String) -> void:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .4
	capsule.height = 2
	shape.shape = capsule
	body.add_child(shape)
	root.add_child(body)
	body.position = start
	body.floor_snap_length = .35
	body.floor_constant_speed = true
	for i in ticks:
		await physics_frame
		var vertical := 0.0 if body.is_on_floor() else body.velocity.y - 24.0/60.0
		body.velocity = direction * 2 + Vector3.UP * vertical
		body.move_and_slide()
	check(body.position.distance_to(expected) < .3, label + " capsule route: " + str(body.position))
	body.free()

func run() -> void:
	gym = load(BASE + "boxing_gym.tscn").instantiate() as Node3D
	root.add_child(gym)
	current_scene = gym
	await physics_frame
	await physics_frame
	var total := 0
	var player := gym.get_node("Player") as PlayerCharacter
	for mi: MeshInstance3D in gym.find_children("*", "MeshInstance3D", true, false):
		if player.is_ancestor_of(mi): continue
		total += mi.mesh.get_faces().size()/3
	check(total > 0 and total <= 50000, "Actual complete scene triangle budget")
	check(total == int(gym.get_meta("rendered_triangles")), "Triangle audit matches imported scene")
	var count := 0
	for group: String in ["Architecture","Training","Props","Lighting"]:
		for prop: Node3D in gym.get_node(group).get_children():
			if prop.name == &"RingAccess": continue
			count += 1
			check(prop.scene_file_path.begins_with(BASE+"props/"), "Editable independent prop scene: " + prop.name)
	check(count == 62, "Original placements plus five new placements and two reused shelves")
	var training := gym.get_node("Training")
	check(training.has_node("HeavyBag1") and training.has_node("HeavyBag2") and training.has_node("SpeedBag"), "Required bag inventory")
	check(training.has_node("WeightRack"), "Weight rack present")
	for pos: Vector2 in [Vector2(0,8), Vector2(-6,3), Vector2(6,3),Vector2(0,-5)]:
		var hit := ray(Vector3(pos.x,1,pos.y),Vector3(pos.x,-.3,pos.y))
		check(not hit.is_empty() and absf(hit.position.y)<.02, "Gym floor solid")
	for x in [-2.8,0,2.8]:
		for z in [-1.8,1,3.8]:
			var hit := ray(Vector3(x,1.2,z),Vector3(x,.8,z))
			check(not hit.is_empty() and absf(hit.position.y-1)<.015, "Ring canvas level at one metre")
	for pos: Vector2 in [Vector2(-10,-9),Vector2(0,-9),Vector2(9,-6.5)]:
		var hit := ray(Vector3(pos.x,3.8,pos.y),Vector3(pos.x,3.2,pos.y))
		check(not hit.is_empty() and absf(hit.position.y-3.6)<.02, "Catwalk and office floors")
	for x in [-2.2,0,2.2]:
		check(not ray(Vector3(x,2.1,5),Vector3(x,2.1,1)).is_empty(), "Front ropes closed across full width")
	check(not ray(Vector3(.4,1,10.5),Vector3(.4,1,11.7)).is_empty(), "Exterior door is closed and solid")
	check(not ray(Vector3(9,1.2,-5),Vector3(9,1.2,-9)).is_empty(), "Bathroom exterior is closed")
	check(not ray(Vector3(-8.65,1,-10),Vector3(-8.65,1,-11.1)).is_empty(), "Future rear exit is closed")
	for key: String in ["FrontWindowLeft","FrontWindowRight","BackDoor","RearExitSign","StorageShelvesLeft","StorageShelvesRight"]:
		check(gym.has_node("Props/"+key), "Required addition: " + key)
	check(gym.get_node("Props/StorageShelvesLeft/Mesh").mesh.resource_path.contains("gas_station_hideout"), "Shelves reuse actual hideout mesh")
	# Moving a prop must move its collision, without an orphaned obstacle.
	var rack := training.get_node("WeightRack") as Node3D
	var before := ray(Vector3(10.5,2,.2),Vector3(10.5,.2,.2))
	check(not before.is_empty(), "Rack collision exists")
	rack.position.z += 3
	await physics_frame
	await physics_frame
	check(ray(Vector3(10.5,2,.2),Vector3(10.5,.2,.2)).is_empty(), "Prop collision follows editable placement")
	rack.position.z -= 3
	await walk(Vector3(-10.1,1.02,-.5),Vector3.FORWARD,270,Vector3(-10.1,4.61,-8.5),"Catwalk stairs")
	print("BOXING_GYM_TEST triangles=",total," placements=",count," failures=",failures.size())
	for i in 30: await physics_frame
	check(player.is_on_floor(), "Existing game player starts grounded")
	check(player.global_position.distance_to(gym.get_node("PlayerSpawn").global_position)<.1, "Direct scene starts at entrance marker")
	check(is_equal_approx(player.spring_arm.spring_length,1.5), "Hideout shoulder distance")
	check(player.spring_arm.position.is_equal_approx(Vector3(.6,.75,0)), "Hideout shoulder offset")
	check(is_equal_approx(player.spring_arm.rotation.x,deg_to_rad(-8)), "Hideout shoulder pitch")
	var access := gym.get_node("Training/RingAccess")
	check(not access.try_interact(player), "Distant E does not teleport")
	player.global_position = gym.get_node("Training/RingSteps").to_global(Vector3(0,1.05,2.0))
	player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	Input.action_press("move_forward")
	for i in 85: await physics_frame
	Input.action_release("move_forward")
	for i in 5: await physics_frame
	check(not access.is_inside(player), "Walking cannot pass through the closed ropes")
	check(access.can_interact(player), "Stairway interaction reachable")
	Input.action_press("pick_up_vehicle")
	for i in 4: await physics_frame
	check(access.is_inside(player), "E enters ring through actual player input path")
	check(player.global_position.distance_to(access.ring.to_global(access.corner_position))<.15, "Teleport lands at the near corner")
	for i in 15: await physics_frame
	check(access.is_inside(player), "Held E does not immediately leave again")
	Input.action_release("pick_up_vehicle")
	for i in 3: await physics_frame
	check(access.try_interact(player) and access.is_inside(player), "Cooldown consumes E without double teleport")
	access._cooldown_until = 0
	Input.action_press("pick_up_vehicle")
	for i in 4: await physics_frame
	Input.action_release("pick_up_vehicle")
	check(not access.is_inside(player), "E returns to the stairway floor")
	check(player.global_position.distance_to(access.stairs.to_global(access.stair_return_position))<.15, "Exit destination is safe")
	player.position = Vector3(-10.1,1.05,-.4)
	player.rotation = Vector3.ZERO
	player.ground_facing_yaw = 0
	player.spring_arm.rotation.y = 0
	player.velocity = Vector3.ZERO
	for i in 10: await physics_frame
	Input.action_press("move_forward")
	for i in 240: await physics_frame
	Input.action_release("move_forward")
	check(player.position.y > 4.5 and player.position.z < -7.5, "Existing player reaches catwalk: " + str(player.position))
	print("BOXING_GYM_PLAYER_TEST failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

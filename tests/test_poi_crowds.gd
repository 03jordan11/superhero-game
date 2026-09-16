extends SceneTree
## Exercise actual full civilians near the new blocks, including relocation.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(65).timeout.connect(func():push_error("POI crowd test timed out");quit(1))
	seed(9613)
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	city.get_node("TrafficManager").free()
	city.get_node("PreviewCamera").free() # Its standalone mode deliberately follows the camera.
	var focus:=Node3D.new()
	focus.name="POICrowdFocus"
	city.add_child(focus)
	var crowd=city.get_node("CivilianCrowd")
	crowd.player_path=^"../POICrowdFocus"
	crowd.get_node("CapsuleLOD").enabled=false
	crowd.population_target=6
	crowd.max_civilians=6
	crowd.ground_radius=65
	crowd.nearby_circle_radius=65
	crowd.minimum_player_distance=3
	crowd.despawn_margin=5
	crowd.despawn_delay=.1
	crowd.prefer_offscreen_spawns=false
	root.add_child(city)
	current_scene=city
	for site in [["Civic plaza",Vector3(-402,0.03,-340)],["Hospital",Vector3(-340,.03,344)],["Bank1",Vector3(-139,.03,494)],["Bank2",Vector3(109,.03,624)],["Firehouse",Vector3(-616,.03,494)]]:
		focus.position=site[1]
		for frame in 150:await physics_frame
		print("POI_SPAWN: ",site[0]," active=",crowd.active_count," target=",crowd.current_target," capacity=",crowd.density_capacity," status=",crowd.status)
		if crowd.active_count<2 or crowd.active_count>6:
			push_error("POI crowd failed to spawn within cap: "+site[0]);city.free();quit(1);return
		var starts: Dictionary={}
		for walker in crowd.get_node("ActiveCivilians").get_children():starts[walker]=walker.global_position
		for frame in 120:await physics_frame
		var moving:=0
		for walker in starts:
			if is_instance_valid(walker) and walker.global_position.distance_to(starts[walker])>.5:moving+=1
		if moving<2:push_error("POI crowds failed to move: "+site[0]);city.free();quit(1);return
		print("POI_CROWD: ",site[0],"; active=",crowd.active_count,"; moving=",moving)
	city.free()
	print("PASS: POI crowd spawning, cap, walking and relocation across five landmark neighborhoods.")
	quit()

extends SceneTree
const BASE := "res://assets/buildings/gas_station_hideout/"
var failures := 0
func _initialize() -> void:
	create_timer(80).timeout.connect(func(): push_error("Hideout test timed out"); quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run() -> void:
	var city := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(city); current_scene = city
	var player: PlayerCharacter = city.get_node("Player")
	var identity := player.get_instance_id()
	var money := player.stats.money
	var spring := player.spring_arm.spring_length
	var outdoor_pivot: Vector3 = player.camera_effects.base_spring_arm_position
	for cycle in 2:
		var station: Node3D = city.get_node("SuperCity/Sidewalks/GasStationHideout")
		var door: Node3D = station.get_node("HideoutEntrance")
		player.global_position = door.to_global(Vector3(0, 0.3, 1.1))
		await physics_frame; await physics_frame
		check(city.find_children("GasStationInterior", "", true, false).is_empty(), "No interior nested in the city")
		check(door.can_interact(player), "Can enter placed exterior")
		player.is_dead = true; check(not door.can_interact(player), "Dead player cannot enter"); player.is_dead = false
		player.global_position = door.to_global(Vector3(0, 0, -0.8))
		check(not door.can_interact(player), "Cannot use marker from behind the door")
		player.global_position = door.to_global(Vector3(0, 0.3, 1.1))
		var encounter := BaseEncounter.new(); encounter.name = "TemporaryEncounter"
		city.add_child(encounter); encounter.state = BaseEncounter.EncounterState.ACTIVE
		var city_id := city.get_instance_id()
		var city_clock: Node = get_first_node_in_group(&"game_clock")
		city_clock.set_time(23.5)
		city_clock.cycle_running = false
		var expected_return: Vector3 = door.to_global(Vector3(0, 0.4, 1.4))
		print("HIDEOUT_CYCLE ", cycle, " ENTER")
		Input.action_press("pick_up_vehicle")
		for tick in 3: await physics_frame
		await process_frame
		Input.action_release("pick_up_vehicle")
		while root.get_node("LoadingScreen").active: await process_frame
		var travel := get_first_node_in_group(&"hideout_travel")
		check(travel != null, "E starts travel through player input")
		if travel == null: quit(1); return
		check(current_scene.name == &"GasStationInterior", "Interior is the active separate scene")
		var room_clock: Node = current_scene.get_node("Clock")
		check(is_equal_approx(room_clock.time_of_day, 23.5) and not room_clock.cycle_running, "City time and clock settings survive entry")
		room_clock.advance_hours(8.0)
		var player_hud: Node = player.get_node("GameplayHUD")
		player_hud._refresh_clock()
		check(player_hud.get_node("Clock").text == "07:30", "Transferred HUD reconnects to indoor clock")
		check(not is_instance_valid(city), "City completely unloaded")
		check(not is_instance_valid(encounter), "Old encounters discarded")
		check(player.get_instance_id() == identity and player.get_parent() == current_scene, "Same player transferred")
		check(player.stats.money == money, "Character stats preserved")
		check(player.spring_arm.position.x > 0.0 and player.spring_arm.spring_length < 2.0, "Close right-shoulder camera indoors")
		if cycle == 0:
			audit(current_scene)
			await physics_frame; await physics_frame
			var space := player.get_world_3d().direct_space_state
			for point in [Vector3(-6,2,-3),Vector3(3,2,-4),Vector3(-3.45,2,-3.25)]:
				var ray := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 3, 1)
				ray.exclude = [player.get_rid()]
				var hit := space.intersect_ray(ray)
				check(not hit.is_empty() and absf(hit.position.y - 0.36) < 0.06, "Solid floor including connecting threshold")
			var opening := PhysicsRayQueryParameters3D.create(Vector3(-6,1.5,-3.25),Vector3(0,1.5,-3.25),1)
			opening.exclude = [player.get_rid()]
			check(space.intersect_ray(opening).is_empty(), "Office-to-garage doorway is clear")
			if "--render" in OS.get_cmdline_user_args(): await render_views(current_scene)
		# The machine reuses the menu transferred from the city on each visit.
		var machine: Node3D = current_scene.get_node("power_machine/Interaction")
		var menu: Node = get_first_node_in_group(&"gameplay_menu")
		player.global_position = machine.to_global(Vector3(0, 1.05, 2.0))
		Input.action_press("pick_up_vehicle")
		for tick in 3: await physics_frame
		Input.action_release("pick_up_vehicle")
		check(menu.visible and paused and menu.tabs.current_tab == 0, "E at machine opens transferred Powers menu")
		check(menu.powers_page.progression == player.get_node("PlayerPowerController").progression, "Machine retains actual player progression")
		check(get_nodes_in_group(&"gameplay_menu").size() == 1, "Machine does not duplicate the city menu")
		menu.close_menu()
		if "--quit-inside" in OS.get_cmdline_user_args():
			print("HIDEOUT_QUIT_INSIDE failures=", failures)
			quit(1 if failures else 0); return
		var room := current_scene
		var exit_door: Node3D = room.get_node("ExitDoor")
		player.global_position = Vector3(-5.14, 1.4, 0.5)
		while Time.get_ticks_msec() < travel._cooldown_until + 100: await process_frame
		check(exit_door.can_interact(player), "Inside exit is reachable")
		Input.action_press("pick_up_vehicle")
		for tick in 3: await physics_frame
		await process_frame
		Input.action_release("pick_up_vehicle")
		while root.get_node("LoadingScreen").active: await process_frame
		city = current_scene
		check(city.name == &"Main" and city.get_instance_id() != city_id, "Exit loads a fresh city")
		var returned_clock: Node = get_first_node_in_group(&"game_clock")
		check(is_equal_approx(returned_clock.time_of_day, 7.5) and not returned_clock.cycle_running, "Eight-hour skip persists on return to the city")
		check(returned_clock._sun.visible, "Returned city lighting reflects morning time")
		player_hud._refresh_clock()
		check(player_hud.get_node("Clock").text == "07:30", "Transferred HUD reconnects to outdoor clock")
		check(player.get_parent() == city and player.get_instance_id() == identity, "Existing player returns without progress reset")
		check(is_equal_approx(player.spring_arm.spring_length, spring), "Outdoor camera restored")
		check(player.camera_effects.base_spring_arm_position.is_equal_approx(outdoor_pivot), "Outdoor camera pivot restored after repeat visits")
		check(player.global_position.distance_to(expected_return) < 0.5, "Return is safely outside the placed station")
		check(not is_instance_valid(room), "Interior unloaded on exit")
		check(city.get_node_or_null("TemporaryEncounter") == null, "Encounter does not survive reload")
		while Time.get_ticks_msec() < travel._cooldown_until + 100: await process_frame
	print("HIDEOUT_TEST_PASS failures=", failures)
	quit(1 if failures else 0)
func audit(room: Node) -> void:
	var triangles := 0
	var surfaces := 0
	for mesh: MeshInstance3D in room.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var indices: int = mesh.mesh.surface_get_array_index_len(index)
			triangles += int((indices if indices else mesh.mesh.surface_get_array_len(index)) / 3)
			surfaces += 1
			var material := mesh.get_active_material(index) as StandardMaterial3D
			check(material != null, "Imported materials exist")
			if not material.emission_enabled: check(material.albedo_texture != null, "Interior UV atlas imports")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "interior_manifest.json"))
	check(triangles == int(data.triangles) and triangles < 5000, "Actual imported interior stays below 5k")
	var placed_triangles := 0
	for mesh: MeshInstance3D in room.get_node("power_machine").find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var indices: int = mesh.mesh.surface_get_array_index_len(index)
			placed_triangles += int((indices if indices else mesh.mesh.surface_get_array_len(index)) / 3)
	check(triangles + placed_triangles + 2200 < 10000, "Combined exterior/interior and machine remain below POI budget")
	var file := FileAccess.open(BASE + "interior_triangle_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"triangles":triangles,"surfaces":surfaces,"placed_machine_triangles":placed_triangles,"combined_with_exterior":triangles+placed_triangles+2200,"failures":failures},"\t") + "\n")

func render_views(room: Node3D) -> void:
	var camera := Camera3D.new(); room.add_child(camera); camera.current = true; camera.fov = 80
	var player: Node3D = room.get_node("Player"); player.hide()
	for view in [["garage",Vector3(-2.4,2.65,-.25),Vector3(3,1.8,-6)], ["office",Vector3(-4.1,2.4,-1),Vector3(-8.0,1.6,-5)], ["workbench",Vector3(5,2.6,-3.9),Vector3(2.5,1.7,-8)]]:
		camera.position = view[1]; camera.look_at(view[2])
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/gas_station_hideout/interior_" + view[0] + ".png")
	player.show(); camera.queue_free(); player.get_node("SpringArm3D/Camera3D").make_current()
	for frame in 12: await physics_frame
	print("INTERIOR_CAMERA ", player.get_node("SpringArm3D/Camera3D").global_position, " hero ", player.global_position, " hit ", player.get_node("SpringArm3D").get_hit_length(), " margin ", player.get_node("SpringArm3D").margin)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/gas_station_hideout/interior_player.png")

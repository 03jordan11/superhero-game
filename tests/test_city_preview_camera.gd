extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var city := load("res://scenes/super_city.tscn").instantiate() as Node3D
	root.add_child(city)
	current_scene = city
	await process_frame
	await process_frame
	assert(not city.has_node("Player"))
	var camera := city.get_node("PreviewCamera") as Camera3D
	assert(camera.is_current() and camera.is_processing())
	assert(get_nodes_in_group(&"player").is_empty())
	assert(city.get_node("CivilianCrowd").get_node(city.get_node("CivilianCrowd").player_path) == camera)
	city.free()
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	assert(not main.has_node("SuperCity/Player"))
	assert(not main.has_node("SuperCity/PreviewCamera"))
	assert(get_nodes_in_group(&"player").size() == 1)
	assert(main.get_node("Player/SpringArm3D/Camera3D").is_current())
	main.free()
	print("PASS: Standalone city camera and single Main player/camera")
	quit()

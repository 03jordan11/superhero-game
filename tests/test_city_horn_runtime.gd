extends SceneTree
## Real process frames and natural audio completion; no manual _process or finished calls.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene: Node = load("res://scenes/super_city.tscn").instantiate()
	var sound: Node = scene.get_node("Sound")
	scene.remove_child(sound)
	scene.free()
	var city := Node3D.new()
	root.add_child(city)
	var hero := Node3D.new()
	city.add_child(hero)
	hero.add_to_group(&"player")
	var camera := Camera3D.new()
	hero.add_child(camera)
	camera.make_current()
	var horns = sound.get_node("CityHorns")
	horns.first_horn_delay = 0.2
	horns.minimum_interval = 1.0
	horns.maximum_interval = 1.0
	horns.minimum_pitch = 2.0
	horns.maximum_pitch = 2.0
	city.add_child(sound)
	var deadline := Time.get_ticks_msec() + 9000
	while horns.automatic_horns_played < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed: bool = horns.automatic_horns_played >= 2
	if not passed: push_error("Automatic horns must start and repeat on real frames without the preview button")
	print("Automatic horn runtime: %s (%d automatic plays)" % ["PASS" if passed else "FAIL", horns.automatic_horns_played])
	city.free()
	quit(0 if passed else 1)

extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Loading test timed out"); quit(1))
	var loading := root.get_node("LoadingScreen")
	loading.error_display_seconds = 0.01
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(loading.begin("ENTERING HIDEOUT"), "First transition accepted")
	check(loading.visible and paused and root.is_input_disabled(), "Overlay pauses simulation and blocks menu input")
	check(not loading.begin("DUPLICATE"), "Repeated requests rejected")
	await loading.checkpoint(42, "Loading resources…")
	loading.set_progress(10, "Loading resources…")
	check(loading.progress_bar.value == 42, "Progress never moves backwards")
	if "--render" in OS.get_cmdline_user_args():
		await loading.present()
		root.get_texture().get_image().save_png("res://artifacts/loading_screen.png")
	var resource: PackedScene = await loading.load_scene("res://scenes/main_menu.tscn", 42, 85)
	check(resource != null and loading.progress_bar.value == 85, "Threaded loading returns the destination scene")
	check(loading.visible and paused, "Screen remains up while caller prepares scene")
	await loading.finish(true)
	check(not loading.active and not loading.visible and not paused and not root.is_input_disabled(), "Success restores input and simulation")
	check(loading.progress_bar.value == 100, "Only successful completion reaches 100 percent")
	# Failure must also restore a previously paused menu and its mouse state.
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	loading.begin("LOADING")
	resource = await loading.load_scene("res://missing_loading_destination.tscn", 0, 85)
	check(resource == null, "Missing destination fails cleanly")
	await loading.finish(false)
	check(paused and not loading.active and not root.is_input_disabled(), "Failure restores the prior pause and input state")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Failure restores menu cursor")
	# Exercise the real travel failure path: the current scene must survive.
	paused = false
	var source := Node3D.new()
	root.add_child(source)
	current_scene = source
	var door := Node3D.new()
	door.set_script(load("res://scripts/hideout_door.gd"))
	door.interior_scene = "res://missing_loading_destination.tscn"
	var prompt := Label3D.new()
	prompt.name = "Prompt"
	door.add_child(prompt)
	source.add_child(door)
	var travel: Node = load("res://scripts/hideout_travel.gd").new()
	root.add_child(travel)
	await travel._transition(door)
	check(current_scene == source and not travel._busy and not paused, "Failed travel preserves the original scene and unlocks interaction")
	travel.free()
	source.free()
	print("LOADING_SCREEN_TEST failures=", failures)
	quit(1 if failures else 0)

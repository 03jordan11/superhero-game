extends SceneTree
## Run without --headless to exercise actual OS window decorations/mode changes.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in 8: await process_frame
func check_fit(screen: int, borderless: bool) -> void:
	var id := root.get_window_id()
	var outer := Rect2i(DisplayServer.window_get_position_with_decorations(id), DisplayServer.window_get_size_with_decorations(id))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	check(root.mode == Window.MODE_WINDOWED and root.borderless == borderless, "Requested window mode applied")
	check(root.current_screen == screen, "Selection stays on the original monitor")
	check(usable.encloses(outer), "Whole window, including title bar, fits usable screen: %s in %s" % [outer, usable])
	check((outer.get_center() - usable.get_center()).length() <= 2, "Whole window centered in work area")
	print("DISPLAY_FIT screen=", screen, " borderless=", borderless, " outer=", outer, " usable=", usable)
func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Display fit test timeout"); quit(1))
	if DisplayServer.get_name() == "headless":
		print("SKIP: native window placement requires a graphical display")
		quit()
		return
	var settings := root.get_node("GameSettings")
	# All requests are non-persistent; never modify the player's preferences.
	var screen := root.current_screen
	paused = true # Changes originate in the paused settings menu too.
	for mode in [0, 1]:
		settings.set_display_settings(2, Vector2i(1920,1080), false)
		await settle()
		settings.set_display_settings(mode, Vector2i(7680,4320), false)
		await settle()
		check_fit(screen, mode == 1)
		check(settings.window_resolution == Vector2i(7680,4320), "Oversize preference retained for larger displays")
		settings.set_display_settings(mode, Vector2i(960,540), false)
		await settle()
		check_fit(screen, mode == 1)
		check(root.size == Vector2i(960,540), "Fitting resolution is not unnecessarily reduced")
		root.position = DisplayServer.screen_get_position(screen) - Vector2i(200,400)
		settings.set_display_settings(mode, Vector2i(1280,720), false)
		await settle()
		check_fit(screen, mode == 1)
	# Simulate quick selections before previous deferred placement work executes.
	settings.set_display_settings(0, Vector2i(1920,1080), false)
	settings.set_display_settings(1, Vector2i(1280,720), false)
	settings.set_display_settings(2, Vector2i(1920,1080), false)
	await settle()
	check(root.mode == Window.MODE_FULLSCREEN, "Stale windowed callbacks cannot override fullscreen")
	settings.set_display_settings(1, Vector2i(1920,1080), false)
	settings.set_display_settings(0, Vector2i(960,540), false)
	await settle()
	check_fit(screen, false)
	check(root.size == Vector2i(960,540), "Latest rapid selection wins")
	for other_screen in DisplayServer.get_screen_count():
		if other_screen == screen: continue
		root.current_screen = other_screen
		await settle()
		for mode in [0, 1]:
			settings.set_display_settings(mode, Vector2i(7680,4320), false)
			await settle()
			check_fit(other_screen, mode == 1)
		settings.set_display_settings(0, Vector2i(960,540), false)
		await settle()
	paused = false
	print("DISPLAY_WINDOW_FIT failures=", failures)
	quit(1 if failures else 0)

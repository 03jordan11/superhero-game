extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func speed(expected: float, message: String) -> void:
	check(is_equal_approx(Engine.time_scale, expected) and is_equal_approx(AudioServer.playback_speed_scale, expected), message)

func run() -> void:
	var helper := root.get_node("SlowMotion")
	var first := Node.new()
	var second := Node.new()
	root.add_child(first)
	root.add_child(second)
	# Advance transition time explicitly to check intermediate audio/game speeds.
	helper.set_process(false)
	check(helper.ease_in_seconds == 0.1 and helper.ease_out_seconds == 0.5, "Default easing durations")
	helper.start(first, 0.5)
	speed(1.0, "Starting slowdown does not snap speed")
	helper._advance(0.05)
	speed(0.75, "Ease-in midpoint scales game and audio together")
	helper.start(first, 0.5)
	helper._advance(0.05)
	speed(0.5, "Repeated start does not restart the transition")
	helper.stop(first)
	speed(0.5, "Stopping does not snap back")
	helper._advance(0.25)
	speed(0.75, "Ease-out midpoint")
	helper.start(second, 0.25)
	helper._advance(0.1)
	speed(0.25, "New request during fade keeps original baseline")
	helper.stop(second)
	helper._advance(0.5)
	speed(1.0, "Tail restores original baseline")
	helper.start(first, 0.5)
	helper._advance(0.1)
	helper.start(second, 0.25)
	helper._advance(0.1)
	helper.stop(second)
	helper._advance(0.25)
	speed(0.375, "Releasing strongest smoothly returns to remaining request")
	helper._advance(0.25)
	speed(0.5, "Remaining request survives another request release")
	helper.stop(first)
	helper.cancel_all()
	speed(1.0, "Global cancellation also clears a pending fade")
	helper.set_process(true)
	# Verify the optional instant tuning and legacy request lifecycle as well.
	helper.ease_in_seconds = 0.0
	helper.ease_out_seconds = 0.0
	check(helper.start(first, 0.5), "Any scene node can request slow motion")
	speed(0.5, "Game and all audio share half speed")
	helper.start(first, 0.5)
	speed(0.5, "Repeated request cannot compound slowdown")
	helper.start(second, 0.25)
	speed(0.25, "Strongest of overlapping requests wins")
	helper.stop(first)
	speed(0.25, "Ending one power cannot prematurely restore another")
	helper.stop(second)
	speed(1.0, "Final release restores game and audio")
	Engine.time_scale = 0.8
	helper.start(first, 0.5)
	speed(0.4, "Preserves the previous game speed as the baseline")
	helper.start(second, 0.25)
	helper.stop(second)
	speed(0.4, "Removing strongest request resumes the remaining slowdown")
	helper.start(first, 0.75)
	speed(0.6, "Caller can update its own slowdown")
	helper.stop(first)
	speed(0.8, "Both speeds return to the original baseline")
	Engine.time_scale = 1.0
	helper.start(first, 0.5)
	first.free()
	speed(1.0, "Deleting source automatically restores game/audio")
	helper.start(second, 0.5)
	paused = true
	await process_frame
	await process_frame
	speed(1.0, "Pause cannot strand slowed audio")
	check(not helper.start(second, 0.2), "Paused scenes cannot start slow motion")
	paused = false
	helper.start(second, 0.5)
	helper._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	speed(1.0, "Focus loss restores game/audio")
	check(not helper.start(null, 0.5), "Invalid source cannot leave an unowned slowdown")
	helper.stop(second)
	speed(1.0, "Late/idempotent release is harmless")
	second.free()
	print("SLOW_MOTION_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

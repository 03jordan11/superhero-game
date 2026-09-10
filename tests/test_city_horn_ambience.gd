extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var packed_city: Node = load("res://scenes/super_city.tscn").instantiate()
	var sound: Node = packed_city.get_node("Sound")
	packed_city.remove_child(sound)
	packed_city.free()
	var city := Node3D.new()
	root.add_child(city)
	city.add_child(sound)
	var ambience = sound.get_node("CityAmbiances")
	var horns = sound.get_node("CityHorns")
	ambience.set_process(false)
	horns.set_process(false)
	horns.volume_variation_db = 0.0
	horns._random.seed = 8301
	check(not horns.playing and horns._remaining == 8.0, "First horn uses the short configurable startup delay")
	var remaining: float = horns._remaining
	horns._process(5.0)
	check(not horns.playing and horns._remaining == remaining and horns.volume_linear == 0.0, "Missing hero is silent and does not consume the interval")
	var hero := Node3D.new()
	city.add_child(hero)
	hero.add_to_group(&"player")
	var camera := Camera3D.new()
	hero.add_child(camera)
	camera.position = Vector3(0, 4, 10)
	camera.make_current()
	ambience._process(3.0)
	horns._remaining = 0.2
	horns._process(0.1)
	check(not horns.playing, "Horn waits until the interval expires")
	horns._process(0.11)
	check(horns.playing and not horns.stream.loop, "Interval expiry starts one non-looping horn")
	var distance: float = horns.global_position.distance_to(hero.global_position)
	check(distance >= 120.0 and distance <= 220.0, "Horn is placed randomly around the hero")
	check(horns.pitch_scale >= 0.75 and horns.pitch_scale <= 1.2, "Horn pitch and playback speed stay within tuning limits")
	var selected_stream: AudioStream = horns.stream
	horns._process(500.0)
	check(horns.stream == selected_stream, "An active horn is not replaced by another")
	hero.position = Vector3(500, 0, 0)
	horns._process(0.1)
	check(is_equal_approx(horns.global_position.distance_to(hero.global_position), distance), "Horn stays distant while the hero moves quickly")
	hero.position = Vector3(-292, 0, 0)
	ambience._process(3.0)
	horns._process(0.1)
	check(is_equal_approx(horns.volume_linear, db_to_linear(horns.base_volume_db) * 0.15), "Horns share the park fade")
	hero.position.y = 110.0
	ambience._process(3.0)
	horns._process(0.1)
	check(is_equal_approx(horns.volume_linear, db_to_linear(horns.base_volume_db) * 0.075), "Horns combine park and height fades")
	hero.position = Vector3(1600, 0, 0)
	ambience._process(3.0)
	horns._process(0.1)
	check(is_equal_approx(horns.volume_linear, db_to_linear(horns.base_volume_db) * 0.5), "Horns share the city boundary fade")
	hero.position = Vector3(0, 250, 0)
	ambience._process(3.0)
	horns._process(0.1)
	check(horns.volume_linear == 0.0 and not horns.playing, "Inaudible horns stop decoding above the city")
	horns.stop()
	horns.finished.emit()
	check(horns._remaining >= 45.0 and horns._remaining <= 120.0, "Finishing schedules fresh silence between horns")
	remaining = horns._remaining
	var count_before: int = horns.automatic_horns_played
	selected_stream = horns.stream
	horns._process(500.0)
	check(not horns.playing and horns._remaining == 0.0 and horns.automatic_horns_played == count_before and horns.stream == selected_stream, "Out-of-range time only updates a countdown without selecting or playing silent clips")
	hero.position = Vector3.ZERO
	ambience._process(3.0)
	horns._process(0.01)
	check(horns.playing and horns.automatic_horns_played == count_before + 1, "Returning to the city plays exactly one due horn")
	horns.stop()
	horns._remaining = 0.0
	hero.position = Vector3(0, 250, 0)
	ambience._process(0.01)
	horns._process(0.01)
	check(not horns.playing, "No new horn starts outside range while an old environmental fade is still audible")
	hero.position = Vector3.ZERO
	ambience._process(3.0)
	var used_clips := {}
	var pitches := {}
	for index in range(20):
		horns._play_random_horn(camera.global_position, 1.0)
		for clip_index in range(horns.horn_sounds.size()):
			if horns.stream.data == horns.horn_sounds[clip_index].data:
				used_clips[clip_index] = true
		pitches[horns.pitch_scale] = true
		horns.stop()
	check(used_clips.size() == 2 and pitches.size() > 1, "Both recordings and varied pitches are used")
	horns._play_random_horn(camera.global_position, 1.0)
	horns.horns_enabled = false
	horns._process(0.1)
	check(not horns.playing and horns.volume_linear == 0.0, "Disabling horns stops their playback")
	horns.horns_enabled = true
	horns.minimum_interval = 2.0
	horns.maximum_interval = 2.0
	horns._process(0.1)
	check(not horns.playing and is_equal_approx(horns._remaining, 1.9), "Live frequency edits reschedule immediately")
	ambience.ambience_enabled = false
	ambience._process(3.0)
	horns._process(10.0)
	check(not horns.playing and horns.volume_linear == 0.0, "City ambience disable also fades horns out")
	city.free()
	print("Distant city horns: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

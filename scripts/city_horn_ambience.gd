extends AudioStreamPlayer3D
## Occasional distant horns. CityAmbiances owns the shared environmental fade rules.

@export_category("Distant Horn Ambience")
@export var horns_enabled := true
@export_node_path("AudioStreamPlayer") var city_ambience_path: NodePath = ^"../CityAmbiances"
@export var horn_sounds: Array[AudioStream] = [
	preload("res://assets/audio/Vehicles/car_horn_one_beep.mp3"),
	preload("res://assets/audio/Vehicles/car_horn_two_beeps.mp3"),
]
## Overall level before spatial attenuation and the shared city fade.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var base_volume_db := -8.0
@export_range(0.0, 6.0, 0.5, "suffix:dB") var volume_variation_db := 2.0

@export_group("Frequency")
## A short initial wait makes this layer audible shortly after entering gameplay.
@export_range(0.0, 120.0, 1.0, "suffix:s") var first_horn_delay := 8.0
## Random silence after each horn finishes.
@export_range(1.0, 600.0, 1.0, "suffix:s") var minimum_interval := 45.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var maximum_interval := 120.0

@export_group("Distance")
## Distance from the hero. Each horn selects a new random horizontal direction.
@export_range(30.0, 1000.0, 5.0, "suffix:m") var minimum_distance := 120.0
@export_range(30.0, 1000.0, 5.0, "suffix:m") var maximum_distance := 220.0

@export_group("Pitch And Playback Speed")
## Pitch scaling also changes playback duration; lower = deeper and slower.
@export_range(0.5, 2.0, 0.01) var minimum_pitch := 0.75
@export_range(0.5, 2.0, 0.01) var maximum_pitch := 1.2

var _random := RandomNumberGenerator.new()
var _remaining := 0.0
var _interval_range := Vector2.ZERO
var _offset := Vector3.ZERO
var _volume_offset := 0.0
var automatic_horns_played := 0

func _ready() -> void:
	add_to_group(&"city_horn_ambience")
	process_priority = 1 # Read this frame's fade after CityAmbiances updates.
	_random.randomize()
	volume_linear = 0.0
	finished.connect(_on_horn_finished)
	_schedule_next_horn()
	_remaining = maxf(0.0, first_horn_delay)

func _process(delta: float) -> void:
	if _interval_range != Vector2(minimum_interval, maximum_interval):
		_schedule_next_horn() # Frequency edits take effect immediately in Remote Inspector.
	if not horns_enabled:
		if playing:
			stop()
			_schedule_next_horn()
		volume_linear = 0.0
		return
	var ambience := get_node_or_null(city_ambience_path)
	if ambience == null or not ambience.has_method("get_fade_gain"):
		volume_linear = 0.0
		return
	var hero: Node3D = ambience.get_ambience_hero()
	var gain: float = ambience.get_fade_gain() if hero != null else 0.0
	volume_linear = db_to_linear(base_volume_db + _volume_offset) * gain
	if hero == null:
		if playing: stop()
		return
	# Once the shared fade is inaudible, release playback rather than decoding a
	# silent recording. Keep the due time so re-entry can produce one fresh event.
	if gain < 0.01 and playing: stop()
	# A random offset around the hero stays distant even during fast traversal.
	global_position = hero.global_position + _offset
	if playing: return
	# Count real gameplay time outside the city too, but hold a due event at zero.
	# Returning to range produces one horn, never a backlog of missed events.
	_remaining = maxf(0.0, _remaining - maxf(delta, 0.0))
	if gain < 0.01 or ambience.get_target_fade_gain() < 0.01: return
	if _remaining <= 0.0:
		_play_random_horn(hero.global_position, gain)

func _on_horn_finished() -> void:
	_schedule_next_horn()

func _schedule_next_horn() -> void:
	_interval_range = Vector2(minimum_interval, maximum_interval)
	var lower := maxf(1.0, minf(minimum_interval, maximum_interval))
	var upper := maxf(lower, maxf(minimum_interval, maximum_interval))
	_remaining = _random.randf_range(lower, upper)

func _play_random_horn(listener_position: Vector3, gain: float) -> void:
	var available: Array[AudioStream] = []
	for clip in horn_sounds:
		if clip != null: available.append(clip)
	if available.is_empty():
		_schedule_next_horn()
		return
	stream = available[_random.randi_range(0, available.size() - 1)].duplicate()
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var pitch_low := maxf(0.1, minf(minimum_pitch, maximum_pitch))
	pitch_scale = _random.randf_range(pitch_low, maxf(pitch_low, maxf(minimum_pitch, maximum_pitch)))
	var distance_low := maxf(30.0, minf(minimum_distance, maximum_distance))
	var distance := _random.randf_range(distance_low, maxf(distance_low, maxf(minimum_distance, maximum_distance)))
	var angle := _random.randf_range(0.0, TAU)
	_offset = Vector3(cos(angle), 0.0, sin(angle)) * distance
	global_position = listener_position + _offset
	_volume_offset = _random.randf_range(-absf(volume_variation_db), absf(volume_variation_db))
	volume_linear = db_to_linear(base_volume_db + _volume_offset) * gain
	play()
	automatic_horns_played += 1

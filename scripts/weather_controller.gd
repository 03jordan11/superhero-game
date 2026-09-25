extends Node3D
## Persistent session weather; scenes own their lighting, this node owns timing/audio.
signal weather_changed(weather: StringName)
signal lightning_struck(direction: Vector3, distance: float)
signal thunder_played
const RAIN = preload("res://effects/weather_rain.gd")
const RAIN_AUDIO = preload("res://assets/audio/weather/rain_loop.wav")
const THUNDER = [preload("res://assets/audio/weather/thunder_1.wav"), preload("res://assets/audio/weather/thunder_2.wav"), preload("res://assets/audio/weather/thunder_3.wav")]
@export var transition_seconds := 6.0
@export var lightning_interval_min := 8.0
@export var lightning_interval_max := 18.0
@export var lightning_distance_min := 600.0
@export var lightning_distance_max := 1800.0
@export var rain_volume_db := -13.0
@export var thunder_volume_db := -6.0
var current_weather: StringName = &"clear"
var thunderstorm_cooldown_remaining := 0.0
var lightning_strike_cooldown_remaining := 0.0
# Session-owned like the other power cooldowns, including travel between scenes.
var external_combustion_cooldown_remaining := 0.0
var frost_wall_cooldown_remaining := 0.0
var storm_amount := 0.0
var flash := 0.0
var lightning_direction := Vector3.FORWARD
var lightning_seed := 0.0
var indoor_amount := 0.0
var sheltered := false
var presentation_enabled := false
var next_lightning := 10.0
var pending_thunder: Array[Dictionary] = []
var _flash_age := 1.0
var _probe_remaining := 0.0
var _scene_id := 0
var _rain: MultiMeshInstance3D
var _rain_audio: AudioStreamPlayer
var _thunder_audio: Array[AudioStreamPlayer] = []
var _filter: AudioEffectLowPassFilter
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	_rain = RAIN.new()
	_rain.name = "Rain"
	add_child(_rain)
	var bus := AudioServer.get_bus_index("Weather")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Weather")
		AudioServer.set_bus_send(bus, "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master")
	_filter = AudioEffectLowPassFilter.new()
	_filter.cutoff_hz = 18000.0
	AudioServer.add_bus_effect(bus, _filter)
	_rain_audio = _audio_player()
	_rain_audio.stream = RAIN_AUDIO.duplicate()
	_rain_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_rain_audio.stream.loop_end = int(_rain_audio.stream.get_length() * _rain_audio.stream.mix_rate)
	for i in 3: _thunder_audio.append(_audio_player())

func _audio_player() -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.bus = &"Weather"
	add_child(audio)
	return audio

func is_thunderstorm() -> bool:
	return current_weather == &"thunderstorm"

func summon_thunderstorm(cooldown_seconds: float) -> bool:
	if is_thunderstorm() or thunderstorm_cooldown_remaining > 0.0: return false
	thunderstorm_cooldown_remaining = maxf(0.0, cooldown_seconds)
	return set_weather(&"thunderstorm")

func begin_lightning_strike_cooldown(seconds: float) -> bool:
	if not is_thunderstorm() or lightning_strike_cooldown_remaining > 0.0: return false
	lightning_strike_cooldown_remaining = maxf(0.0, seconds)
	return true

func set_weather(value: StringName) -> bool:
	if value not in [&"clear", &"thunderstorm"]: return false
	if value == current_weather: return true
	current_weather = value
	if is_thunderstorm():
		next_lightning = _random.randf_range(3.0, 6.0)
	else:
		pending_thunder.clear()
		flash = 0.0
		_flash_age = 1.0
		for audio in _thunder_audio: audio.stop()
	weather_changed.emit(current_weather)
	return true

func status_text() -> String:
	return "Weather: %s | storm %.0f%% | %s" % [current_weather, storm_amount * 100, "indoors / sheltered" if sheltered else "outdoors"]

func trigger_lightning() -> bool:
	if not is_thunderstorm(): return false
	var angle := _random.randf_range(-PI, PI)
	lightning_direction = Vector3(sin(angle), 0, cos(angle))
	lightning_seed = _random.randf() * 1000.0
	_flash_age = 0.0
	flash = 1.0
	var distance := _random.randf_range(lightning_distance_min, lightning_distance_max)
	pending_thunder.append({"remaining": distance / 343.0, "clip": _random.randi_range(0, THUNDER.size() - 1)})
	next_lightning = _random.randf_range(lightning_interval_min, lightning_interval_max)
	lightning_struck.emit(lightning_direction, distance)
	return true

func _physics_process(delta: float) -> void:
	var scene := get_tree().current_scene
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	var active_scene := scene != null and is_instance_valid(hero) and (scene == hero or scene.is_ancestor_of(hero))
	var scene_id := scene.get_instance_id() if scene != null else 0
	if scene_id != _scene_id:
		_scene_id = scene_id
		_probe_remaining = 0.0
		# Silence presentation immediately across menus, load gaps and simulation scenes.
		_rain.hide()
		_rain_audio.stop()
		for audio in _thunder_audio: audio.stop()
	presentation_enabled = active_scene and not scene.is_in_group(&"combat_arena") if scene != null else false
	advance_weather(delta)
	if not presentation_enabled:
		_rain.hide()
		_rain_audio.stop()
		return
	var camera := get_viewport().get_camera_3d()
	var outdoors := not get_tree().get_nodes_in_group(&"day_night_cycle").is_empty() and not scene.is_in_group(&"weather_indoors")
	_probe_remaining -= delta
	if outdoors and camera != null and storm_amount > 0.001 and camera.global_position.distance_squared_to(_rain.global_position) > 64.0:
		_probe_remaining = 0.0
	if _probe_remaining <= 0.0:
		_probe_remaining = 0.15
		sheltered = not outdoors
		var excluded: Array[RID] = []
		if hero is CollisionObject3D: excluded.append(hero.get_rid())
		if outdoors:
			var head := hero.global_position + Vector3.UP * 0.65
			var query := PhysicsRayQueryParameters3D.create(head, head + Vector3.UP * 2048, 1, excluded)
			sheltered = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if outdoors and camera != null and storm_amount > 0.001:
			_rain.sample_roofs(camera.global_position, excluded)
	indoor_amount = move_toward(indoor_amount, 1.0 if sheltered else 0.0, delta * 2.0)
	_filter.cutoff_hz = lerpf(18000.0, 850.0, indoor_amount)
	_rain.update_rain(delta, storm_amount if outdoors and camera != null else 0.0)
	_rain_audio.volume_db = rain_volume_db + linear_to_db(maxf(storm_amount, 0.0001)) - indoor_amount * 10.0
	if storm_amount > 0.001:
		if not _rain_audio.playing: _rain_audio.play()
	else: _rain_audio.stop()
	for audio in _thunder_audio: audio.volume_db = thunder_volume_db - indoor_amount * 8.0

func advance_weather(delta: float) -> void:
	thunderstorm_cooldown_remaining = maxf(0.0, thunderstorm_cooldown_remaining - maxf(0.0, delta))
	lightning_strike_cooldown_remaining = maxf(0.0, lightning_strike_cooldown_remaining - maxf(0.0, delta))
	external_combustion_cooldown_remaining = maxf(0.0, external_combustion_cooldown_remaining - maxf(0.0, delta))
	frost_wall_cooldown_remaining = maxf(0.0, frost_wall_cooldown_remaining - maxf(0.0, delta))
	storm_amount = move_toward(storm_amount, 1.0 if is_thunderstorm() else 0.0, delta / maxf(transition_seconds, 0.001))
	_flash_age += delta
	flash = maxf(0.0, 1.0 - _flash_age / 0.12)
	if _flash_age > 0.17 and _flash_age < 0.27: flash = 0.6 * (1.0 - (_flash_age - 0.17) / 0.1)
	for i in range(pending_thunder.size() - 1, -1, -1):
		pending_thunder[i].remaining -= delta
		if pending_thunder[i].remaining <= 0.0:
			if presentation_enabled:
				for audio in _thunder_audio:
					if not audio.playing:
						audio.stream = THUNDER[pending_thunder[i].clip]
						audio.pitch_scale = _random.randf_range(0.93, 1.06)
						audio.play()
						thunder_played.emit()
						break
			pending_thunder.remove_at(i)
	if is_thunderstorm() and presentation_enabled:
		next_lightning -= delta
		if next_lightning <= 0.0: trigger_lightning()

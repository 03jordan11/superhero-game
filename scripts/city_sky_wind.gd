extends AudioStreamPlayer
## Gentle altitude ambience, independent of whether the hero is flying or hovering.

@export var wind_enabled := true
@export_node_path("AudioStreamPlayer") var city_ambience_path: NodePath = ^"../CityAmbiances"
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var base_volume_db := -22.0
@export_group("Height")
@export_range(0.0, 2000.0, 1.0, "suffix:m") var start_height := 20.0
@export_range(0.0, 2000.0, 1.0, "suffix:m") var full_height := 200.0
@export_group("Transitions")
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_in_seconds := 1.8
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_out_seconds := 1.2

var _gain := 0.0

func _ready() -> void:
	process_priority = 1
	volume_linear = 0.0
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)

func _process(delta: float) -> void:
	var target := calculate_target_gain()
	var seconds := fade_in_seconds if target > _gain else fade_out_seconds
	_gain = target if seconds <= 0.0 else move_toward(_gain, target, maxf(delta, 0.0) / seconds)
	volume_linear = db_to_linear(base_volume_db) * _gain
	if _gain <= 0.001:
		stop() # No decoding at street level or outside the audible city.
	elif stream != null and not playing:
		play()

func calculate_target_gain() -> float:
	if not wind_enabled: return 0.0
	var ambience := get_node_or_null(city_ambience_path)
	if ambience == null or not ambience.has_method("get_ambience_hero") or not ambience.ambience_enabled:
		return 0.0
	var hero: Node3D = ambience.get_ambience_hero()
	var city_root := ambience.get_node_or_null(ambience.city_root_path) as Node3D
	if hero == null or city_root == null: return 0.0
	var city_position := city_root.to_local(hero.global_position)
	var height: float = city_position.y - ambience.street_height
	var altitude := smoothstep(start_height, maxf(start_height + 0.01, full_height), height)
	# Wind remains audible over the park at altitude, but respects the city boundary.
	return altitude * ambience.get_city_boundary_gain(Vector2(city_position.x, city_position.z))

extends AudioStreamPlayer
## Non-positional city ambience. All distances use the city root's local X/Z
## coordinates and street-level Y, so rooftops do not reset the height fade.

@export_category("City Ambience")
@export var ambience_enabled := true
@export var play_on_start := true
@export var loop_ambience := true
## Use this instead of the native Volume property, which the script updates.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var base_volume_db := 0.0
## Optional override. Empty finds the current node in the player group.
@export_node_path("Node3D") var hero_path: NodePath
## Rectangles and street height are relative to this node, normally SuperCity.
@export_node_path("Node3D") var city_root_path: NodePath = ^"../.."

@export_group("Height Fade")
@export var height_fade_enabled := true
@export var street_height := 0.0
@export_range(0.0, 2000.0, 1.0, "suffix:m") var height_fade_start := 20.0
@export_range(0.0, 2000.0, 1.0, "suffix:m") var height_fade_end := 200.0

@export_group("City Boundary Fade")
@export var city_fade_enabled := true
## Position = minimum X/Z; Size = width/depth. Defaults match layout.json.
@export var city_bounds := Rect2(-1500.0, -1000.0, 3000.0, 2000.0)
@export_range(0.0, 2000.0, 1.0, "suffix:m") var city_fade_start_distance := 0.0
@export_range(0.0, 2000.0, 1.0, "suffix:m") var city_fade_end_distance := 200.0

@export_group("Park Fade")
@export var park_fade_enabled := true
## Central park's X/Z rectangle, relative to the city root.
@export var park_bounds := Rect2(-546.0, -302.0, 508.0, 604.0)
## Distance inward from the nearest park edge to reach the reduced volume.
@export_range(0.0, 500.0, 1.0, "suffix:m") var park_fade_distance := 60.0
## Linear volume multiplier in the park interior; 0 = silent, 1 = unchanged.
@export_range(0.0, 1.0, 0.01) var park_volume_scale := 0.15

@export_group("Transition Timing")
## Seconds for a full-volume change. Zero makes the corresponding change instant.
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_in_seconds := 1.8
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_out_seconds := 1.2

var _hero: Node3D
var _current_gain := 0.0

func _ready() -> void:
	# Start silently so city/hero initialization cannot produce a loud first frame.
	volume_linear = 0.0
	if stream != null and loop_ambience:
		# Keep import settings/shared audio resources unchanged.
		stream = stream.duplicate()
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if stream.loop_end <= stream.loop_begin:
				stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if play_on_start and stream != null: play()

func _process(delta: float) -> void:
	var target_gain := 0.0
	var city_root := get_node_or_null(city_root_path) as Node3D
	if not hero_path.is_empty():
		_hero = get_node_or_null(hero_path) as Node3D
	elif not is_instance_valid(_hero) or not _hero.is_inside_tree():
		_hero = get_tree().get_first_node_in_group(&"player") as Node3D
	if ambience_enabled and city_root != null and is_instance_valid(_hero) and _hero.is_inside_tree():
		target_gain = calculate_target_gain(city_root.to_local(_hero.global_position))
	var seconds := fade_in_seconds if target_gain > _current_gain else fade_out_seconds
	_current_gain = target_gain if seconds <= 0.0 else move_toward(_current_gain, target_gain, maxf(delta, 0.0) / seconds)
	volume_linear = db_to_linear(base_volume_db) * _current_gain

## Shared by occasional ambience layers so all city fades stay in sync.
func get_fade_gain() -> float:
	return _current_gain

func get_ambience_hero() -> Node3D:
	return _hero if is_instance_valid(_hero) and _hero.is_inside_tree() else null

## Unsmoothed eligibility: do not start new ambience events during a fade out
## after the hero has already left the city's audible range.
func get_target_fade_gain() -> float:
	var hero := get_ambience_hero()
	var city_root := get_node_or_null(city_root_path) as Node3D
	if hero == null or city_root == null: return 0.0
	return calculate_target_gain(city_root.to_local(hero.global_position))

func calculate_target_gain(city_position: Vector3) -> float:
	if not ambience_enabled: return 0.0
	var horizontal := Vector2(city_position.x, city_position.z)
	var height_gain := 1.0
	var city_gain := 1.0
	var park_gain := 1.0
	if height_fade_enabled:
		height_gain = _fade_out(maxf(0.0, city_position.y - street_height), height_fade_start, height_fade_end)
	if city_fade_enabled:
		city_gain = get_city_boundary_gain(horizontal)
	if park_fade_enabled:
		var bounds := park_bounds.abs()
		if bounds.has_point(horizontal):
			var depth := minf(minf(horizontal.x - bounds.position.x, bounds.end.x - horizontal.x), minf(horizontal.y - bounds.position.y, bounds.end.y - horizontal.y))
			var blend := 1.0 - _fade_out(depth, 0.0, park_fade_distance)
			park_gain = lerpf(1.0, clampf(park_volume_scale, 0.0, 1.0), blend)
	return clampf(height_gain * city_gain * park_gain, 0.0, 1.0)

func get_city_boundary_gain(horizontal: Vector2) -> float:
	if not city_fade_enabled: return 1.0
	var bounds := city_bounds.abs()
	var nearest := Vector2(clampf(horizontal.x, bounds.position.x, bounds.end.x), clampf(horizontal.y, bounds.position.y, bounds.end.y))
	return _fade_out(horizontal.distance_to(nearest), city_fade_start_distance, city_fade_end_distance)

func _fade_out(distance: float, start: float, end: float) -> float:
	# Equal/reversed Inspector thresholds safely produce a narrow transition.
	var lower := maxf(0.0, start)
	var upper := maxf(lower + 0.001, end)
	return 1.0 - smoothstep(lower, upper, distance)

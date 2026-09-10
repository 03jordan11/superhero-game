extends AudioStreamPlayer3D
## Shared engine loop for vehicle scenes. Native audio properties tune distance and volume.

@export var engine_enabled := true
@export var random_start_offset := true

@export_group("Engine Character")
## Pitch also changes the recording's playback speed. Use this instead of native Pitch Scale.
@export_range(0.5, 2.0, 0.01) var base_pitch := 1.0
## Each spawned car gets a stable random multiplier within this fraction of its base pitch.
@export_range(0.0, 0.2, 0.01) var pitch_variation := 0.04
## Fractional pitch increase at the reference driving speed; zero disables speed response.
@export_range(0.0, 0.5, 0.01) var speed_pitch_increase := 0.18
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var pitch_reference_speed := 12.0
## Response rate per second. Zero applies changes immediately.
@export_range(0.0, 10.0, 0.1) var pitch_response := 3.0

var _vehicle: Vehicle
var _pitch_offset := 0.0

func _ready() -> void:
	_vehicle = get_parent() as Vehicle
	if _vehicle != null:
		_vehicle.destroyed.connect(_on_vehicle_destroyed)
		if _vehicle.is_destroyed:
			set_process(false)
			return
	if not engine_enabled or stream == null:
		set_process(false)
		return
	# Local randomness leaves the traffic simulation's random sequence unchanged.
	var random := RandomNumberGenerator.new()
	random.randomize()
	_pitch_offset = random.randf_range(-1.0, 1.0)
	pitch_scale = _target_pitch()
	# Loop this player's copy without changing the imported recording for other uses.
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		stream.loop = true
	var offset := 0.0
	if random_start_offset:
		offset = random.randf() * stream.get_length()
	play(offset)

func _process(delta: float) -> void:
	var target := _target_pitch()
	var blend := 1.0 if pitch_response <= 0.0 else 1.0 - exp(-pitch_response * maxf(delta, 0.0))
	pitch_scale = lerpf(pitch_scale, target, blend)

func _target_pitch() -> float:
	# Traffic moves frozen bodies, so use its actual driving speed, not linear_velocity.
	# Carried/thrown vehicles return to idle instead of revving with the hero's motion.
	var speed := _vehicle.traffic_speed if is_instance_valid(_vehicle) and _vehicle.traffic_controlled else 0.0
	var speed_fraction := clampf(speed / maxf(pitch_reference_speed, 0.01), 0.0, 1.0)
	return clampf(base_pitch * (1.0 + _pitch_offset * pitch_variation) * (1.0 + speed_fraction * speed_pitch_increase), 0.1, 4.0)

func _on_vehicle_destroyed(_impact_speed: float) -> void:
	stop()
	set_process(false)

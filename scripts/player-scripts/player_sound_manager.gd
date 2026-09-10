extends Node
## Player feedback sounds, triggered by the systems that create their matching effects.

@export var sounds_enabled := true
@export_group("Bullet Hits")
@export var bullet_hit_sound: AudioStream = preload("res://assets/audio/player/superhero_bullet_hit.wav")
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var bullet_hit_volume_db := -6.0
@export_range(0.0, 0.2, 0.01) var bullet_hit_pitch_variation := 0.08

@export_group("Heavy Landing")
@export var heavy_landing_sound: AudioStream = preload("res://assets/audio/player/heavy_landing.wav")
## Leaves headroom for the bass boost and reverb on the PlayerImpacts audio bus.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var heavy_landing_volume_db := -3.0
## Lower pitch also slows playback: 0.9 makes the impact about 11% longer.
@export_range(0.5, 2.0, 0.01) var heavy_landing_pitch := 0.9

@export_group("Footsteps")
@export var footsteps_enabled := true
@export var footstep_sound: AudioStream = preload("res://assets/audio/player/generic_footstep.mp3")
## The supplied clip peaks near -30 dB. +24 dB compensates for its quiet recording.
## Tune here: the child player's native volume is updated for every footstep.
@export_range(-60.0, 36.0, 0.5, "or_greater", "suffix:dB") var footstep_volume_db := 24.0
@export_range(0.0, 0.2, 0.01) var footstep_pitch_variation := 0.04

@export_subgroup("Animation Contact Timing")
## Percentage of the animation loop. 0 = start, 50 = halfway; 100 wraps to 0.
## Walking uses the animation named Run (the imported Jog_Fwd clip).
@export_range(0.0, 99.9, 0.1, "suffix:%") var walk_left_contact := 0.0
@export_range(0.0, 99.9, 0.1, "suffix:%") var walk_right_contact := 50.0
@export_range(0.0, 99.9, 0.1, "suffix:%") var sprint_left_contact := 0.0
@export_range(0.0, 99.9, 0.1, "suffix:%") var sprint_right_contact := 50.0

@export_group("Combo Punches")
@export var punch_sounds: Array[AudioStream] = [
	preload("res://assets/audio/combat/melee/punch_1.mp3"),
	preload("res://assets/audio/combat/melee/punch_2.mp3"),
	preload("res://assets/audio/combat/melee/punch_3.mp3"),
]
## Seconds into combo attacks 1, 2, and 3 respectively (X, Y, Z).
@export var punch_sound_delays := Vector3(0.12, 0.16, 0.18)
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var punch_volume_db := -6.0

@export_group("Super Jump Charge")
@export var jump_charge_sound: AudioStream = preload("res://assets/audio/player/super_jump_charge_AI.wav")
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var jump_charge_volume_db := -12.0

@export_group("Speed Wind")
## Speed thresholds and the shared fade live on PlayerSpeedFeedback.
@export var speed_wind_sound: AudioStream = preload("res://assets/audio/player/speed_wind_AI.wav")
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var speed_wind_volume_db := -12.0

@export_group("Death and Heavy Lift")
@export var death_sound: AudioStream = preload("res://assets/audio/player/player_death_AI.wav")
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var death_volume_db := -6.0
@export var heavy_lift_sound: AudioStream = preload("res://assets/audio/player/heavy_lift_AI.wav")
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var heavy_lift_volume_db := -6.0

var _step_animation: StringName = &""
var _pending_punch := -1
var _loop_sources: Dictionary = {}
var _previous_step_phase := 0.0
var _step_random := RandomNumberGenerator.new()
@onready var _player: PlayerCharacter = get_parent() as PlayerCharacter
@onready var _heavy_landing: AudioStreamPlayer = $HeavyLanding
@onready var _footstep: AudioStreamPlayer = $Footstep
@onready var _punch: AudioStreamPlayer = $ComboPunch
@onready var _speed_wind: AudioStreamPlayer = $SpeedWind
@onready var _jump_charge: AudioStreamPlayer = $JumpCharge
@onready var _death: AudioStreamPlayer = $Death
@onready var _heavy_lift: AudioStreamPlayer = $HeavyLift
@onready var _speed_feedback: PlayerSpeedFeedback = get_parent().get_node("PlayerSpeedFeedback")
@onready var _bullet_hit: AudioStreamPlayer = $BulletHit

func _ready() -> void:
	# Sample after AnimationPlayer advances the visible pose in idle processing.
	process_priority = 10
	_step_random.randomize()
	# An editor session opened before this bus existed can save the node as Master.
	if AudioServer.get_bus_index(&"PlayerImpacts") >= 0:
		_heavy_landing.bus = &"PlayerImpacts"
	if AudioServer.get_bus_index(&"PlayerFootsteps") >= 0:
		_footstep.bus = &"PlayerFootsteps"
	if AudioServer.get_bus_index(&"PlayerSpeedWind") >= 0:
		_speed_wind.bus = &"PlayerSpeedWind"
	var landing_controller := get_parent().get_node("PlayerLandingImpactController")
	landing_controller.hard_landing_effect_spawned.connect(play_heavy_landing)
	get_parent().get_node("PlayerCombatController").combo_punch_started.connect(_on_combo_punch_started)
	get_parent().get_node("PlayerDamageReceiver").damage_received.connect(_on_damage_received)
	get_parent().get_node("PlayerVehicleInteractor").vehicle_picked_up.connect(_on_vehicle_picked_up)
	get_parent().get_node("PlayerStateMachine/DeadState").death_started.connect(_on_player_died)
	_player.jump_charge_changed.connect(_on_jump_charge_changed)
	# Also supports non-looping/custom AudioStream types; common file types use native loops.
	_speed_wind.finished.connect(_restart_loop.bind(_speed_wind))
	_jump_charge.finished.connect(_restart_loop.bind(_jump_charge))

func _on_damage_received(damage_info) -> void:
	if damage_info.damage_type != &"bullet" or not sounds_enabled or bullet_hit_sound == null:
		return
	if _bullet_hit.stream != bullet_hit_sound:
		_bullet_hit.stream = bullet_hit_sound
	_bullet_hit.volume_db = bullet_hit_volume_db
	_bullet_hit.pitch_scale = 1.0 + _step_random.randf_range(-bullet_hit_pitch_variation, bullet_hit_pitch_variation)
	_bullet_hit.play()

func _process(delta: float) -> void:
	update_combo_audio()
	update_power_audio(delta)
	var walking := _player.is_on_floor() and _player.state_machine.active_state is PlayerGroundedState
	walking = walking and not _player.combat_controller.is_action_locked()
	var motion := _player.get_real_velocity()
	var animations := _player.animation_controller.animation_player
	if animations == null or not animations.is_playing():
		_step_animation = &""
		return
	update_footsteps(animations.current_animation, animations.current_animation_position,
		animations.current_animation_length, walking, Vector2(motion.x, motion.z).length())

func update_footsteps(animation: StringName, position: float, length: float, walking: bool, horizontal_speed: float) -> void:
	if not sounds_enabled or not footsteps_enabled or footstep_sound == null or not walking or horizontal_speed < 0.3 or length <= 0.0 or animation not in [&"Run", &"Sprint"]:
		_step_animation = &""
		return
	var phase := fposmod(position / length, 1.0)
	if _step_animation != animation:
		_step_animation = animation
		# Catch a contact at the start of a new clip, without replaying older contacts
		# when resuming movement partway through an animation.
		_previous_step_phase = -0.000001 if phase < 0.1 else phase
	var left := (sprint_left_contact if animation == &"Sprint" else walk_left_contact) / 100.0
	var right := (sprint_right_contact if animation == &"Sprint" else walk_right_contact) / 100.0
	var contact := _crossed_contact(phase, left) or _crossed_contact(phase, right)
	_previous_step_phase = phase
	if contact: _play_footstep()

func _crossed_contact(phase: float, contact: float) -> bool:
	if phase < _previous_step_phase: # Animation wrapped from its end to its start.
		return contact > _previous_step_phase or contact <= phase
	return contact > _previous_step_phase and contact <= phase

func _play_footstep() -> void:
	if _footstep.stream != footstep_sound:
		_footstep.stream = footstep_sound
	_footstep.volume_db = footstep_volume_db
	_footstep.pitch_scale = 1.0 + _step_random.randf_range(-footstep_pitch_variation, footstep_pitch_variation)
	_footstep.play()

func _on_combo_punch_started(punch_index: int) -> void:
	_pending_punch = punch_index

func update_combo_audio() -> void:
	if _pending_punch < 0: return
	var combat := _player.combat_controller
	if not combat.is_punch_active or combat.combo_punch_index != _pending_punch:
		_pending_punch = -1
		return
	if combat.punch_time < maxf(0.0, punch_sound_delays[_pending_punch]): return
	var index := _pending_punch
	_pending_punch = -1 # Exactly one sound per attack, even when a punch misses.
	if not sounds_enabled or index >= punch_sounds.size() or punch_sounds[index] == null: return
	_punch.stream = punch_sounds[index]
	_punch.volume_db = punch_volume_db
	_punch.play()

func _on_jump_charge_changed(_charge: float, _maximum: float) -> void:
	update_power_audio(0.0)

func update_power_audio(_delta: float) -> void:
	var alive := not _player.is_dead and not _player.is_knocked_out
	var charge := clampf(_player.jump_charge / maxf(_player.max_jump_charge_time, 0.001), 0.0, 1.0)
	var charging := alive and _player.is_charging_jump
	_jump_charge.pitch_scale = lerpf(0.85, 1.65, charge)
	_update_loop(_jump_charge, jump_charge_sound, jump_charge_volume_db,
		lerpf(0.3, 1.0, charge) if charging else 0.0)
	_update_loop(_speed_wind, speed_wind_sound, speed_wind_volume_db,
		_speed_feedback.intensity if alive else 0.0)
	if not sounds_enabled:
		_death.stop()
		_heavy_lift.stop()

func _update_loop(output: AudioStreamPlayer, source: AudioStream, volume: float, gain: float) -> void:
	output.volume_linear = db_to_linear(volume) * gain
	if not sounds_enabled or source == null or gain <= 0.001:
		output.stop()
		return
	if _loop_sources.get(output) != source:
		_loop_sources[output] = source
		var loop := source.duplicate() as AudioStream
		# Copy before configuring: other users of the same resource remain unchanged.
		if loop is AudioStreamWAV:
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		elif loop is AudioStreamOggVorbis or loop is AudioStreamMP3:
			loop.loop = true
			loop.loop_offset = 0.0
		output.stream = loop
	if not output.playing:
		output.play()

func _restart_loop(_output: AudioStreamPlayer) -> void:
	# Re-evaluate current state before restarting a custom stream that finished.
	update_power_audio(0.0)

func _on_vehicle_picked_up(_vehicle: RigidBody3D) -> void:
	if not sounds_enabled or heavy_lift_sound == null or _player.is_dead:
		return
	_heavy_lift.stream = heavy_lift_sound
	_heavy_lift.volume_db = heavy_lift_volume_db
	_heavy_lift.play()

func _on_player_died() -> void:
	_jump_charge.stop()
	_speed_wind.stop()
	_heavy_lift.stop()
	if not sounds_enabled or death_sound == null:
		return
	_death.stream = death_sound
	_death.volume_db = death_volume_db
	_death.play()

func play_heavy_landing() -> void:
	if not sounds_enabled or heavy_landing_sound == null: return
	if _heavy_landing.stream != heavy_landing_sound:
		_heavy_landing.stream = heavy_landing_sound
	_heavy_landing.volume_db = heavy_landing_volume_db
	_heavy_landing.pitch_scale = heavy_landing_pitch
	_heavy_landing.play()

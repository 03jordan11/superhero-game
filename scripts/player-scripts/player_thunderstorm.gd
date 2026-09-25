class_name PlayerThunderstorm
extends Node3D
## Electricity tier 2. The weather autoload owns the storm and session cooldown.
const ARC = preload("res://effects/electric_arc.gd")
const CLIPS: Array[StringName] = [&"Spell_Simple_Enter", &"Spell_Simple_Idle", &"Spell_Simple_Shoot", &"Spell_Simple_Exit"]
@export_range(0.0, 600.0, 1.0, "suffix:s") var cooldown_seconds := 300.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var hold_seconds := 0.35
var casting := false
var elapsed := 0.0
var released := false
var _require_release := true
var _phase := -1
var _durations: Array[float] = []
var _arc: Node3D
var _skeleton: Skeleton3D
var _hand := -1
@onready var player: PlayerCharacter = get_parent()
@onready var weather: Node = get_node("/root/Weather")

func _ready() -> void:
	_arc = ARC.new()
	add_child(_arc)
	process_priority = 12
	player.ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup() -> void:
	var library := AnimationLibrary.new()
	var loader := CharacterAnimationLibraryLoader.new()
	for clip in CLIPS:
		loader.add_animation(library, &"UAL1", clip, clip)
		library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip == &"Spell_Simple_Idle" else Animation.LOOP_NONE
		_durations.append(library.get_animation(clip).length)
	player.character_animation_player.add_animation_library(&"Thunderstorm", library)
	_skeleton = player.laser_eyes._skeleton
	if is_instance_valid(_skeleton): _hand = _skeleton.find_bone("LeftHand")
	player.damage_receiver.damage_received.connect(_on_damage_received)

func unlocked() -> bool:
	return player.get_node("PlayerPowerController").progression.level("electricity") >= 2

func eligible() -> bool:
	return unlocked() and player.get_node("PlayerPowerController").active_power == &"electricity" and not (
		get_tree().paused or get_node("/root/DebugManager").developer_menu_open
		or get_node("/root/GameSettings").input_bindings.is_capturing
		or player.get_node("PlayerPowerController").is_selector_open()
		or player.is_dead or player.is_knocked_out or player.is_dodging
		or player.anticipation.active() or player.is_ground_slamming or player.is_wall_running
		or player.is_charging_jump or player.is_charging_flight or player.is_carrying()
		or player.hostile_grab.owns_animation() or player.ship_interaction.is_attached()
		or player.combat_controller.is_action_locked())

func tick(delta: float, input: PlayerInputSnapshot) -> bool:
	if delta <= 0.0: return casting
	if not input.secondary_power_pressed: _require_release = false
	if casting and not eligible(): cancel()
	if not casting and not _require_release and input.secondary_power_just_pressed:
		_require_release = true
		if eligible() and not weather.is_thunderstorm() and weather.thunderstorm_cooldown_remaining <= 0.0:
			_begin()
	if not casting: return false
	# Keep shared Heat cooling while the cast owns movement and animation.
	player.laser_eyes.update_power(delta, PlayerInputSnapshot.new())
	# An external storm appearing during the windup makes this cast unnecessary.
	if not released and weather.is_thunderstorm():
		cancel()
		return false
	elapsed += delta
	var release_time := _durations[0] + hold_seconds + _durations[2] * 0.5
	if not released and elapsed >= release_time:
		if not weather.summon_thunderstorm(cooldown_seconds):
			cancel()
			return false
		released = true
	var durations: Array[float] = [_durations[0], hold_seconds, _durations[2], _durations[3]]
	var local_time := elapsed
	var phase := 0
	while phase < durations.size() and local_time >= durations[phase]:
		local_time -= durations[phase]
		phase += 1
	if phase == durations.size():
		cancel()
		return false
	if phase != _phase:
		_phase = phase
		player.character_animation_player.play("Thunderstorm/" + String(CLIPS[phase]), 0.08)
		player.character_animation_player.seek(local_time, true)
	# Plant on the ground or hover in flight. An ordinary airborne cast still falls.
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	if player.is_flying:
		player.velocity.y = 0.0
	elif player.is_on_floor():
		player.velocity.y = -0.1
	else:
		player.velocity.y -= player.gravity * delta
	player.move_and_slide()
	player.stamina.finish_tick(delta, Vector3.ZERO, player.is_on_floor())
	return true

func _begin() -> void:
	prepare_cast()
	casting = true
	released = false
	elapsed = 0.0
	_phase = -1

func prepare_cast() -> void:
	# Cancel existing held powers before claiming the shared animation player.
	player.laser_eyes.cancel_input()
	player.anticipation.cancel()
	player.combat_controller.cancel_punch()
	player.flying_state.cancel_charge()
	player.flying_state.surge_remaining = 0.0
	player.flying_state.is_boosting = false
	player.current_flight_speed = 0.0
	if player.is_flying: player.flying_state._publish_flight_speed(true)
	player.bounding_controller.reset()
	player.target_lock.release()
	player.animation_controller.is_hit_reacting = false
	player.animation_controller.is_playing_landing_animation = false
	player.superhero_character.rotation = player.superhero_character_default_rotation
	player.ground_facing_yaw = player.global_rotation.y
	player._apply_ground_facing_visual()

func cancel() -> void:
	if casting and is_instance_valid(player.character_animation_player):
		if String(player.character_animation_player.current_animation).begins_with("Thunderstorm/"):
			player.character_animation_player.stop()
	casting = false
	_require_release = true
	if is_instance_valid(_arc): _arc.hide()

func _on_damage_received(_info) -> void:
	if casting: cancel()

func _process(delta: float) -> void:
	if not casting or not is_instance_valid(_skeleton) or _hand < 0: return
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)
	_arc.draw_arc(hand.origin, hand.origin + Vector3.UP * 0.22, player.camera.global_position, true, delta)

func _exit_tree() -> void:
	cancel()

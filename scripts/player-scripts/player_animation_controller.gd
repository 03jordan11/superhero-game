class_name PlayerAnimationController
extends Node

const PLAYER_FIGHT_STATE_ANIMATION_SOURCES := {
	"Punch_01": "Punch_01",
	"Punch_02": "Punch_02",
	"Punch_03": "Punch_03",
}

const AUTHORED_COMBO_LIBRARY: AnimationLibrary = preload(
	"res://assets/animations/authored-combo/hero_combo.glb"
)
const AUTHORED_COMBO_ANIMATIONS := {
	"Punch_01": "AuthoredCombo/Hero_Cross",
	"Punch_02": "AuthoredCombo/Hero_Hook",
	"Punch_03": "AuthoredCombo/Hero_FlyingUppercut",
}

const PLAYER_KNOCKDOWN_ANIMATION_SOURCES := {
	"Knocked_Down": "Hit_Knockback",
}

const PLAYER_STATE_ANIMATION_SOURCES := {
	"Idle": "Idle",
	"Dodge_Roll": "Roll",
	"Ship_Effort": "Push",
	"Run": "Jog_Fwd",
	"Sprint": "Sprint",
	"Jump_Charge": "Crouch_Idle",
	"Jump_Start": "Jump_Start",
	"Jump_Fall": "Jump",
	"Landing": "Jump_Land",
	"Hit_Chest": "Hit_Chest",
	"Hit_Head": "Hit_Head",
	"Death": "Death01",
}

const FLIGHT_LIBRARY: AnimationLibrary = preload("res://assets/animations/authored-flight/hero_flight.glb")
const FLIGHT_ANIMATIONS := ["Flight_Hover", "Flight_Move", "Flight_Fast"]
const HIT_REACTION_ANIMATIONS := ["Hit_Chest", "Hit_Head"]

@export var animation_blend_time: float = 0.15
@export var flight_animation_blend_time: float = 0.3
## Turn off to compare against the untouched original Punch_01/02/03 clips.
@export var use_authored_combo: bool = false
## Short blend preserves the authored anticipation before the 0.2 second impact.
@export_range(0.0, 0.2, 0.01) var authored_combo_blend_time: float = 0.06

var animation_player: AnimationPlayer
var animation_library_loader := CharacterAnimationLibraryLoader.new()
var was_on_floor: bool = false
var is_playing_landing_animation: bool = false
var is_hit_reacting: bool = false
var is_knocked_down: bool = false
var is_playing_death: bool = false


func setup(target_animation_player: AnimationPlayer, initially_on_floor: bool) -> void:
	animation_player = target_animation_player
	_setup_animation_library()
	was_on_floor = initially_on_floor


func update_animation(
	is_flying: bool,
	is_knocked_out: bool,
	is_dead: bool,
	is_combat_action_active: bool,
	velocity: Vector3,
	is_charging_jump: bool,
	is_on_floor: bool,
	is_sprinting: bool,
	is_flight_moving: bool,
	is_flight_boosting: bool = false
) -> void:
	if animation_player == null or not animation_player.has_animation("Idle"):
		return

	if is_dead:
		if not is_playing_death:
			play_death()
		return

	if is_knocked_out:
		if not is_knocked_down:
			play_knockdown()
		return
	if is_knocked_down:
		is_knocked_down = false
	var player:=get_parent() as PlayerCharacter
	if player != null and player.is_dodging: return
	if player!=null and player.hostile_grab!=null and player.hostile_grab.owns_animation(): return

	if is_hit_reacting:
		if animation_player.is_playing():
			return
		is_hit_reacting = false

	if is_combat_action_active:
		return

	if is_flying:
		is_playing_landing_animation = false
		if is_flight_boosting:
			_play_animation("Flight_Fast")
		elif is_flight_moving:
			_play_animation("Flight_Move")
		else:
			_play_animation("Flight_Hover")
	elif is_charging_jump:
		is_playing_landing_animation = false
		_play_animation("Jump_Charge")
	elif not is_on_floor:
		is_playing_landing_animation = false
		if velocity.y > 0.0:
			_play_animation("Jump_Start")
		else:
			_play_animation("Jump_Fall")
	elif not was_on_floor:
		is_playing_landing_animation = true
		_play_animation("Landing")
	elif is_playing_landing_animation:
		if animation_player.current_animation != "Landing" or not animation_player.is_playing():
			is_playing_landing_animation = false
		else:
			was_on_floor = is_on_floor
			return
	else:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		if horizontal_speed > 0.1:
			_play_animation("Sprint" if is_sprinting else "Run")
		else:
			_play_animation("Idle")

	was_on_floor = is_on_floor


func play_hit_reaction() -> bool:
	if get_parent() is PlayerCharacter and get_parent().is_dodging: return false
	if animation_player == null:
		return false

	var animation_name: String = HIT_REACTION_ANIMATIONS.pick_random()
	if not animation_player.has_animation(animation_name):
		return false

	is_hit_reacting = true
	animation_player.play(animation_name, animation_blend_time)
	animation_player.seek(0.0, true)
	return true


func play_knockdown() -> bool:
	if get_parent() is PlayerCharacter and get_parent().is_dodging: return false
	if animation_player == null or not animation_player.has_animation("Knocked_Down"):
		return false

	is_hit_reacting = false
	is_knocked_down = true
	animation_player.play("Knocked_Down", animation_blend_time)
	animation_player.seek(0.0, true)
	return true


func play_death() -> bool:
	if animation_player == null or not animation_player.has_animation("Death"):
		return false

	is_hit_reacting = false
	is_knocked_down = false
	is_playing_death = true
	animation_player.play("Death", animation_blend_time)
	animation_player.seek(0.0, true)
	return true


func play_combat_animation(animation_name: String) -> bool:
	var use_authored_clip := use_authored_combo and AUTHORED_COMBO_ANIMATIONS.has(animation_name)
	if use_authored_clip:
		animation_name = AUTHORED_COMBO_ANIMATIONS[animation_name]
	if animation_player == null or not animation_player.has_animation(animation_name):
		return false

	is_hit_reacting = false
	is_playing_landing_animation = false
	animation_player.play(
		animation_name,
		authored_combo_blend_time if use_authored_clip else animation_blend_time
	)
	# Repeated attacks must start at the beginning, even if this same clip was
	# paused for a dash, interrupted, or just finished on the previous frame.
	animation_player.seek(0.0, true)
	return true


func is_current_animation_in_final_window(window_duration: float) -> bool:
	if animation_player == null or not animation_player.is_playing():
		return false

	var current_animation := animation_player.get_animation(animation_player.current_animation)
	if current_animation == null:
		return false

	return animation_player.current_animation_position >= current_animation.length - window_duration


func has_current_animation_finished() -> bool:
	return animation_player == null or not animation_player.is_playing()

func _setup_animation_library() -> void:
	var animation_library := AnimationLibrary.new()
	animation_library_loader.add_animations(
		animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		PLAYER_STATE_ANIMATION_SOURCES,
	)
	animation_library_loader.add_animations(
		animation_library,
		CharacterAnimationLibraryLoader.FIGHTING_GROUP,
		PLAYER_FIGHT_STATE_ANIMATION_SOURCES,
	)
	animation_library_loader.add_animations(
		animation_library,
		CharacterAnimationLibraryLoader.UAL2_GROUP,
		PLAYER_KNOCKDOWN_ANIMATION_SOURCES,
	)
	for name in FLIGHT_ANIMATIONS:
		var clip := FLIGHT_LIBRARY.get_animation(name).duplicate() as Animation
		clip.loop_mode = Animation.LOOP_LINEAR
		animation_library.add_animation(name, clip)
	animation_library.get_animation("Ship_Effort").loop_mode = Animation.LOOP_LINEAR
	animation_library.get_animation("Dodge_Roll").loop_mode = Animation.LOOP_NONE
	animation_player.add_animation_library("", animation_library)
	animation_player.add_animation_library("AuthoredCombo", AUTHORED_COMBO_LIBRARY)
	animation_player.play("Idle")


func _play_animation(animation_name: String) -> void:
	if animation_player.current_animation != animation_name:
		var current_animation := animation_player.current_animation
		if animation_name in FLIGHT_ANIMATIONS or current_animation in FLIGHT_ANIMATIONS:
			animation_player.play(animation_name, flight_animation_blend_time)
		else:
			animation_player.play(animation_name, animation_blend_time)

class_name PlayerAnimationController
extends Node

const UAL_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/UAL1_Standard.glb")
const FLYING_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/Flying.fbx")
const FIGHTING_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/fight-animations/Fighting.glb")

const FIGHT_ANIMATION_SOURCES := {
	"Punch_01": "Punch_01"
}

const ANIMATION_SOURCES := {
	"Idle": "Idle",
	"Run": "Jog_Fwd",
	"Sprint": "Sprint",
	"Jump_Charge": "Crouch_Idle",
	"Jump_Start": "Jump_Start",
	"Jump_Fall": "Jump",
	"Landing": "Jump_Land",
	"Flight_Hover": "Swim_Idle",
}

const FLIGHT_ANIMATIONS := ["Flying", "Flight_Hover"]

const MIXAMO_TO_SUPERHERO_BONES := {
	"mixamorig1_Hips": "Hips",
	"mixamorig1_Spine": "Spine",
	"mixamorig1_Spine1": "Chest",
	"mixamorig1_Spine2": "UpperChest",
	"mixamorig1_Neck": "Neck",
	"mixamorig1_Head": "Head",
	"mixamorig1_LeftShoulder": "LeftShoulder",
	"mixamorig1_LeftArm": "LeftUpperArm",
	"mixamorig1_LeftForeArm": "LeftLowerArm",
	"mixamorig1_LeftHand": "LeftHand",
	"mixamorig1_LeftHandThumb1": "LeftThumbMetacarpal",
	"mixamorig1_LeftHandThumb2": "LeftThumbProximal",
	"mixamorig1_LeftHandThumb3": "LeftThumbDistal",
	"mixamorig1_LeftHandThumb4": "thumb_04_leaf_l",
	"mixamorig1_LeftHandIndex1": "LeftIndexProximal",
	"mixamorig1_LeftHandIndex2": "LeftIndexIntermediate",
	"mixamorig1_LeftHandIndex3": "LeftIndexDistal",
	"mixamorig1_LeftHandIndex4": "index_04_leaf_l",
	"mixamorig1_LeftHandMiddle1": "LeftMiddleProximal",
	"mixamorig1_LeftHandMiddle2": "LeftMiddleIntermediate",
	"mixamorig1_LeftHandMiddle3": "LeftMiddleDistal",
	"mixamorig1_LeftHandMiddle4": "middle_04_leaf_l",
	"mixamorig1_LeftHandRing1": "LeftRingProximal",
	"mixamorig1_LeftHandRing2": "LeftRingIntermediate",
	"mixamorig1_LeftHandRing3": "LeftRingDistal",
	"mixamorig1_LeftHandRing4": "ring_04_leaf_l",
	"mixamorig1_LeftHandPinky1": "LeftLittleProximal",
	"mixamorig1_LeftHandPinky2": "LeftLittleIntermediate",
	"mixamorig1_LeftHandPinky3": "LeftLittleDistal",
	"mixamorig1_LeftHandPinky4": "pinky_04_leaf_l",
	"mixamorig1_RightShoulder": "RightShoulder",
	"mixamorig1_RightArm": "RightUpperArm",
	"mixamorig1_RightForeArm": "RightLowerArm",
	"mixamorig1_RightHand": "RightHand",
	"mixamorig1_RightHandThumb1": "RightThumbMetacarpal",
	"mixamorig1_RightHandThumb2": "RightThumbProximal",
	"mixamorig1_RightHandThumb3": "RightThumbDistal",
	"mixamorig1_RightHandThumb4": "thumb_04_leaf_r",
	"mixamorig1_RightHandIndex1": "RightIndexProximal",
	"mixamorig1_RightHandIndex2": "RightIndexIntermediate",
	"mixamorig1_RightHandIndex3": "RightIndexDistal",
	"mixamorig1_RightHandIndex4": "index_04_leaf_r",
	"mixamorig1_RightHandMiddle1": "RightMiddleProximal",
	"mixamorig1_RightHandMiddle2": "RightMiddleIntermediate",
	"mixamorig1_RightHandMiddle3": "RightMiddleDistal",
	"mixamorig1_RightHandMiddle4": "middle_04_leaf_r",
	"mixamorig1_RightHandRing1": "RightRingProximal",
	"mixamorig1_RightHandRing2": "RightRingIntermediate",
	"mixamorig1_RightHandRing3": "RightRingDistal",
	"mixamorig1_RightHandRing4": "ring_04_leaf_r",
	"mixamorig1_RightHandPinky1": "RightLittleProximal",
	"mixamorig1_RightHandPinky2": "RightLittleIntermediate",
	"mixamorig1_RightHandPinky3": "RightLittleDistal",
	"mixamorig1_RightHandPinky4": "pinky_04_leaf_r",
	"mixamorig1_LeftUpLeg": "LeftUpperLeg",
	"mixamorig1_LeftLeg": "LeftLowerLeg",
	"mixamorig1_LeftFoot": "LeftFoot",
	"mixamorig1_LeftToeBase": "LeftToes",
	"mixamorig1_LeftToe_End": "ball_leaf_l",
	"mixamorig1_RightUpLeg": "RightUpperLeg",
	"mixamorig1_RightLeg": "RightLowerLeg",
	"mixamorig1_RightFoot": "RightFoot",
	"mixamorig1_RightToeBase": "RightToes",
	"mixamorig1_RightToe_End": "ball_leaf_r",
}

@export var animation_blend_time: float = 0.15
@export var flight_animation_blend_time: float = 0.3

var animation_player: AnimationPlayer
var was_on_floor: bool = false
var is_playing_landing_animation: bool = false
var is_fighting: bool = false


func setup(target_animation_player: AnimationPlayer, initially_on_floor: bool) -> void:
	animation_player = target_animation_player
	_setup_animation_library()
	was_on_floor = initially_on_floor


func update_animation(
	is_flying: bool,
	velocity: Vector3,
	is_charging_jump: bool,
	is_on_floor: bool,
	is_sprinting: bool,
	is_flight_forward_pressed: bool
) -> void:
	if animation_player == null or not animation_player.has_animation("Idle"):
		return
		
	if is_fighting:
		if animation_player.is_playing():
			return
		is_fighting = false

	if is_flying:
		is_playing_landing_animation = false
		if not is_flight_forward_pressed and animation_player.has_animation("Flight_Hover"):
			_play_animation("Flight_Hover")
		elif animation_player.has_animation("Flying"):
			_play_animation("Flying")
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

func play_fighting_animation(animation_name: String) -> bool:
	if is_fighting:
		return false
		
	if animation_player == null or not animation_player.has_animation(animation_name):
		return false
	
	is_fighting = true
	animation_player.play(animation_name, animation_blend_time)
	return true

func _setup_animation_library() -> void:
	var animation_library := AnimationLibrary.new()
	_add_animations_from_library(animation_library, UAL_ANIMATION_LIBRARY, ANIMATION_SOURCES, "UAL1")
	_add_animations_from_library(animation_library, FIGHTING_ANIMATION_LIBRARY, FIGHT_ANIMATION_SOURCES, "Punch_01")

	_add_flying_animation(animation_library)
	animation_player.add_animation_library("", animation_library)
	animation_player.play("Idle")


func _add_animations_from_library(
	animation_library: AnimationLibrary,
	source_library: AnimationLibrary,
	animation_sources: Dictionary,
	source_label: String
) -> void:
	for target_name in animation_sources:
		var source_name: String = animation_sources[target_name]
		var animation := source_library.get_animation(source_name)
		if animation == null:
			push_error("Missing %s animation: %s" % [source_label, source_name])
			continue
		animation_library.add_animation(target_name, animation.duplicate())


func _play_animation(animation_name: String) -> void:
	if animation_player.current_animation != animation_name:
		var current_animation := animation_player.current_animation
		if animation_name in FLIGHT_ANIMATIONS or current_animation in FLIGHT_ANIMATIONS:
			animation_player.play(animation_name, flight_animation_blend_time)
		else:
			animation_player.play(animation_name, animation_blend_time)


func _add_flying_animation(animation_library: AnimationLibrary) -> void:
	var flying_animation := FLYING_ANIMATION_LIBRARY.get_animation("mixamo_com")
	if flying_animation == null:
		push_error("Flying animation library has no mixamo_com animation.")
		return

	var retargeted_animation := flying_animation.duplicate() as Animation
	retargeted_animation.loop_mode = Animation.LOOP_LINEAR
	for track_index in range(retargeted_animation.get_track_count() - 1, -1, -1):
		var track_path := str(retargeted_animation.track_get_path(track_index))
		var path_parts := track_path.split(":")
		if path_parts.size() != 2 or not MIXAMO_TO_SUPERHERO_BONES.has(path_parts[1]):
			retargeted_animation.remove_track(track_index)
			continue

		if path_parts[1] == "mixamorig1_Hips" and (
			retargeted_animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D
		):
			retargeted_animation.remove_track(track_index)
			continue

		var target_bone: String = MIXAMO_TO_SUPERHERO_BONES[path_parts[1]]
		retargeted_animation.track_set_path(
			track_index,
			NodePath("%%GeneralSkeleton:%s" % target_bone)
		)

	animation_library.add_animation("Flying", retargeted_animation)

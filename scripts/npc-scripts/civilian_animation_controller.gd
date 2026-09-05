class_name CivilianAnimationController
extends Node

static var cached_animation_library: AnimationLibrary
static var has_built_cached_animation_library: bool = false

@onready var animation_player: AnimationPlayer = $"../Superhero_Female_FullBody/CharacterAnimationPlayer"


func _ready() -> void:
	# UAL tracks address the skeleton as Armature/Skeleton3D. Resolve those paths
	# from the imported model root, which is the AnimationPlayer's parent.
	animation_player.root_node = NodePath("..")

	var civilian_animation_library := _get_cached_animation_library()
	if civilian_animation_library == null:
		return

	animation_player.add_animation_library("", civilian_animation_library)
	animation_player.play("Idle")


static func _get_cached_animation_library() -> AnimationLibrary:
	if has_built_cached_animation_library:
		return cached_animation_library

	has_built_cached_animation_library = true
	var animation_library_loader := CharacterAnimationLibraryLoader.new()
	var civilian_animation_library := AnimationLibrary.new()
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Idle",
		&"Idle"
	):
		return null
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Walk",
		&"Walk"
	):
		return null
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Sprint",
		&"Run"
	):
		return null
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Hit_Chest",
		&"Hit_Chest"
	):
		return null
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Death01",
		&"Death01"
	):
		return null
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL2_GROUP,
		&"Hit_Knockback",
		&"Hit_Knockback"
	):
		return null
	# This project does not currently include Hit_Knockback_RM, so ground slams
	# use the available UAL2 knockback clip until that asset is added.
	if not animation_library_loader.add_animation(
		civilian_animation_library,
		CharacterAnimationLibraryLoader.UAL2_GROUP,
		&"Hit_Knockback",
		&"Hit_Knockback_RM"
	):
		return null

	cached_animation_library = civilian_animation_library
	return cached_animation_library


func set_is_walking(should_walk: bool) -> void:
	var target_animation := "Walk" if should_walk else "Idle"
	if animation_player.current_animation != target_animation:
		animation_player.play(target_animation, 0.15)


func set_is_fleeing() -> void:
	if animation_player.current_animation != "Run":
		animation_player.play("Run", 0.15)


func play_hit() -> void:
	_play_reaction(&"Hit_Chest")


func play_death() -> void:
	_play_reaction(&"Death01")


func play_knockback() -> void:
	_play_reaction(&"Hit_Knockback")


func play_ground_slam_knockback() -> void:
	# UAL2 has no separate root-motion version in this project yet.
	_play_reaction(&"Hit_Knockback_RM")


func is_hit_playing() -> bool:
	return (
		animation_player.current_animation in [
			"Hit_Chest",
			"Hit_Knockback",
			"Hit_Knockback_RM"
		]
		and animation_player.is_playing()
	)


func is_chest_hit_animation_playing() -> bool:
	return animation_player.current_animation == "Hit_Chest" and animation_player.is_playing()


func _play_reaction(animation_name: StringName) -> void:
	if not animation_player.has_animation(animation_name):
		push_error("Civilian reaction animation is not registered: %s" % animation_name)
		return

	# Reactions must take over immediately. Starting slightly into the clip also
	# applies its first visible pose instead of leaving the prior walk pose on
	# screen during a transition blend.
	animation_player.play(animation_name)
	animation_player.seek(0.05, true)
	print(
		"Civilian reaction requested: %s | current: %s | playing: %s" % [
			animation_name,
			animation_player.current_animation,
			animation_player.is_playing()
		]
	)

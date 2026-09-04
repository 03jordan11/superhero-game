class_name HostileAnimationController
extends Node

signal pistol_reload_finished

static var cached_animation_library: AnimationLibrary
static var has_built_cached_animation_library: bool = false

@onready var animation_player: AnimationPlayer = (
	$"../Superhero_Male_FullBody/CharacterAnimationPlayer"
)


func _ready() -> void:
	animation_player.root_node = NodePath("..")

	var hostile_animation_library := _get_cached_animation_library()
	if hostile_animation_library == null:
		return

	animation_player.add_animation_library("", hostile_animation_library)
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("Idle")


static func _get_cached_animation_library() -> AnimationLibrary:
	if has_built_cached_animation_library:
		return cached_animation_library

	has_built_cached_animation_library = true
	var animation_library_loader := CharacterAnimationLibraryLoader.new()
	var hostile_animation_library := AnimationLibrary.new()
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Idle",
		&"Idle"
	):
		return null
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Sprint",
		&"Sprint"
	):
		return null
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Pistol_Shoot",
		&"Pistol_Shoot"
	):
		return null
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Pistol_Reload",
		&"Pistol_Reload"
	):
		return null
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Hit_Chest",
		&"Hit_Chest"
	):
		return null
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL1_GROUP,
		&"Death01",
		&"Death01"
	):
		return null
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL2_GROUP,
		&"Hit_Knockback",
		&"Hit_Knockback"
	):
		return null
	# The project has no separate root-motion knockback clip yet.
	if not animation_library_loader.add_animation(
		hostile_animation_library,
		CharacterAnimationLibraryLoader.UAL2_GROUP,
		&"Hit_Knockback",
		&"Hit_Knockback_RM"
	):
		return null

	cached_animation_library = hostile_animation_library
	return cached_animation_library


func set_is_idle() -> void:
	if animation_player.current_animation != "Idle":
		animation_player.play("Idle", 0.15)


func set_is_running() -> void:
	if animation_player.current_animation != "Sprint":
		animation_player.play("Sprint", 0.15)


func play_pistol_shot() -> void:
	animation_player.play("Pistol_Shoot", 0.1)


func play_pistol_reload() -> void:
	if not is_pistol_reloading():
		animation_player.play("Pistol_Reload", 0.1)


func is_pistol_shooting() -> bool:
	return animation_player.current_animation == "Pistol_Shoot" and animation_player.is_playing()


func is_pistol_reloading() -> bool:
	return animation_player.current_animation == "Pistol_Reload" and animation_player.is_playing()


func play_hit() -> void:
	_play_reaction(&"Hit_Chest")


func play_death() -> void:
	_play_reaction(&"Death01")


func play_knockback() -> void:
	_play_reaction(&"Hit_Knockback")


func play_ground_slam_knockback() -> void:
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
		push_error("Hostile reaction animation is not registered: %s" % animation_name)
		return

	animation_player.play(animation_name)
	animation_player.seek(0.05, true)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Pistol_Reload":
		pistol_reload_finished.emit()

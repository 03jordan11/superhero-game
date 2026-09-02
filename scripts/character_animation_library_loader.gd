class_name CharacterAnimationLibraryLoader
extends RefCounted

const UAL1_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/UAL1_Standard.glb")
const UAL2_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/UAL2_Standard.glb")
const FLYING_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/Flying.fbx")
const FIGHTING_ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/fight-animations/fighting_animations.glb")

const UAL1_GROUP: StringName = &"UAL1"
const UAL2_GROUP: StringName = &"UAL2"
const FLYING_GROUP: StringName = &"Flying"
const FIGHTING_GROUP: StringName = &"Fighting"

const UAL1_ANIMATION_SOURCES := {
	"A_TPose": "A_TPose",
	"Crouch_Fwd": "Crouch_Fwd",
	"Crouch_Idle": "Crouch_Idle",
	"Dance": "Dance",
	"Death01": "Death01",
	"Driving": "Driving",
	"Fixing_Kneeling": "Fixing_Kneeling",
	"Hit_Chest": "Hit_Chest",
	"Hit_Head": "Hit_Head",
	"Idle": "Idle",
	"Idle_Talking": "Idle_Talking",
	"Idle_Torch": "Idle_Torch",
	"Interact": "Interact",
	"Jog_Fwd": "Jog_Fwd",
	"Jump": "Jump",
	"Jump_Land": "Jump_Land",
	"Jump_Start": "Jump_Start",
	"PickUp_Table": "PickUp_Table",
	"Pistol_Aim_Down": "Pistol_Aim_Down",
	"Pistol_Aim_Neutral": "Pistol_Aim_Neutral",
	"Pistol_Aim_Up": "Pistol_Aim_Up",
	"Pistol_Idle": "Pistol_Idle",
	"Pistol_Reload": "Pistol_Reload",
	"Pistol_Shoot": "Pistol_Shoot",
	"Punch_Cross": "Punch_Cross",
	"Punch_Jab": "Punch_Jab",
	"Push": "Push",
	"Roll": "Roll",
	"Sitting_Enter": "Sitting_Enter",
	"Sitting_Exit": "Sitting_Exit",
	"Sitting_Idle": "Sitting_Idle",
	"Sitting_Talking": "Sitting_Talking",
	"Spell_Simple_Enter": "Spell_Simple_Enter",
	"Spell_Simple_Exit": "Spell_Simple_Exit",
	"Spell_Simple_Idle": "Spell_Simple_Idle",
	"Spell_Simple_Shoot": "Spell_Simple_Shoot",
	"Sprint": "Sprint",
	"Swim_Fwd": "Swim_Fwd",
	"Swim_Idle": "Swim_Idle",
	"Sword_Attack": "Sword_Attack",
	"Sword_Idle": "Sword_Idle",
	"Walk": "Walk",
	"Walk_Formal": "Walk_Formal"
}

const UAL2_ANIMATION_SOURCES := {
	"A_TPose": "A_TPose",
	"Chest_Open": "Chest_Open",
	"ClimbUp_1m": "ClimbUp_1m",
	"Consume": "Consume",
	"Farm_Harvest": "Farm_Harvest",
	"Farm_PlantSeed": "Farm_PlantSeed",
	"Farm_Watering": "Farm_Watering",
	"Hit_Knockback": "Hit_Knockback",
	"Idle_FoldArms": "Idle_FoldArms",
	"Idle_Lantern": "Idle_Lantern",
	"Idle_No": "Idle_No",
	"Idle_Rail_Call": "Idle_Rail_Call",
	"Idle_Rail": "Idle_Rail",
	"Idle_Shield_Break": "Idle_Shield_Break",
	"Idle_Shield": "Idle_Shield",
	"Idle_TalkingPhone": "Idle_TalkingPhone",
	"LayToIdle": "LayToIdle",
	"Melee_Hook": "Melee_Hook",
	"Melee_Hook_Rec": "Melee_Hook_Rec",
	"NinjaJump_Idle": "NinjaJump_Idle",
	"NinjaJump_Land": "NinjaJump_Land",
	"NinjaJump_Start": "NinjaJump_Start",
	"OverhandThrow": "OverhandThrow",
	"Shield_Dash": "Shield_Dash",
	"Shield_OneShot": "Shield_OneShot",
	"Slide": "Slide",
	"Slide_Exit": "Slide_Exit",
	"Slide_Start": "Slide_Start",
	"Sword_Block": "Sword_Block",
	"Sword_Dash": "Sword_Dash",
	"Sword_Heavy_Combo": "Sword_Heavy_Combo",
	"Sword_Regular_A": "Sword_Regular_A",
	"Sword_Regular_A_Rec": "Sword_Regular_A_Rec",
	"Sword_Regular_B": "Sword_Regular_B",
	"Sword_Regular_B_Rec": "Sword_Regular_B_Rec",
	"Sword_Regular_C": "Sword_Regular_C",
	"Sword_Regular_Combo": "Sword_Regular_Combo",
	"TreeChopping": "TreeChopping",
	"Walk_Carry": "Walk_Carry",
	"Yes": "Yes",
	"Zombie_Idle": "Zombie_Idle",
	"Zombie_Scratch": "Zombie_Scratch",
	"Zombie_Walk_Fwd": "Zombie_Walk_Fwd"
}

const FLYING_ANIMATION_SOURCES := {
	"mixamo_com": "mixamo_com"
}

const FIGHTING_ANIMATION_SOURCES := {
	"Punch_01": "Punch_01",
	"Punch_02": "Punch_02",
	"Punch_03": "Punch_03"
}

const ANIMATION_CATALOGS := {
	UAL1_GROUP: UAL1_ANIMATION_SOURCES,
	UAL2_GROUP: UAL2_ANIMATION_SOURCES,
	FLYING_GROUP: FLYING_ANIMATION_SOURCES,
	FIGHTING_GROUP: FIGHTING_ANIMATION_SOURCES
}


func _init() -> void:
	_validate_animation_catalogs()


func load_all_animations(
	target_animation_player: AnimationPlayer,
	animation_groups: Array[StringName]
) -> void:
	for animation_group in animation_groups:
		var source_library := _get_source_library(animation_group)
		if source_library == null:
			continue

		var catalog: Dictionary = ANIMATION_CATALOGS.get(animation_group, {})
		var target_library := AnimationLibrary.new()
		for animation_name in catalog:
			var target_animation_name: StringName = animation_name
			var source_animation_name: StringName = catalog[animation_name]
			add_animation(
				target_library,
				animation_group,
				source_animation_name,
				target_animation_name
			)
		target_animation_player.add_animation_library(animation_group, target_library)


func add_animation(
	target_library: AnimationLibrary,
	animation_group: StringName,
	source_name: StringName,
	target_name: StringName
) -> bool:
	var source_library := _get_source_library(animation_group)
	var catalog: Dictionary = ANIMATION_CATALOGS.get(animation_group, {})
	var source_name_key := String(source_name)
	if (
		source_library == null
		or not catalog.has(source_name_key)
		or not source_library.has_animation(source_name)
	):
		push_error("Missing %s animation: %s" % [animation_group, source_name])
		return false

	var animation: Animation = source_library.get_animation(source_name)
	if animation == null:
		push_error("Failed to load %s animation: %s" % [animation_group, source_name])
		return false

	target_library.add_animation(target_name, animation.duplicate())
	return true


func add_animations(
	target_library: AnimationLibrary,
	animation_group: StringName,
	animation_sources: Dictionary,
) -> void:
	for target_name in animation_sources:
		var target_animation_name: StringName = target_name
		var source_name: StringName = animation_sources[target_name]
		add_animation(
			target_library,
			animation_group,
			source_name,
			target_animation_name
		)


func get_animation(animation_group: StringName, animation_name: StringName) -> Animation:
	var source_library := _get_source_library(animation_group)
	var catalog: Dictionary = ANIMATION_CATALOGS.get(animation_group, {})
	var animation_name_key := String(animation_name)
	if (
		source_library == null
		or not catalog.has(animation_name_key)
		or not source_library.has_animation(animation_name)
	):
		push_error("Missing %s animation: %s" % [animation_group, animation_name])
		return null
	return source_library.get_animation(animation_name)


func _validate_animation_catalogs() -> void:
	for animation_group in ANIMATION_CATALOGS:
		var source_library := _get_source_library(animation_group)
		if source_library == null:
			continue

		var catalog: Dictionary = ANIMATION_CATALOGS[animation_group]
		for animation_name in source_library.get_animation_list():
			if not catalog.has(animation_name):
				push_warning(
					"%s has an uncataloged animation: %s" % [animation_group, animation_name]
				)
		for animation_name in catalog:
			var source_animation_name: StringName = catalog[animation_name]
			if not source_library.has_animation(source_animation_name):
				push_warning(
					"%s catalog references a missing animation: %s" % [
						animation_group,
						source_animation_name
					]
				)


func _get_source_library(animation_group: StringName) -> AnimationLibrary:
	match animation_group:
		UAL1_GROUP:
			return UAL1_ANIMATION_LIBRARY
		UAL2_GROUP:
			return UAL2_ANIMATION_LIBRARY
		FLYING_GROUP:
			return FLYING_ANIMATION_LIBRARY
		FIGHTING_GROUP:
			return FIGHTING_ANIMATION_LIBRARY
		_:
			return null

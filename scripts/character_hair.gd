class_name CharacterHair
extends Node
## Rigid accessories follow the existing Head bone; source assets stay shared.
const FEMALE_STYLES: Array[PackedScene] = [
	preload("res://assets/characters/Superhero-female/Hairstyles/Hair_Long.gltf"),
	preload("res://assets/characters/Superhero-female/Hairstyles/Hair_Buns.gltf"),
	preload("res://assets/characters/Superhero-female/Hairstyles/Hair_BuzzedFemale.gltf"),
]
const PLAYER_STYLES: Array[PackedScene] = [
	preload("res://assets/characters/Superhero-male/Hairstyles/Hair_SimpleParted.gltf"),
	preload("res://assets/characters/Superhero-male/Hairstyles/Hair_Beard.gltf"),
]
const FITTING_SCENE: PackedScene = preload("res://scenes/tests/hair_fitting.tscn")
static var _fitting_adjustments: Dictionary = {}
const COLOR_NAMES := ["Blonde", "Black", "Brown", "Grey"]
const COLORS := [Color("f5cc82"), Color("191714"), Color("704629"), Color("c6c9cc")]
@export var model_path: NodePath
## Models with integrated hair do not need a separate accessory shell.
@export var enabled := true
@export var female_npc := true
@export_range(0, 3, 1) var player_color := 2
static var _materials: Dictionary = {}
static var _random := RandomNumberGenerator.new()
static var _random_initialized := false
var attachment: BoneAttachment3D
var style_index := -1
var color_index := -1
var _model: Node3D
var _skeleton: Skeleton3D

static func choose_for(actor: Node) -> void:
	if not _random_initialized:
		_random.randomize()
		_random_initialized = true
	if actor.hair_style_index < 0: actor.hair_style_index = _random.randi_range(0, FEMALE_STYLES.size() - 1)
	if actor.hair_color_index < 0: actor.hair_color_index = _random.randi_range(0, COLORS.size() - 1)

func _ready() -> void:
	if not enabled: return
	_model = get_node(model_path) as Node3D
	for skeleton in _model.find_children("*", "Skeleton3D", true, false):
		if skeleton.find_bone("Head") >= 0:
			_skeleton = skeleton
			break
	if _skeleton == null:
		push_error("Hair requires a Head bone: " + str(_model.get_path()))
		return
	attachment = BoneAttachment3D.new()
	attachment.name = "HairstyleAttachment"
	attachment.bone_name = "Head"
	_skeleton.add_child(attachment)
	refresh()

func refresh() -> void:
	if attachment == null: return
	if female_npc:
		choose_for(get_parent())
		style_index = clampi(get_parent().hair_style_index, 0, FEMALE_STYLES.size() - 1)
		color_index = clampi(get_parent().hair_color_index, 0, COLORS.size() - 1)
	else:
		style_index = 0
		color_index = clampi(player_color, 0, COLORS.size() - 1)
	for child in attachment.get_children(): child.free()
	var styles: Array = [FEMALE_STYLES[style_index]] if female_npc else PLAYER_STYLES
	# glTF meshes use character-origin coordinates, not head-local coordinates.
	var head := _skeleton.find_bone("Head")
	var offset := _skeleton.get_bone_global_rest(head).affine_inverse() * _skeleton.global_transform.affine_inverse() * _model.global_transform
	for packed in styles:
		var hair := packed.instantiate() as Node3D
		hair.transform = offset * fitting_adjustment(packed.resource_path) * hair.transform
		attachment.add_child(hair)
		_tint_tree(hair)
	# Eyebrows are already part of both original characters.
	for mesh in _model.find_children("Eyebrows", "MeshInstance3D", true, false): _tint_mesh(mesh)

func _tint_tree(node: Node3D) -> void:
	if node is MeshInstance3D: _tint_mesh(node)
	for mesh in node.find_children("*", "MeshInstance3D", true, false): _tint_mesh(mesh)

func _tint_mesh(mesh: MeshInstance3D) -> void:
	for surface in mesh.mesh.get_surface_count():
		var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if original == null: continue
		var key := "%s:%d" % [original.get_rid().get_id(), color_index]
		if not _materials.has(key):
			var material := original.duplicate() as StandardMaterial3D
			material.albedo_color = COLORS[color_index]
			material.roughness = 0.85
			_materials[key] = material
		mesh.set_surface_override_material(surface, _materials[key])

static func fitting_adjustment(asset_path: String) -> Transform3D:
	if _fitting_adjustments.is_empty():
		_fitting_adjustments = read_fitting_adjustments(FITTING_SCENE.get_state())
	return _fitting_adjustments.get(asset_path, Transform3D.IDENTITY)

static func read_fitting_adjustments(state: SceneState) -> Dictionary:
	# Read only saved adjustment data; never instantiate the fitting studio in-game.
	var result := {}
	for node_index in state.get_node_count():
		var asset := ""
		var adjusted := Transform3D.IDENTITY
		var neutral := Transform3D.IDENTITY
		for property_index in state.get_node_property_count(node_index):
			var property := state.get_node_property_name(node_index, property_index)
			var value: Variant = state.get_node_property_value(node_index, property_index)
			match property:
				&"metadata/hair_asset": asset = value
				&"metadata/neutral_transform": neutral = value
				&"transform": adjusted = value
		if not asset.is_empty(): result[asset] = adjusted * neutral.affine_inverse()
	return result

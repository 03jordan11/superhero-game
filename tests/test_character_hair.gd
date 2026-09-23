extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func check_hair_geometry() -> void:
	# Check imported geometry, not just the import checkbox: coarse hair LODs
	# collapse through the scalp at normal third-person viewing distances.
	var styles: Array[PackedScene] = []
	styles.append_array(CharacterHair.PLAYER_STYLES)
	styles.append_array(CharacterHair.FEMALE_STYLES)
	for packed in styles:
		var model := packed.instantiate()
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "Hairstyle contains geometry: " + packed.resource_path)
		for instance: MeshInstance3D in meshes:
			var surfaces: Array = instance.mesh.get("_surfaces")
			for surface: Dictionary in surfaces:
				check(surface.get("lods", []).is_empty(), "Hair preserves its fitted shape at a distance: " + packed.resource_path)
		model.free()

func run() -> void:
	check_hair_geometry()
	CharacterHair._random.seed = 492
	CharacterHair._random_initialized = true
	var world := Node3D.new()
	root.add_child(world)
	var choices := {}
	var actor_script = load("res://scripts/npc-scripts/capsule_civilian.gd")
	for i in 100:
		var walker := actor_script.new() as Node3D
		CharacterHair.choose_for(walker)
		var selection := Vector2i(walker.hair_style_index, walker.hair_color_index)
		choices[selection] = true
		CharacterHair.choose_for(walker)
		check(selection == Vector2i(walker.hair_style_index, walker.hair_color_index), "Selection stays stable")
		walker.free()
	check(choices.size() == 12, "Random selection covers all three styles and four colors")
	for style in 3:
		for color in 4:
			# Legacy accessories still work on their original body; current civilians
			# use the integrated Meshy hair, checked in test_civilian_meshy.gd.
			var npc = load("res://tests/fixtures/civilian_legacy_benchmark.tscn").instantiate()
			npc.hair_style_index = style
			npc.hair_color_index = color
			world.add_child(npc)
			npc.set_physics_process(false)
			var hair: CharacterHair = npc.get_node("CharacterHair")
			check(hair.attachment.get_child_count() == 1 and hair.style_index == style and hair.color_index == color, "Female NPC gets its requested style and color")
			check(npc.find_children("*", "Skeleton3D", true, false).size() == 1, "Hair does not add another skeleton")
			var before: Transform3D = hair.attachment.get_child(0).global_transform
			var head := hair._skeleton.find_bone("Head")
			hair._skeleton.set_bone_pose_rotation(head, Quaternion(Vector3.UP, 0.45))
			hair._skeleton.force_update_all_bone_transforms()
			hair.attachment.on_skeleton_update()
			check(not before.is_equal_approx(hair.attachment.get_child(0).global_transform), "Hairstyle follows head rotation")
			var eyebrows := hair._model.find_children("Eyebrows", "MeshInstance3D", true, false)[0] as MeshInstance3D
			check(eyebrows.get_active_material(0).albedo_color == CharacterHair.COLORS[color], "Eyebrows match hair color")
			check(eyebrows.mesh.surface_get_material(0) != eyebrows.get_active_material(0), "Original shared material is untouched")
			npc.free()
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	var player_hair: CharacterHair = player.get_node("CharacterHair")
	check(not player_hair.enabled and player_hair.attachment == null, "Meshy player uses integrated hair without accessory shells")
	check(player.superhero_character.find_children("*", "MeshInstance3D", true, false).size() == 1, "Player body, fro and beard share one skinned mesh")
	world.free()
	print("CHARACTER_HAIR_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

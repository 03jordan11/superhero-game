extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var studio := CharacterHair.FITTING_SCENE.instantiate()
	root.add_child(studio)
	var expected := {}
	var index := 0
	for station in studio.get_node("Models").get_children():
		var adjustment: Node3D = station.get_node("HairAdjustment")
		check(station.has_node("ReferenceBody") and adjustment.has_node("HairMesh"), "Each station exposes reference body and editable hair")
		var asset: String = adjustment.get_meta("hair_asset")
		var neutral: Transform3D = adjustment.get_meta("neutral_transform")
		adjustment.transform = Transform3D(Basis(Vector3.UP, 0.08 * (index + 1)).scaled(Vector3(1.05, 1.03, 1.02)), neutral.origin + Vector3(0.01,0.035,-0.015))
		expected[asset] = adjustment.transform * neutral.affine_inverse()
		station.position += Vector3(20, 4, 7)
		index += 1
	check(index == 5, "Five separate hairstyle fitting stations")
	var saved := PackedScene.new()
	check(saved.pack(studio) == OK, "Edited transforms pack successfully")
	var path := "res://artifacts/hair_fit_save_test.tscn"
	check(ResourceSaver.save(saved, path) == OK, "Edited scene saves")
	var reloaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var adjustments := CharacterHair.read_fitting_adjustments(reloaded.get_state())
	check(adjustments.size() == 5, "Read five saved per-style adjustments")
	for asset in expected:
		check(adjustments[asset].is_equal_approx(expected[asset]), "Saved translation, rotation and scale survive; station placement is ignored")
	CharacterHair._fitting_adjustments = adjustments
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var hair: CharacterHair = player.get_node("CharacterHair")
	var head := hair._skeleton.find_bone("Head")
	var offset := hair._skeleton.get_bone_global_rest(head).affine_inverse() * hair._skeleton.global_transform.affine_inverse() * hair._model.global_transform
	for i in CharacterHair.PLAYER_STYLES.size():
		var packed: PackedScene = CharacterHair.PLAYER_STYLES[i]
		var raw := packed.instantiate() as Node3D
		check(hair.attachment.get_child(i).transform.is_equal_approx(offset * expected[packed.resource_path] * raw.transform), "Gameplay applies the saved fit before bone attachment")
		raw.free()
	player.free()
	studio.free()
	CharacterHair._fitting_adjustments.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HAIR_FITTING_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

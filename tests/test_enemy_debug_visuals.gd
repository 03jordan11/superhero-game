extends SceneTree

var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var debug := root.get_node("DebugManager")
	var enemies: Array[HostileBase] = []
	var original_overlay := StandardMaterial3D.new()
	original_overlay.albedo_color = Color.WHITE
	var models := {"pistol": "skinny", "rifle": "skinny", "melee": "beard", "super": "brute"}
	for kind in ["pistol", "rifle", "melee", "super"]:
		var enemy := load("res://scenes/npcs/%s_thug.tscn" % kind).instantiate() as HostileBase
		var model: Node3D = enemy.get_node("Superhero_Male_FullBody")
		check(model.scene_file_path == "res://assets/characters/Hostiles/prepared/thug_white_male_%s_rigged.glb" % models[kind], "Encounter type uses its approved hostile mesh: " + kind)
		check(model.find_children("*", "Skeleton3D", true, false).size() == 1, "Replacement model has one skeleton")
		var mesh := enemy.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		mesh.material_overlay = original_overlay
		world.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
		var animation: AnimationPlayer = model.get_node("CharacterAnimationPlayer")
		for clip in ["Idle", "Sprint", "Pistol_Shoot" if kind in ["pistol", "rifle"] else "Punch_01"]:
			check(animation.has_animation(clip), "Gameplay animation is available: " + clip)
			animation.play(clip)
			animation.advance(0.15)
		if kind == "super":
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			check(absf(bounds.size.y - 2.3) < 0.005, "Encounter brute retains its approved 2.3 m height")
			check(enemy.max_health == 500 and enemy.faction == &"mafia" and not enemy.can_grab, "Super combat identity survives the model replacement")
		check(enemy.nameplate.visible and mesh.material_overlay == original_overlay, "Enemy textures start without the debug tint")
		check(enemy._debug_tint.albedo_color.is_equal_approx(Color(enemy.nameplate.modulate, 0.75)), "Tint matches each enemy's type color at 75 percent opacity")
	debug.show_enemy_tints = true
	debug.show_enemy_names = false
	for enemy in enemies:
		check(not enemy.nameplate.visible and enemy._debug_meshes[0].material_overlay == enemy._debug_tint, "Names toggle independently of tint")
	debug.show_enemy_tints = false
	for enemy in enemies:
		check(enemy._debug_meshes[0].material_overlay == original_overlay, "Tint off restores original overlay exactly")
	var later := preload("res://scenes/npcs/melee_thug.tscn").instantiate()
	world.add_child(later)
	later.set_physics_process(false)
	check(not later.nameplate.visible and later._debug_meshes[0].material_overlay == null, "New spawns inherit disabled debug settings")
	debug.show_enemy_names = true
	debug.show_enemy_tints = true
	check(later.nameplate.visible and later._debug_meshes[0].material_overlay == later._debug_tint, "Toggles update existing enemies immediately")
	later._die()
	debug.show_enemy_names = false
	debug.show_enemy_names = true
	check(not later.nameplate.visible, "Name toggle cannot resurrect a dead enemy's label")
	check(original_overlay.albedo_color == Color.WHITE, "Shared source material was not modified")
	world.free()
	print("Enemy debug visuals: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

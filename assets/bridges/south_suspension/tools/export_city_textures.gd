extends SceneTree
## Read the existing Godot textures for the packed Blender source materials.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/south_bridge")
	for label in ["road_20m", "sidewalk"]:
		var texture: Texture2D = load("res://assets/super-city/textures/%s.res" % label)
		assert(texture.get_image().save_png("res://artifacts/south_bridge/%s.png" % label) == OK)
	quit()

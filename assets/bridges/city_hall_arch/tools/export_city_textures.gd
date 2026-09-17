extends SceneTree

func _initialize() -> void:
	var output := "res://artifacts/city_hall_bridge/"
	DirAccess.make_dir_recursive_absolute(output)
	for texture_name in ["road_28m", "sidewalk"]:
		var texture: Texture2D = load("res://assets/super-city/textures/" + texture_name + ".res")
		var result := texture.get_image().save_png(output + texture_name + ".png")
		if result != OK:
			push_error("Could not export bridge reference texture: " + texture_name)
			quit(1)
			return
	quit()

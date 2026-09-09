extends "res://assets/super-city/tools/generate_super_city.gd"
## Updates road visuals in-place without packing or rewriting either city scene.
func _initialize() -> void:
	var layout = JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	for row in layout.roads:
		var data: Dictionary = row.duplicate()
		data.rect = Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])
		roads.append(data)
	city = Node3D.new()
	groups["Roads"] = group(city,"Roads")
	groups["Sidewalks"] = group(city,"Sidewalks")
	# Load existing base resources; only road textures/materials/meshes change.
	for width in [6,12,20,28]:
		materials["road_%dm" % width] = load(OUT+"materials/road_%dm.tres" % width)
	bake_transport()
	print("Updated road approach crosswalks: 3 m stripes, 2 m setback; junction interiors clear. Scene files and collision geometry untouched.")
	city.free()
	quit()

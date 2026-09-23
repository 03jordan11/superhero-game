extends SceneTree
## Run after update_stair_sides.py and reimport. Preserve native prop text.
const BASE := "res://assets/buildings/city_hall/"
func _initialize() -> void:
	var model: Node3D = load(BASE+"city_hall.glb").instantiate()
	var text := FileAccess.get_file_as_string(BASE+"city_hall.tscn")
	var newline := "\r\n" if text.contains("\r\n") else "\n"
	text = text.replace("\r\n", "\n")
	var props := text.substr(text.find('[node name="GardenProps"'))
	var pattern := RegEx.new()
	pattern.compile('(?ms)^\\[node name="(?:Landingpiers|Staircheekwalls)\\d*"[^\\n]*\\]\\n.*?(?=^\\[|\\z)')
	text = pattern.sub(text, "", true)
	for side: String in ["Left", "Right"]:
		var mesh := model.get_node("Continuous stair side "+side) as MeshInstance3D
		var path := BASE+"stair_side_"+side.to_lower()+"_collision.res"
		assert(ResourceSaver.save(mesh.mesh.create_trimesh_shape(),path) == OK)
		if not text.contains('id="stair_side_'+side+'"'):
			var at := text.find("[sub_resource")
			text = text.insert(at, '[ext_resource type="Shape3D" path="'+path+'" id="stair_side_'+side+'"]\n\n')
		if not text.contains('[node name="ContinuousStairSide'+side+'"'):
			var at := text.find('[node name="GardenProps"')
			text = text.insert(at, '[node name="ContinuousStairSide'+side+'" type="CollisionShape3D" parent="ExteriorCollision"]\nshape = ExtResource("stair_side_'+side+'")\n\n')
	assert(text.substr(text.find('[node name="GardenProps"')) == props)
	FileAccess.open(BASE+"city_hall.tscn",FileAccess.WRITE).store_string(text.replace("\n",newline))
	model.free()
	print("CITY_HALL_STAIR_COLLISION_PASS: continuous walls, native props preserved verbatim")
	quit()

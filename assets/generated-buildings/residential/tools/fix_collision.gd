extends SceneTree
const FIT=preload("res://assets/generated-buildings/residential/tools/residential_collision.gd")
func _initialize() -> void:
	var folder:="res://assets/generated-buildings/residential/"
	DirAccess.make_dir_recursive_absolute("res://artifacts/residential_collision")
	for i in range(1,21):
		var name_string:="residential_building_%02d.tscn"%i
		var body: StaticBody3D=load(folder+name_string).instantiate()
		FIT.fit(body,body.get_node("MeshInstance3D").mesh,i)
		var scene:=PackedScene.new(); assert(scene.pack(body)==OK)
		assert(ResourceSaver.save(scene,"res://artifacts/residential_collision/"+name_string)==OK)
		body.free()
	print("RESIDENTIAL_BOXES_BUILT: 20 scenes, solid tier volumes, original primary node paths")
	quit()

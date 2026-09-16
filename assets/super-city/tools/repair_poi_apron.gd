extends SceneTree
const BUILDER=preload("res://assets/super-city/tools/city_mesh.gd")
func _initialize() -> void:
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	var tile:=Rect2(-1000,0,500,500)
	var builder=BUILDER.new()
	builder.origin=Vector3(-750,0,250)
	var mat: Material=load("res://assets/super-city/materials/sidewalk.tres")
	for row in layout.sidewalks:
		var r:=Rect2(row[0],row[1],row[2],row[3]).intersection(tile)
		if r.has_area():builder.slab(r,.03,.03,mat,r.size/4,false,r.position/4)
	var body: StaticBody3D=builder.body("sidewalks_1_2","res://assets/super-city/meshes/sidewalks_1_2.res")
	assert(ResourceSaver.save(body.get_node("CollisionShape3D").shape,"res://assets/super-city/poi-integration/sidewalks_1_2_collision.res")==OK)
	body.free()
	print("Rebuilt the firehouse apron across its 500 m chunk seam.")
	quit()

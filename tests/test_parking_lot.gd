extends SceneTree
const LOT := preload("res://assets/parking_lots/parking_lot.tscn")

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var a := LOT.instantiate()
	var b := LOT.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.width_m=52
	a.depth_m=58
	assert(a.get_parking_layout()==Vector2i(17,5))
	assert(b.get_parking_layout()==Vector2i(8,3),"Dimensions leaked between instances")
	assert(a.mesh!=b.mesh and a.mesh.material==b.mesh.material)
	assert(a.get_instance_shader_parameter("lot_size_m")==Vector2(52,58))
	for width: float in [2,7.2,9.7,9.8,16,30,52,70]:
		for depth: float in [2,12.3,12.4,18,36,58,80]:
			a.width_m=width
			a.depth_m=depth
			var layout: Vector2i=a.get_parking_layout()
			assert(layout.x>=0 and layout.y>=0)
			if layout.x>0: assert(layout.x*a.stall_width_m+a.aisle_width_m+1.2<=width+.001)
			if layout.y>0: assert(layout.y*(a.stall_depth_m+a.aisle_width_m)+1.2<=depth+.001)
			assert(a.mesh.get_faces().size()/3==2,"Resizing added geometry")
	a.width_m=26
	a.depth_m=29
	a.scale=Vector3(2,1,2)
	a.rotation.y=.7
	assert(a.get_parking_layout()==Vector2i(17,5),"Scaled/rotated lot uses incorrect real-world dimensions")
	assert(a.get_child_count()==0,"Visual lot unexpectedly adds logic/collision children")
	print("PARKING_LOT_PASS: 56 sizes, complete bays/aisles, instance isolation, transform scaling, constant 2 triangles")
	a.free()
	b.free()
	quit()

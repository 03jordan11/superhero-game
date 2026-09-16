extends SceneTree
## Explicit offline authoring tool. Only writes this kit and its test scene.
## Re-running overwrites manual edits to the test scene; never run automatically.
const OUT := "res://assets/super-city/modular-sidewalks/"
const TEST_SCENE := "res://scenes/previews/modular_sidewalk_test.tscn"
const MATERIAL = preload("res://assets/super-city/modular-sidewalks/sidewalk.tres")
const TOP := 0.03
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()

func _initialize() -> void: build.call_deferred()

func own(parent: Node, child: Node, root_node: Node) -> void:
	parent.add_child(child)
	child.owner = root_node

func triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for point in [a,b,c]:
		vertices.append(point); normals.append(normal); uvs.append(Vector2(point.x,point.z)/4.0)

func face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	triangle(a,b,c,normal); triangle(a,c,d,normal)

func shape_mesh(polygons: Array) -> ArrayMesh:
	vertices.clear(); normals.clear(); uvs.clear()
	var edges := {}
	for polygon: Array in polygons:
		for i in range(1,polygon.size()-1):
			var a := Vector3(polygon[0].x,TOP,polygon[0].y)
			var b := Vector3(polygon[i].x,TOP,polygon[i].y)
			var c := Vector3(polygon[i+1].x,TOP,polygon[i+1].y)
			triangle(a,b,c,Vector3.UP)
			triangle(c-Vector3.UP*TOP,b-Vector3.UP*TOP,a-Vector3.UP*TOP,Vector3.DOWN)
		for i in polygon.size():
			var a: Vector2 = polygon[i]; var b: Vector2 = polygon[(i+1)%polygon.size()]
			var reverse := str(b)+":"+str(a)
			if edges.has(reverse): edges.erase(reverse)
			else: edges[str(a)+":"+str(b)] = [a,b]
	for edge: Array in edges.values():
		var a: Vector2 = edge[0]; var b: Vector2 = edge[1]
		var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()
		face(Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(b.x,TOP,b.y),Vector3(a.x,TOP,a.y),normal)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,MATERIAL)
	return mesh

func rect_polygon(rect: Rect2) -> Array:
	return [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]

func module(id: String, cells: Array, ports: Dictionary, length := 0.0, capped := false) -> Dictionary:
	var root_node := StaticBody3D.new(); root_node.name = id.to_pascal_case()
	root_node.set_meta("sidewalk_module", id)
	root_node.set_meta("snap_grid_m", 2.0)
	root_node.set_meta("path_width_m", 4.0)
	root_node.set_meta("_edit_group_", true)
	var polygons: Array = []
	var rects: Array[Rect2] = []
	if length > 0: rects.append(Rect2(-2,-length/2,4,length))
	else:
		for cell: Vector2 in cells: rects.append(Rect2(cell-Vector2(2,2),Vector2(4,4)))
	if capped:
		polygons.append([Vector2(-2,-2),Vector2(2,-2),Vector2(2,1.5),Vector2(1.5,2),Vector2(-1.5,2),Vector2(-2,1.5)])
	else:
		for rect in rects: polygons.append(rect_polygon(rect))
	var visual := MeshInstance3D.new(); visual.name = "Mesh"
	visual.mesh = shape_mesh(polygons)
	assert(ResourceSaver.save(visual.mesh,OUT+"meshes/"+id+".res")==OK)
	visual.mesh.take_over_path(OUT+"meshes/"+id+".res")
	own(root_node,visual,root_node)
	if capped:
		var shape := ConvexPolygonShape3D.new(); var points := PackedVector3Array()
		for point: Vector2 in polygons[0]:
			# One millimetre of horizontal overlap tolerates float error at 90° joins.
			point *= 1.0005
			points.append(Vector3(point.x,0,point.y)); points.append(Vector3(point.x,TOP,point.y))
		shape.points = points
		var collision := CollisionShape3D.new(); collision.name = "Collision"; collision.shape = shape
		own(root_node,collision,root_node)
	else:
		for i in rects.size():
			var rect := rects[i]
			var shape := BoxShape3D.new(); shape.size = Vector3(rect.size.x+0.002,TOP,rect.size.y+0.002)
			var collision := CollisionShape3D.new(); collision.name = "Collision%d" % i
			collision.shape=shape; collision.position=Vector3(rect.get_center().x,TOP/2,rect.get_center().y)
			own(root_node,collision,root_node)
	var sockets := Node3D.new(); sockets.name="Sockets"; own(root_node,sockets,root_node)
	for port: String in ports:
		var point: Vector2 = ports[port]
		var marker := Marker3D.new(); marker.name=port
		marker.position=Vector3(point.x,0,point.y)
		marker.rotation.y=atan2(-point.x,-point.y)
		marker.gizmo_extents=0.7
		own(sockets,marker,root_node)
	var packed := PackedScene.new(); assert(packed.pack(root_node)==OK)
	assert(ResourceSaver.save(packed,OUT+id+".tscn")==OK)
	var report := {"id":id,"triangles":visual.mesh.surface_get_array_len(0)/3,"sockets":ports.size(),"collision_shapes":1 if capped else rects.size()}
	root_node.free()
	return report

func group(root_node: Node, node_name: String) -> Node3D:
	var node := Node3D.new(); node.name=node_name; own(root_node,node,root_node); return node

func place(root_node: Node, parent: Node, id: String, node_name: String, at: Vector2, turn := 0.0) -> void:
	var piece := (load(OUT+id+".tscn") as PackedScene).instantiate() as Node3D
	piece.name=node_name; piece.position=Vector3(at.x,0,at.y); piece.rotation.y=deg_to_rad(turn)
	own(parent,piece,root_node)

func label(root_node: Node, parent: Node, node_name: String, caption: String, at: Vector3, size := 48) -> void:
	var text := Label3D.new(); text.name=node_name; text.text=caption; text.position=at
	text.font_size=size; text.pixel_size=0.06; text.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate=Color(0.8,0.92,1); text.outline_modulate=Color(0.03,0.04,0.06); text.outline_size=10
	own(parent,text,root_node)

func preview() -> void:
	var scene := Node3D.new(); scene.name="ModularSidewalkTest"
	scene.set_script(load("res://scripts/previews/modular_sidewalk_test.gd"))
	var loose := group(scene,"LoosePieces")
	var labels := group(scene,"Labels")
	var defs := [["straight_4m",-76, "4 m",4],["straight_8m",-60,"8 m",8],["straight_16m",-44,"16 m",16],["straight_40m",-28,"40 m",40]]
	for row: Array in defs:
		place(scene,loose,row[0],row[0].to_pascal_case(),Vector2(row[1],-24))
		label(scene,labels,row[0]+"Label",row[2],Vector3(row[1],1,-27-row[3]/2.0))
	defs=[["corner_l",-76,"CORNER"],["junction_t",-60,"T JUNCTION"],["junction_cross",-44,"CROSS"],["end_cap",-28,"END CAP"]]
	for row: Array in defs:
		place(scene,loose,row[0],row[0].to_pascal_case(),Vector2(row[1],0))
		label(scene,labels,row[0]+"Label",row[2],Vector3(row[1],1,10),44)
	label(scene,labels,"KitTitle","LOOSE PIECES",Vector3(-52,1,-57),60)
	label(scene,labels,"ExampleTitle","CONNECTED EXAMPLE",Vector3(25,1,-48),60)
	var example := group(scene,"AssembledExample")
	var placements := [
		["junction_cross","CenterCross",28,-20,0], ["straight_16m","EastStraight",42,-20,90],
		["corner_l","NorthEastCorner",56,-20,180], ["straight_16m","RightStraight",56,-6,0],
		["corner_l","SouthEastCorner",56,8,90], ["straight_16m","BottomStraight",42,8,90],
		["corner_l","SouthWestCorner",28,8,0], ["straight_16m","LeftStraight",28,-6,0],
		["straight_8m","NorthStraight",28,-30,0], ["end_cap","NorthCap",28,-36,180],
		["straight_8m","WestStraight",18,-20,90], ["junction_t","WestJunction",8,-20,0],
		["straight_8m","WestBranch",-2,-20,90], ["end_cap","WestCap",-8,-20,-90],
		["end_cap","JunctionCap",8,-28,180]]
	for row: Array in placements: place(scene,example,row[0],row[1],Vector2(row[2],row[3]),row[4])
	var ground := StaticBody3D.new(); ground.name="TestGround"; ground.position=Vector3(-4,-0.1,-15)
	own(scene,ground,scene)
	var mesh := MeshInstance3D.new(); mesh.name="Mesh"; var box := BoxMesh.new(); box.size=Vector3(156,0.2,100); mesh.mesh=box
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(0.065,0.09,0.12); mat.roughness=1
	mesh.material_override=mat; own(ground,mesh,scene)
	var collision := CollisionShape3D.new(); collision.name="Collision"; var shape:=BoxShape3D.new(); shape.size=box.size; collision.shape=shape; own(ground,collision,scene)
	var environment := WorldEnvironment.new(); environment.name="Environment"; environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.11,0.15,0.2)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color(0.8,0.87,1); environment.environment.ambient_light_energy=0.35
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	own(scene,environment,scene)
	var sun:=DirectionalLight3D.new(); sun.name="Sun"; sun.rotation_degrees=Vector3(-55,-25,0); sun.light_energy=1.0; sun.shadow_enabled=true; own(scene,sun,scene)
	var camera:=Camera3D.new(); camera.name="OverviewCamera"; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=156; camera.far=600
	camera.position=Vector3(6,134,53); camera.rotation_degrees=Vector3(-63,6,0); camera.current=true; own(scene,camera,scene)
	var start:=Marker3D.new(); start.name="PlayerStart"; start.position=Vector3(28,1.25,8); own(scene,start,scene)
	var player:Node3D=load("res://scenes/player.tscn").instantiate(); player.name="Player"; player.transform=start.transform
	player.process_mode=Node.PROCESS_MODE_DISABLED; player.visible=false; own(scene,player,scene)
	var ui:=CanvasLayer.new(); ui.name="Instructions"; ui.layer=15; own(scene,ui,scene)
	var panel:=PanelContainer.new(); panel.name="Panel"; panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left=28; panel.offset_right=-28; panel.offset_top=-104; panel.offset_bottom=-24; panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; own(ui,panel,scene)
	var help:=Label.new(); help.name="Help"; help.text="F4: walk test | Grid snap 2 m | Rotation snap 90 degrees"; help.add_theme_font_size_override("font_size",24); help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; help.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; help.mouse_filter=Control.MOUSE_FILTER_IGNORE; own(panel,help,scene)
	var packed:=PackedScene.new(); assert(packed.pack(scene)==OK); assert(ResourceSaver.save(packed,TEST_SCENE)==OK); scene.free()

func build() -> void:
	DirAccess.make_dir_recursive_absolute(OUT+"meshes")
	var report: Array = []
	for length in [4,8,16,40]:
		report.append(module("straight_%dm"%length,[],{"North":Vector2(0,-length/2.0),"South":Vector2(0,length/2.0)},length))
	report.append(module("corner_l",[Vector2.ZERO,Vector2(0,-4),Vector2(4,0)],{"North":Vector2(0,-6),"East":Vector2(6,0)}))
	report.append(module("junction_t",[Vector2.ZERO,Vector2(0,-4),Vector2(-4,0),Vector2(4,0)],{"North":Vector2(0,-6),"West":Vector2(-6,0),"East":Vector2(6,0)}))
	report.append(module("junction_cross",[Vector2.ZERO,Vector2(0,-4),Vector2(0,4),Vector2(-4,0),Vector2(4,0)],{"North":Vector2(0,-6),"South":Vector2(0,6),"West":Vector2(-6,0),"East":Vector2(6,0)}))
	report.append(module("end_cap",[],{"North":Vector2(0,-2)},0,true))
	preview()
	var file:=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE); file.store_string(JSON.stringify({"width_m":4,"grid_m":2,"top_y":TOP,"modules":report},"\t")+"\n"); file.close()
	print("MODULAR_SIDEWALK_KIT_BUILT ",JSON.stringify(report))
	quit()

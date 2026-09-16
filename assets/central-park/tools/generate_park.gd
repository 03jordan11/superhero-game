extends SceneTree
## Offline park authoring. Writes only the dedicated park scene/assets, never the city.
const LAYOUT = preload("res://assets/central-park/tools/park_layout.gd")
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
const OUT := "res://assets/central-park/"
var rng := RandomNumberGenerator.new()
var park: Node3D
var routes: Array[Dictionary]
var meshes: Dictionary = {}
var materials: Dictionary = {}
var tree_records: Array[Dictionary] = []
var lantern_points: Array[Vector3] = []
var mesh_index := 0

func _initialize() -> void:
	generate.call_deferred()

func generate() -> void:
	# The dummy headless renderer discards MultiMesh transforms during serialization.
	if DisplayServer.get_name() == "headless":
		push_error("Bake the park with a graphics renderer (omit --headless); MultiMesh buffers must be saved.")
		quit(1)
		return
	rng.seed = 735190
	DirAccess.make_dir_recursive_absolute(OUT + "meshes")
	park = Node3D.new()
	park.name = "CentralPark"
	park.set_script(load("res://scripts/central_park.gd"))
	park.set_meta("park_rect", LAYOUT.BOUNDS)
	for name in ["Terrain", "Lake", "Trails", "Woodland", "TreeCollisions", "Lanterns", "Houses", "Landmarks", "Discoveries", "Foliage"]:
		add(Node3D.new(), park, name)
	materials.wood = material(Color("654934"))
	materials.darkwood = material(Color("302f2a"))
	materials.stone = material(Color("686b70"))
	materials.iron = material(Color("293338"))
	materials.lantern = glow_material(Color("ffcc75"), 3.5, false)
	materials.window = glow_material(Color("ffc47a"), 2.3, false)
	materials.vertex = material(Color.WHITE)
	materials.vertex.vertex_color_use_as_albedo = true
	materials.vertex.vertex_color_is_srgb = true
	routes = LAYOUT.paths()
	make_terrain()
	make_trails()
	make_bridge()
	make_dock()
	make_houses()
	make_forest()
	make_details()
	make_fireflies()
	assert(tree_records.size() == LAYOUT.TREE_COUNT, "Failed to place target tree count")
	var restored := TREES.restore_saved_layout(park,"res://scenes/central_park.tscn")
	if restored >= 0:
		tree_records.clear()
		for tree in TREES.trees(park):
			var pose := Transform3D.IDENTITY
			var ancestor: Node3D = tree
			while ancestor != park:
				pose = ancestor.transform*pose
				ancestor = ancestor.get_parent()
			tree_records.append({"x":pose.origin.x,"z":pose.origin.z,"kind":TREES.SPECIES.find(tree.scene_file_path.get_file().get_basename()),"scale":pose.basis.get_scale().x})
	park.set_meta("tree_count", tree_records.size())
	park.set_meta("lantern_count", lantern_points.size())
	park.set_meta("house_count", 3)
	for node in park.find_children("*", "MultiMeshInstance3D", true, false):
		assert(not node.multimesh.buffer.is_empty(), "Missing instance transforms: " + node.name)
	var packed := PackedScene.new()
	assert(packed.pack(park) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/central_park.tscn") == OK)
	var manifest := {"seed":735190,"tree_count":tree_records.size(),"lantern_count":lantern_points.size(),"trees":tree_records,"houses":[[-171,-186],[155,156],[-157,177]],"lake_center":[32,-54],"lake_size":[91,74],"meadow_center":[LAYOUT.MEADOW.x,LAYOUT.MEADOW.y],"meadow_radii":[LAYOUT.MEADOW_RADII.x,LAYOUT.MEADOW_RADII.y]}
	var file := FileAccess.open(OUT + "layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	park.free()
	print("Central Park authored: %d trees, %d path lanterns, three houses, lake, bridge and open meadow." % [tree_records.size(), lantern_points.size()])
	quit()

func add(node: Node, parent: Node, label: String) -> Node:
	node.name = label
	parent.add_child(node, true)
	node.owner = park
	return node

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	return result

func glow_material(color: Color, energy: float, magic: bool) -> StandardMaterial3D:
	var result := material(color * 0.3)
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = 0.0
	result.set_meta("glow_energy", energy)
	if magic: result.set_meta("magic", true)
	return result

func save_mesh(mesh: Mesh, label: String) -> Mesh:
	var path := OUT + "meshes/" + label + ".res"
	assert(ResourceSaver.save(mesh, path) == OK)
	mesh.take_over_path(path)
	return mesh

func visual(mesh: Mesh, parent: Node, label: String, position := Vector3.ZERO, override_material: Material = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	if override_material != null:
		node.material_override = override_material
		if override_material.has_meta("glow_energy"): node.set_meta("glow_material",true)
	add(node,parent,label)
	return node

func box(parent: Node, label: String, size: Vector3, position: Vector3, mat: Material, collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := visual(mesh,parent,label,position,mat)
	if collision:
		var body := StaticBody3D.new()
		add(body,node,"Solid")
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		add(shape,body,"CollisionShape3D")
	return node

func cylinder(radius: float, height: float, top: float = -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh

func ball(size: Vector3) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 3
	return mesh

func append(tool: SurfaceTool, mesh: Mesh, pose: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	for i in range(0,indices.size(),3):
		var a := pose * vertices[indices[i]]
		var b := pose * vertices[indices[i+1]]
		var c := pose * vertices[indices[i+2]]
		var normal := (b-a).cross(c-a).normalized()
		if normal.dot(pose.basis * normals[indices[i]]) < 0.0: normal = -normal
		for point in [a,b,c]:
			tool.set_color(color)
			tool.set_normal(normal)
			tool.add_vertex(point)

func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for point in [a,b,c]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(point)

func surface_body(mesh: ArrayMesh, parent: Node, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	add(body,parent,label)
	visual(mesh,body,"MeshInstance3D")
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_trimesh_shape()
	add(collider,body,"CollisionShape3D")
	return body

func make_terrain() -> void:
	var ground: Dictionary = preload("res://assets/central-park/tools/park_terrain.gd").build(rng)
	var mesh: ArrayMesh = ground.mesh
	park.set_meta("terrain_triangles",ground.triangles)
	park.set_meta("terrain_max_unsplit_error",ground.max_unsplit_error)
	save_mesh(mesh,"terrain")
	surface_body(mesh,park.get_node("Terrain"),"Ground")
	var lake_tool := SurfaceTool.new()
	lake_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector2 = LAYOUT.LAKE_CENTER
	for i in 96:
		var points: Array[Vector3] = [Vector3(center.x,0.12,center.y)]
		for index in [i,i+1]:
			var angle: float = index/96.0*TAU
			var radius := 1.0+0.08*sin(angle*3.0)+0.05*cos(angle*5.0)
			var p: Vector2 = center+Vector2(cos(angle),sin(angle))*LAYOUT.LAKE_SIZE*radius*1.14
			points.append(Vector3(p.x,0.12,p.y))
		triangle(lake_tool,points[0],points[1],points[2],Color.WHITE)
	var water := save_mesh(lake_tool.commit(),"lake")
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load(OUT+"lake.gdshader")
	visual(water,park.get_node("Lake"),"Water",Vector3.ZERO,water_mat)
	marker("MoonwaterLake",Vector2(32,-54),7.0)

func make_trails() -> void:
	var builder := preload("res://assets/central-park/tools/park_paths.gd").new()
	var ground: Mesh = park.get_node("Terrain/Ground/MeshInstance3D").mesh
	var trail_meshes := builder.build(ground)
	for path in routes:
		var points: PackedVector2Array = path.points
		var mesh: ArrayMesh = trail_meshes[path.name]
		save_mesh(mesh,"trail_"+str(path.name).to_snake_case())
		surface_body(mesh,park.get_node("Trails"),path.name)
		if path.lit:
			var traveled := 0.0
			for i in points.size()-1:
				traveled += points[i].distance_to(points[i+1])
				if traveled < 57.0: continue
				traveled = 0.0
				var direction := (points[i+1]-points[i]).normalized()
				var p := points[i]+Vector2(-direction.y,direction.x)*(float(path.width)*0.5+1.0)
				if LAYOUT.lake_radius(p)>1.18: lantern(p)

func lantern(p: Vector2) -> void:
	var node := Node3D.new()
	add(node,park.get_node("Lanterns"),"TrailLantern%d"%lantern_points.size())
	node.position = Vector3(p.x,LAYOUT.height(p),p.y)
	lantern_points.append(node.position)
	box(node,"Post",Vector3(0.18,4.0,0.18),Vector3(0,2,0),materials.iron)
	box(node,"Base",Vector3(0.40,0.35,0.40),Vector3(0,0.175,0),materials.iron)
	visual(cylinder(0.42,0.4,0.0),node,"Roof",Vector3(0,4.55,0),materials.iron)
	visual(cylinder(0.23,0.48),node,"WarmGlass",Vector3(0,4.13,0),materials.lantern)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd28a")
	light.light_energy = 2.8
	light.omni_range = 13.0
	light.omni_attenuation = 0.65
	light.position = Vector3(0,3.9,0)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 90.0
	light.distance_fade_length = 70.0
	add(light,node,"WarmPool")

func marker(label: String, point: Vector2, lift := 1.4) -> void:
	var mark := Marker3D.new()
	mark.position = Vector3(point.x,LAYOUT.height(point)+lift,point.y)
	add(mark,park.get_node("Discoveries"),label)

func make_bridge() -> void:
	var bridge := Node3D.new()
	add(bridge,park.get_node("Landmarks"),"BowBridge")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := Vector2(-48,18)
	var end := Vector2(112,18)
	var y0 := LAYOUT.height(start)+0.13
	var y1 := LAYOUT.height(end)+0.13
	for i in 80:
		var a := float(i)/80.0
		var b := float(i+1)/80.0
		var x0 := lerpf(start.x,end.x,a)
		var x1 := lerpf(start.x,end.x,b)
		var h0 := lerpf(y0,y1,a)+sin(a*PI)*2.5
		var h1 := lerpf(y0,y1,b)+sin(b*PI)*2.5
		var color := Color("876549") if i%2==0 else Color("967558")
		triangle(tool,Vector3(x0,h0,15.7),Vector3(x1,h1,15.7),Vector3(x1,h1,20.3),color)
		triangle(tool,Vector3(x0,h0,15.7),Vector3(x1,h1,20.3),Vector3(x0,h0,20.3),color)
		for z in [15.65,20.35]:
			if i%9==0: box(bridge,"Pier",Vector3(0.4,h0+3.7,0.4),Vector3(x0,(h0-3.7)*0.5,z),materials.darkwood)
	var mesh := tool.commit()
	mesh.surface_set_material(0,materials.vertex)
	save_mesh(mesh,"bridge_deck")
	surface_body(mesh,bridge,"Deck")
	make_bridge_railings(bridge,y0,y1)
	marker("BowBridge",Vector2(32,18),8.0)

func make_bridge_railings(bridge: Node3D, y0: float, y1: float) -> void:
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 128:
		for x in 128:
			if x < 8 or y < 9 or y > 115:
				image.set_pixel(x,y,Color("493d31").lightened(.055 if x<3 or y>123 else 0.0))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,OUT+"meshes/bridge_railing_albedo.res") == OK)
	texture.take_over_path(OUT+"meshes/bridge_railing_albedo.res")
	var railing_material := material(Color.WHITE)
	railing_material.albedo_texture = texture
	railing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	railing_material.alpha_scissor_threshold = .45
	railing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision := StaticBody3D.new()
	add(collision,bridge,"RailingCollision")
	for i in 20:
		var a := i/20.0
		var b := (i+1)/20.0
		var x0 := lerpf(-48,112,a)
		var x1 := lerpf(-48,112,b)
		var h0 := lerpf(y0,y1,a)+sin(a*PI)*2.5
		var h1 := lerpf(y0,y1,b)+sin(b*PI)*2.5
		for side in [-1,1]:
			var z: float = 18.0+side*2.35
			var points := [Vector3(x0,h0,z),Vector3(x1,h1,z),Vector3(x1,h1+1.10,z),Vector3(x0,h0+1.10,z)]
			var uvs := [Vector2(0,0),Vector2(4,0),Vector2(4,1),Vector2(0,1)]
			for id in [0,1,2,0,2,3]:
				tool.set_normal(Vector3(0,0,side))
				tool.set_uv(uvs[id])
				tool.add_vertex(points[id])
			var shape := BoxShape3D.new()
			shape.size = Vector3(Vector2(x1-x0,h1-h0).length()+.04,1.10,.14)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3((x0+x1)*.5,(h0+h1)*.5+.55,z)
			collider.rotation.z = atan2(h1-h0,x1-x0)
			add(collider,collision,"RailGuard")
	var mesh := tool.commit()
	mesh.surface_set_material(0,railing_material)
	save_mesh(mesh,"bridge_railings")
	visual(mesh,bridge,"TexturedRailings")

func make_dock() -> void:
	var dock := Node3D.new()
	add(dock,park.get_node("Landmarks"),"MoonwaterDock")
	var p := Vector2(157,-57)
	dock.position = Vector3(p.x,LAYOUT.height(p),p.y)
	box(dock,"Boardwalk",Vector3(40,0.25,4),Vector3(-18,0.4,0),materials.wood,true)
	var ramp := box(dock,"ShoreRamp",Vector3(5,0.12,4),Vector3(4.4,0.22,0),materials.wood,true)
	ramp.rotation.z = -atan(0.105)
	box(dock,"LakePlatform",Vector3(8,0.25,12),Vector3(-34,0.4,0),materials.wood,true)
	for x in [-36,-24,-12,0]:
		for z in [-1.8,1.8]: box(dock,"Piling",Vector3(0.3,6,0.3),Vector3(x,-2.5,z),materials.darkwood)
	bench(dock,Vector3(-34,0.53,-4),0.0)
	marker("MoonwaterDock",Vector2(123,-57),5.0)

func bench(parent: Node, position: Vector3, yaw: float) -> void:
	var seat := Node3D.new()
	add(seat,parent,"Bench")
	seat.position = position
	seat.rotation.y = yaw
	box(seat,"Seat",Vector3(2.8,0.13,0.65),Vector3(0,0.62,0),materials.wood,true)
	box(seat,"Back",Vector3(2.8,0.68,0.12),Vector3(0,1,-0.34),materials.wood)
	for x in [-1,1]: box(seat,"Leg",Vector3(0.16,0.6,0.5),Vector3(x,0.3,0),materials.iron)

func make_houses() -> void:
	var names := ["WillowHermitage","BirchHideaway","MosskeeperCottage"]
	for i in 3:
		var house := Node3D.new()
		add(house,park.get_node("Houses"),names[i])
		var p: Vector2 = LAYOUT.CABINS[i]
		house.position = Vector3(p.x,0.15,p.y)
		var wall := material([Color("84735a"),Color("8b927d"),Color("865e50")][i])
		var roof := material([Color("384c48"),Color("465467"),Color("4f5140")][i])
		box(house,"Floor",Vector3(10,0.22,8),Vector3(0,0.08,0),materials.wood,true)
		box(house,"BackWall",Vector3(10,3.6,0.25),Vector3(0,1.9,-4),wall,true)
		for x in [-4.9,4.9]: box(house,"SideWall",Vector3(0.25,3.6,8),Vector3(x,1.9,0),wall,true)
		for x in [-3.0,3.0]: box(house,"FrontWall",Vector3(3.9,3.6,0.25),Vector3(x,1.9,4),wall,true)
		box(house,"DoorLintel",Vector3(2.2,0.9,0.25),Vector3(0,3.25,4),wall,true)
		for side in [-1,1]:
			var panel := box(house,"GabledRoof",Vector3(5.75,0.24,9.5),Vector3(side*2.55,4.87,0),roof,true)
			panel.rotation.z = -side*atan2(2.2,5.1)
			box(house,"LitWindow",Vector3(1.3,1.1,0.04),Vector3(side*3.0,2.12,4.15),materials.window)
			for sx in [-0.36,0.36]: box(house,"WindowMullion",Vector3(0.055,1.12,0.06),Vector3(side*3.0+sx,2.12,4.19),materials.darkwood)
			box(house,"Shutter",Vector3(0.4,1.25,0.16),Vector3(side*3.0+side*0.92,2.12,4.16),materials.darkwood)
		for z in [-4.02,4.02]:
			var triangle_tool := SurfaceTool.new()
			triangle_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			triangle(triangle_tool,Vector3(-5,3.7,z),Vector3(5,3.7,z),Vector3(0,6,z),Color.WHITE)
			var gable := triangle_tool.commit()
			wall.cull_mode = BaseMaterial3D.CULL_DISABLED
			visual(gable,house,"Gable",Vector3.ZERO,wall)
		box(house,"BrickChimney",Vector3(1.15,3.2,1.2),Vector3(2.7,5.4,-1.5),material(Color("715045")),true)
		box(house,"Porch",Vector3(7,0.18,2.1),Vector3(0,0.05,5.05),materials.wood,true)
		var ramp := box(house,"EntryRamp",Vector3(2.5,0.08,2.0),Vector3(0,0.03,7.1),materials.wood,true)
		ramp.rotation.x = atan(0.07)
		bench(house,Vector3(-2.1,0.18,5),0.0)
		box(house,"BedFrame",Vector3(1.5,0.4,2.5),Vector3(-3.4,0.4,-1.9),materials.darkwood,true)
		box(house,"Blanket",Vector3(1.45,0.15,2.35),Vector3(-3.4,0.68,-1.9),material(Color("657b72")))
		box(house,"Table",Vector3(1.8,0.14,1.3),Vector3(2.5,1.0,-1),materials.wood,true)
		for stack in 4: box(house,"Books",Vector3(0.4,0.11,0.32),Vector3(2.5,1.14+stack*0.11,-1),material(Color("8c6954")))
		for log_index in 5:
			var log := visual(cylinder(0.22,1.8),house,"Firewood",Vector3(5.8,0.3+float(log_index%2)*0.4,-2.8+float(log_index/2)*0.45),materials.wood)
			log.rotation.z = PI*0.5
		var glow := OmniLight3D.new()
		glow.light_color = Color("ffd398")
		glow.light_energy = 1.5
		glow.omni_range = 9.0
		glow.position = Vector3(0,2.5,2.4)
		glow.shadow_enabled = true
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 50
		glow.distance_fade_length = 35
		glow.distance_fade_shadow = 35
		add(glow,house,"HearthLight")
		marker(names[i],p+Vector2(0,9))

func make_tree(kind: int) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("60503a") if kind != 2 else Color("c7c5ad")
	var trunk_mesh := cylinder(0.42,8.0,0.22)
	trunk_mesh.radial_segments = 4
	trunk_mesh.rings = 0
	append(tool,trunk_mesh,Transform3D(Basis.IDENTITY,Vector3(0,4,0)),bark)
	var leaves := [Color("3d633d"),Color("2d4d3d"),Color("719252"),Color("54794e")][kind] as Color
	if kind == 0:
		# Four 20-triangle crowns retain a broad, lobed oak silhouette.
		for entry in [[Vector3(-2.7,8.3,-0.5),Vector3(4.5,3.5,4.5)],
			[Vector3(2.7,8.7,-0.3),Vector3(4.5,3.6,4.5)],
			[Vector3(0,10.2,-2.1),Vector3(4.8,3.8,4.5)],
			[Vector3(0,8.6,2.6),Vector3(4.5,3.6,4.7)]]:
			low_poly_crown(tool,entry[0],entry[1],leaves)
	elif kind == 1:
		for tier in 4:
			low_poly_cone(tool,Vector3(0,6+tier*2.6,0),4.5-tier*0.85,6.3-tier*0.55,leaves.lightened(tier*0.04))
	elif kind == 2:
		# Narrow, upright crowns and pale bark distinguish birch from oak.
		for entry in [[Vector3(0,10,0),Vector3(2.4,3.9,2.4)],
			[Vector3(-1.65,8,-.5),Vector3(2.2,3.5,2.3)],
			[Vector3(1.65,8.5,0),Vector3(2.2,3.5,2.3)],
			[Vector3(0,8.1,1.8),Vector3(2.2,3.5,2.3)]]:
			low_poly_crown(tool,entry[0],entry[1],leaves)
	else:
		# Broad crown with long, low lobes retains the willow's drooping outline.
		for entry in [[Vector3(0,10,-1.2),Vector3(4.2,4.8,4.2)],
			[Vector3(-3,6.5,-1),Vector3(3.7,4.8,3.7)],
			[Vector3(3,7,0),Vector3(3.7,4.8,3.7)],
			[Vector3(0,6.5,3),Vector3(3.7,4.8,3.7)]]:
			low_poly_crown(tool,entry[0],entry[1],leaves)
	var mesh := tool.commit()
	assert(mesh.get_faces().size()/3 <= 100,"Tree exceeds 100 triangles")
	mesh.surface_set_material(0,materials.vertex)
	return save_mesh(mesh,"tree_"+["oak","pine","birch","willow"][kind])

func low_poly_cone(tool: SurfaceTool, center: Vector3, radius: float, height: float, color: Color) -> void:
	# Eight sides plus a six-triangle bottom: closed, with no redundant rings.
	var rim: Array[Vector3] = []
	for i in 8:
		var angle := float(i)*TAU/8.0
		rim.append(Vector3(cos(angle)*radius,-height*.5,sin(angle)*radius))
	var faces: Array = []
	for i in 8: faces.append([rim[i],Vector3(0,height*.5,0),rim[(i+1)%8]])
	for i in range(1,7): faces.append([rim[0],rim[i],rim[i+1]])
	for face in faces:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		if (c-a).cross(b-a).dot(a+b+c) < 0:
			var swap := b
			b = c
			c = swap
		triangle(tool,a+center,b+center,c+center,color)

func low_poly_crown(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var golden := (1.0+sqrt(5.0))/2.0
	var vertices := [Vector3(-1,golden,0),Vector3(1,golden,0),Vector3(-1,-golden,0),Vector3(1,-golden,0),
		Vector3(0,-1,golden),Vector3(0,1,golden),Vector3(0,-1,-golden),Vector3(0,1,-golden),
		Vector3(golden,0,-1),Vector3(golden,0,1),Vector3(-golden,0,-1),Vector3(-golden,0,1)]
	var faces := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
		[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	for face in faces:
		var a: Vector3 = vertices[face[0]].normalized()*size
		var b: Vector3 = vertices[face[1]].normalized()*size
		var c: Vector3 = vertices[face[2]].normalized()*size
		if (c-a).cross(b-a).dot(a+b+c) < 0:
			var swap := b
			b = c
			c = swap
		triangle(tool,a+center,b+center,c+center,color.lightened(clampf((a.y+b.y+c.y)/30.0,0,.10)))

func make_forest() -> void:
	park.get_node("Woodland").set_meta("tree_container",true)
	var trees: Array[Mesh] = []
	for kind in 4: trees.append(make_tree(kind))
	var batches: Dictionary = {}
	var cells: Dictionary = {}
	for attempt in 19000:
		if tree_records.size()>=LAYOUT.TREE_COUNT: break
		var p := Vector2(rng.randf_range(-242,242),rng.randf_range(-288,288))
		if LAYOUT.lake_radius(p)<1.24: continue
		if LAYOUT.in_meadow(p, 13.0): continue
		var blocked := false
		for clearing in LAYOUT.CABINS:
			if p.distance_to(clearing)<16.0: blocked=true; break
		if blocked or LAYOUT.path_distance(p,routes)<4.7: continue
		# Keep a clear approach around the dock and bridge.
		if Rect2(-57,11,180,15).has_point(p) or Rect2(115,-66,51,18).has_point(p): continue
		var cell := Vector2i(floori(p.x/14),floori(p.y/14))
		for dx in range(-1,2):
			for dz in range(-1,2):
				for previous in cells.get(cell+Vector2i(dx,dz),[]):
					if p.distance_to(previous)<13.0: blocked=true
		if blocked: continue
		if not cells.has(cell): cells[cell]=[]
		cells[cell].append(p)
		var kind := rng.randi_range(0,2)
		if LAYOUT.lake_radius(p)<1.6: kind=3
		var size := rng.randf_range(0.75,1.45)
		var pose := Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(p.x,LAYOUT.height(p),p.y))
		var region := Vector3i(floori(p.x/80),floori(p.y/80),kind)
		if not batches.has(region): batches[region]=[]
		batches[region].append(pose)
		tree_records.append({"x":p.x,"z":p.y,"kind":kind,"scale":size})
	for key in batches:
		TREES.group(park.get_node("Woodland"),park,TREES.SPECIES[key.z]+"_Cell_%d_%d"%[key.x,key.y],TREES.SPECIES[key.z],batches[key],1600,150,true)

func batch(mesh: Mesh, poses: Array, parent: Node, label: String) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = poses.size()
	for i in poses.size(): node.multimesh.set_instance_transform(i,poses[i])
	node.visibility_range_end = 1600.0
	node.visibility_range_end_margin = 150.0
	add(node,parent,label)
	return node

func make_details() -> void:
	# Fern/bush clusters in the woods, kept away from trails and lake water.
	var bush_tool := SurfaceTool.new()
	bush_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One tapered eight-vertex shrub instead of three intersecting spheres.
	var shrub := [Vector3(-.95,.06,-.8),Vector3(2.25,.06,-.8),Vector3(2.25,.06,.8),Vector3(-.95,.06,.8),
		Vector3(-.65,1.05,-.60),Vector3(1.95,1.16,-.60),Vector3(1.95,1.05,.60),Vector3(-.65,.95,.60)]
	for face in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		for ids in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
			var a: Vector3 = shrub[ids[0]]
			var b: Vector3 = shrub[ids[1]]
			var c: Vector3 = shrub[ids[2]]
			var normal := (c-a).cross(b-a).normalized()
			if normal.dot((a+b+c)/3.0-Vector3(.65,.55,0)) < 0:
				var swap := b
				b = c
				c = swap
				normal = -normal
			for p: Vector3 in [a,b,c]:
				bush_tool.set_normal(normal)
				bush_tool.set_uv(Vector2(p.x,p.z) if absf(normal.y)>.7 else Vector2(p.x+p.z,p.y))
				bush_tool.add_vertex(p)
	var bush_mesh := bush_tool.commit()
	assert(bush_mesh.get_faces().size()/3 <= 20,"Bush exceeds 20 triangles")
	var bush_material := material(Color.WHITE)
	var leaf_image := Image.create(128,128,false,Image.FORMAT_RGB8)
	leaf_image.fill(Color("455b36"))
	var leaf_rng := RandomNumberGenerator.new()
	leaf_rng.seed = 19723
	for leaf in 220:
		var px := leaf_rng.randi_range(0,127)
		var py := leaf_rng.randi_range(0,127)
		var color := Color("365130").lerp(Color("6b8150"),leaf_rng.randf())
		for dy in range(-3,4):
			for dx in range(-5,6):
				if dx*dx/25.0+dy*dy/9.0 <= 1.0:
					leaf_image.set_pixel(posmod(px+dx,128),posmod(py+dy,128),color)
	leaf_image.generate_mipmaps()
	var leaf_texture := ImageTexture.create_from_image(leaf_image)
	assert(ResourceSaver.save(leaf_texture,OUT+"meshes/bush_albedo.res") == OK)
	leaf_texture.take_over_path(OUT+"meshes/bush_albedo.res")
	bush_material.albedo_texture = leaf_texture
	bush_mesh.surface_set_material(0,bush_material)
	save_mesh(bush_mesh,"undergrowth")
	var bushes: Array[Transform3D] = []
	for i in 280:
		var record: Dictionary = tree_records[rng.randi_range(0,tree_records.size()-1)]
		var p := Vector2(record.x+2.0,record.z+1.8)
		if LAYOUT.in_meadow(p, 3.0): continue
		if LAYOUT.path_distance(p,routes)<2.0: continue
		var pose := Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(p.x,LAYOUT.height(p),p.y))
		if i % 2 == 0: bushes.append(pose) # Retain half, preserving the RNG sequence for later props.
	assert(bushes.size() == 140,"Half of the original 280 bushes must remain")
	batch(bush_mesh,bushes,park.get_node("Foliage"),"Undergrowth")
	for entry in [[Vector2(-15,269),0.0],[Vector2(-204,125),PI*0.5],[Vector2(182,-89),-PI*0.5],[Vector2(65,218),0.0]]:
		var p: Vector2=entry[0]
		bench(park.get_node("Landmarks"),Vector3(p.x,LAYOUT.height(p),p.y),entry[1])
	# Low stone entrance piers frame four park approaches without closing them.
	for entry in [[Vector2(0,296),0.0],[Vector2(-70,-296),0.0],[Vector2(-249,135),PI*0.5],[Vector2(248,58),PI*0.5]]:
		var p: Vector2=entry[0]
		var gate := Node3D.new()
		add(gate,park.get_node("Landmarks"),"ParkGate")
		gate.position=Vector3(p.x,LAYOUT.height(p),p.y)
		gate.rotation.y=entry[1]
		for side in [-1,1]: box(gate,"StonePier",Vector3(1.1,2.6,1.1),Vector3(side*4.2,1.3,0),materials.stone,true)
	marker("GreatLawn",LAYOUT.MEADOW)

func make_fireflies() -> void:
	var positions: Array[Vector3] = []
	for center in [Vector2(-122,-35),Vector2(-169,-161),Vector2(159,173),Vector2(-143,201),Vector2(136,-40),Vector2(-53,-120),Vector2(76,48),Vector2(157,-189),Vector2(-199,71),Vector2(54,201)]:
		for i in 70:
			var p: Vector2 = center+Vector2(rng.randf_range(-15,15),rng.randf_range(-15,15))
			positions.append(Vector3(p.x,maxf(0.6,LAYOUT.height(p))+rng.randf_range(0.8,3.0),p.y))
	make_swarm("Fireflies",positions,0.3,1.0)

func make_swarm(label: String, positions: Array[Vector3], size: float, drift: float) -> void:
	var node := MultiMeshInstance3D.new()
	node.multimesh=MultiMesh.new()
	node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data=true
	var quad := QuadMesh.new()
	quad.size=Vector2.ONE*size
	node.multimesh.mesh=quad
	node.multimesh.instance_count=positions.size()
	for i in positions.size():
		node.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,positions[i]))
		node.multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),0.0,1.0))
	node.multimesh.custom_aabb=AABB(Vector3(-254,-5,-302),Vector3(508,35,604))
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := ShaderMaterial.new()
	shader.shader=load(OUT+"fireflies.gdshader")
	shader.set_shader_parameter("drift",drift)
	node.material_override=shader
	add(node,park,label)



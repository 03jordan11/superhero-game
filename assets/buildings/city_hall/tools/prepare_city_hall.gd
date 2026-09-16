extends SceneTree
## Run after importing the GLBs. Native props keep their collision when moved.
const FOLDER := "res://assets/buildings/city_hall/"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "city_hall_manifest.json"))
	var prop_scenes: Dictionary = {}
	for kind: String in ["bench", "table", "hedge"]:
		var prop := Node3D.new()
		prop.name = kind.capitalize()
		add_owned(prop, (load(FOLDER + "props/" + kind + ".glb") as PackedScene).instantiate(), "Mesh")
		var body := StaticBody3D.new()
		add_owned(prop, body, "Collision")
		match kind:
			"bench":
				add_box(body, prop, "Seat", Vector3(0, .46, 0), Vector3(2.4, .16, .6))
				for x: float in [-.78, .78]:
					add_box(body, prop, "Support", Vector3(x, .19, 0), Vector3(.3, .38, .48))
			"table":
				add_box(body, prop, "Top", Vector3(0, .78, 0), Vector3(2.6, .16, 1.1))
				for x: float in [-.78, .78]:
					add_box(body, prop, "Support", Vector3(x, .35, 0), Vector3(.32, .70, .72))
			"hedge":
				add_box(body, prop, "Hedge", Vector3(0, .65, 0), Vector3(8, 1.3, 1.2))
		var packed := PackedScene.new()
		assert(packed.pack(prop) == OK)
		assert(ResourceSaver.save(packed, FOLDER + "props/" + kind + ".tscn") == OK)
		prop_scenes[kind] = load(FOLDER + "props/" + kind + ".tscn")
		prop.free()
	var hall := Node3D.new()
	hall.name = "CityHall"
	hall.set_script(load(FOLDER + "city_hall.gd"))
	add_owned(hall, (load(FOLDER + "city_hall.glb") as PackedScene).instantiate(), "Model")
	var collision := StaticBody3D.new()
	add_owned(hall, collision, "ExteriorCollision")
	for entry: Dictionary in manifest.collision_boxes:
		add_box(collision, hall, entry.name, vector(entry.center), vector(entry.size))
	for entry: Dictionary in manifest.collision_hulls:
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for point: Array in entry.points:
			points.append(vector(point))
		shape.points = points
		var collider := CollisionShape3D.new()
		collider.name = entry.name.replace(" ", "")
		collider.shape = shape
		collision.add_child(collider, true)
		collider.owner = hall
	var garden := Node3D.new()
	add_owned(hall, garden, "GardenProps")
	for entry: Dictionary in manifest.props:
		var prop: Node3D = prop_scenes[entry.kind].instantiate()
		prop.name = entry.name
		prop.position = vector(entry.position)
		prop.rotation.y = entry.rotation_y
		garden.add_child(prop)
		prop.owner = hall
	var packed := PackedScene.new()
	assert(packed.pack(hall) == OK)
	assert(ResourceSaver.save(packed, FOLDER + "city_hall.tscn") == OK)
	hall.free()
	print("CITY_HALL_SCENE_READY: standalone asset and three independent prop scenes")
	quit()

func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func add_owned(parent: Node, child: Node, node_name: String) -> void:
	child.name = node_name
	parent.add_child(child)
	child.owner = parent

func add_box(body: Node, scene_root: Node, label: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = label.replace(" ", "")
	collider.position = center
	collider.shape = shape
	body.add_child(collider, true)
	collider.owner = scene_root

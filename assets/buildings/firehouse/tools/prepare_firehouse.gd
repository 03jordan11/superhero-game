extends SceneTree
const FOLDER := "res://assets/buildings/firehouse/"

func _initialize() -> void:
	var bench := Node3D.new()
	bench.name = "StoneBench"
	owned(bench, (load(FOLDER + "props/bench.glb") as PackedScene).instantiate(), "Mesh")
	var bench_body := StaticBody3D.new()
	owned(bench, bench_body, "Collision")
	box(bench_body, bench, "Seat", Vector3(0, .48, 0), Vector3(2, .16, .55))
	for x: float in [-.65, .65]:
		box(bench_body, bench, "Support", Vector3(x, .2, 0), Vector3(.28, .4, .42))
	save(bench, FOLDER + "props/bench.tscn")
	bench.free()
	var bench_scene := load(FOLDER + "props/bench.tscn") as PackedScene
	var hall := Node3D.new()
	hall.name = "Firehouse"
	hall.set_script(load(FOLDER + "firehouse.gd"))
	owned(hall, (load(FOLDER + "firehouse.glb") as PackedScene).instantiate(), "Model")
	var body := StaticBody3D.new()
	owned(hall, body, "ExteriorCollision")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "firehouse_manifest.json"))
	for entry: Dictionary in manifest.collision_boxes:
		box(body, hall, entry.name, vector(entry.center), vector(entry.size))
	var props := Node3D.new()
	owned(hall, props, "Props")
	for entry: Dictionary in manifest.props:
		var prop := bench_scene.instantiate() as Node3D
		prop.name = entry.name
		prop.position = vector(entry.position)
		prop.rotation.y = entry.rotation_y
		props.add_child(prop)
		prop.owner = hall
	save(hall, FOLDER + "firehouse.tscn")
	hall.free()
	print("FIREHOUSE_SCENE_READY")
	quit()

func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func owned(parent: Node, node: Node, label: String) -> void:
	node.name = label
	parent.add_child(node)
	node.owner = parent

func box(body: Node, owner_root: Node, label: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = label.replace(" ", "")
	collision.shape = shape
	collision.position = center
	body.add_child(collision, true)
	collision.owner = owner_root

func save(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)

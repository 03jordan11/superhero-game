extends SceneTree
const BASE := "res://assets/waterfront/cargo_ship/"
const PALETTES := {
	"ocean_blue": ["135e96", "805030", "dedbd0", "2292a1", "c64f26", "d4d4c5", "364a54"],
	"oxide_red": ["923c32", "62645b", "e5e0d3", "416674", "bc9b65", "d4d4c5", "865146"],
	"deep_teal": ["205750", "666d67", "d7ddd6", "608f87", "b66639", "ced8ce", "37575b"],
	"graphite": ["343d48", "786c54", "ddd9cb", "416985", "b9a36c", "cfd2ca", "915945"]
}
const SLOTS := ["Hull", "Deck", "Superstructure", "ContainerA", "ContainerB", "ContainerC", "ContainerD"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	for key: String in PALETTES:
		var palette := Resource.new()
		palette.set_script(load(BASE + "ship_palette.gd"))
		palette.resource_name = key.capitalize()
		for i in SLOTS.size():
			var material := StandardMaterial3D.new()
			material.resource_name = key + "_" + SLOTS[i]
			material.albedo_color = Color.html(PALETTES[key][i])
			material.albedo_texture = load(BASE + "textures/" + ("container_panels.png" if i >= 3 else "painted_steel.png"))
			material.metallic = .12
			material.roughness = .72
			var path: String = BASE + "materials/" + key + "_" + SLOTS[i].to_snake_case() + ".tres"
			assert(ResourceSaver.save(material, path) == OK)
			palette.set(SLOTS[i].to_snake_case(), load(path))
		assert(ResourceSaver.save(palette, BASE + "materials/" + key + ".tres") == OK)
	var ship := Node3D.new()
	ship.name = "CargoShip"
	ship.set_script(load(BASE + "cargo_ship.gd"))
	ship.palette = load(BASE + "materials/ocean_blue.tres")
	var model: Node3D = load(BASE + "cargo_ship.glb").instantiate()
	add(ship, model, "Model", ship)
	var body := StaticBody3D.new()
	add(ship, body, "Collision", ship)
	# Exact low-poly hull/deck collision plus simple boxes for every container and roof.
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(part.name) in ["Hull", "Antifouling", "BootStripe", "Deck"]:
			var collision := CollisionShape3D.new()
			collision.shape = part.mesh.create_trimesh_shape()
			collision.transform = part.transform
			add(body, collision, String(part.name), ship)
	for entry: Dictionary in manifest.collision_boxes:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = vector(entry.size)
		collision.shape = shape
		collision.position = vector(entry.center)
		add(body, collision, String(entry.name), ship)
	var lamps := Node3D.new()
	add(ship, lamps, "NavigationLights", ship)
	for entry: Dictionary in manifest.lights:
		var lens := MeshInstance3D.new()
		lens.position = vector(entry.position)
		lens.mesh = octahedron(.24)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shader := ShaderMaterial.new()
		shader.shader = load(BASE + "navigation_lens.gdshader")
		shader.set_shader_parameter("light_color", Color(entry.color[0], entry.color[1], entry.color[2]))
		shader.set_shader_parameter("center_degrees", entry.center)
		shader.set_shader_parameter("arc_degrees", entry.arc)
		lens.material_override = shader
		lens.set_meta("mode", entry.mode)
		add(lamps, lens, entry.name, ship)
	var ball := MeshInstance3D.new()
	ball.mesh = octahedron(.4)
	ball.position = Vector3(0,24,-60)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(.015,.015,.015)
	ball.material_override = black
	add(ship, ball, "AnchorDayBall", ship)
	var deck_lights := Node3D.new()
	add(ship, deck_lights, "DeckLights", ship)
	for side in [-1,1]:
		for z in [-48,0,48]:
			var light := SpotLight3D.new()
			light.position = Vector3(side*10.8,19,z)
			light.rotation_degrees.x = -90
			light.light_color = Color(1,.86,.64)
			light.spot_range = 30
			light.spot_angle = 65
			light.light_energy = 2
			light.shadow_enabled = false
			add(deck_lights, light, "DeckLamp", ship)
	# Apply the default palette in the packed scene so it also reads correctly before _ready.
	ship.apply_palette()
	save_scene(ship, BASE + "cargo_ship.tscn")
	ship.free()
	for key: String in PALETTES:
		var scene := '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="PackedScene" path="%scargo_ship.tscn" id="1"]\n[ext_resource type="Resource" path="%smaterials/%s.tres" id="2"]\n\n[node name="CargoShip" instance=ExtResource("1")]\npalette = ExtResource("2")\n' % [BASE, BASE, key]
		FileAccess.open(BASE + "cargo_ship_" + key + ".tscn", FileAccess.WRITE).store_string(scene)
	print("CARGO_SHIP_SCENES_READY: four palettes, collision, navigation sectors")
	quit()

func vector(v: Array) -> Vector3:
	return Vector3(v[0],v[1],v[2])

func add(parent: Node, child: Node, label: String, owner_root: Node) -> void:
	child.name = label
	parent.add_child(child, true)
	child.owner = owner_root

func save_scene(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene, path) == OK)

func octahedron(radius: float) -> ArrayMesh:
	var vertices := [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]
	var faces := [0,3,4,0,5,3,0,2,5,0,4,2,1,4,3,1,3,5,1,5,2,1,2,4]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in faces: st.add_vertex(vertices[i] * radius)
	st.generate_normals()
	return st.commit()

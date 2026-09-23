extends SceneTree
## Offline Godot-native authoring. No generation or processing on placed instances.
const BASE := "res://assets/props/subway_entrance/"
var prop: Node3D
var materials := {}

func _initialize() -> void:
	build.call_deferred()

func own(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = prop

func material(key: String, color: String, metal := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = key
	result.albedo_color = Color.from_string(color, Color.WHITE)
	result.metallic = metal
	result.roughness = 0.72
	materials[key] = result
	return result

func box(parent: Node, title: String, size: Vector3, at: Vector3, mat: String, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials[mat]
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.position = at
	own(parent, node)
	if solid:
		var body := StaticBody3D.new()
		body.name = "Collision"
		own(node, body)
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		own(body, shape)
	return node

func group(title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	own(prop, node)
	return node

func build() -> void:
	prop = Node3D.new()
	prop.name = "SubwayEntrance"
	material("Charcoal", "#303946", 0.45)
	material("DarkMetal", "#202A30", 0.4)
	material("Stone", "#646E70")
	material("Bronze", "#B68B59", 0.65)
	material("BlankSign", "#18232B")
	var glass := material("Glass", "#708F91", 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.27
	glass.roughness = 0.22
	var glow := material("WarmStrip", "#E3D8B9")
	glow.emission_enabled = true
	glow.emission = Color("#E3D8B9")
	glow.emission_energy_multiplier = 0.65
	var beacon := material("GreenBeacon", "#51BA83")
	beacon.emission_enabled = true
	beacon.emission = Color("#51BA83")
	beacon.emission_energy_multiplier = 1.5
	var canopy := group("Canopy")
	box(canopy, "Roof", Vector3(3.7,0.23,5.0), Vector3(0,3.0,0), "Charcoal", true)
	box(canopy, "FrontBlankFascia", Vector3(3.62,0.27,0.035), Vector3(0,2.96,2.515), "BlankSign")
	box(canopy, "LeftBlankFascia", Vector3(0.035,0.27,4.94), Vector3(-1.865,2.96,0), "BlankSign")
	box(canopy, "RightBlankFascia", Vector3(0.035,0.27,4.94), Vector3(1.865,2.96,0), "BlankSign")
	box(canopy, "TopCap", Vector3(3.8,0.055,5.1), Vector3(0,3.14,0), "DarkMetal")
	box(canopy, "BeaconBase", Vector3(1.98,0.08,0.58), Vector3(0,3.2075,1.9), "DarkMetal")
	box(canopy, "GreenBeacon", Vector3(1.8,0.34,0.42), Vector3(0,3.3975,1.9), "GreenBeacon")
	for side in [-1,1]:
		box(canopy, "UndersideStrip%d" % (side+1), Vector3(0.075,0.025,4.5), Vector3(side*1.5,2.875,0), "WarmStrip")
	for z in [-1.5,0.0,1.5]:
		box(canopy, "RoofRib%d" % int((z+1.5)*2), Vector3(3.1,0.07,0.07), Vector3(0,2.84,z), "DarkMetal")
	var frame := group("Frame")
	for x in [-1.55,1.55]:
		for z in [-2.15,2.15]:
			box(frame, "Post%d" % frame.get_child_count(), Vector3(0.16,2.87,0.16), Vector3(x,1.435,z), "Charcoal", true)
	var sides := group("StairwellSurround")
	for side in [-1,1]:
		var suffix := "Left" if side < 0 else "Right"
		box(sides, suffix+"Base", Vector3(0.28,0.26,4.6), Vector3(side*1.55,0.13,0), "Stone", true)
		box(sides, suffix+"BaseCap", Vector3(0.32,0.055,4.66), Vector3(side*1.55,0.288,0), "DarkMetal")
		box(sides, suffix+"Glass", Vector3(0.025,0.87,4.15), Vector3(side*1.55,0.74,0), "Glass", true)
		box(sides, suffix+"TopRail", Vector3(0.075,0.075,4.34), Vector3(side*1.55,1.21,0), "Charcoal")
		box(sides, suffix+"CenterMullion", Vector3(0.055,0.94,0.055), Vector3(side*1.55,0.75,0), "Charcoal")
	box(sides, "BackWall", Vector3(3.1,1.24,0.14), Vector3(0,0.62,-2.2), "DarkMetal", true)
	box(sides, "BackCap", Vector3(3.24,0.065,0.23), Vector3(0,1.27,-2.2), "Charcoal")
	box(sides, "EntryThreshold", Vector3(2.84,0.045,0.25), Vector3(0,0.0225,2.26), "Stone")
	var stair := MeshInstance3D.new()
	stair.name = "SealedStairwell"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.84,4.35)
	var stair_material := ShaderMaterial.new()
	stair_material.shader = load(BASE+"stairwell.gdshader")
	plane.material = stair_material
	stair.mesh = plane
	stair.position = Vector3(0,0.05,-0.035)
	own(sides, stair)
	# Solid closure prevents walking across the painted opening. Future travel
	# interaction can activate from the approach marker without excavating terrain.
	var closure := StaticBody3D.new()
	closure.name = "StairwellClosure"
	own(sides, closure)
	var closure_shape := CollisionShape3D.new()
	closure_shape.name = "Shape"
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.84,1.3,4.35)
	closure_shape.shape = bounds
	closure_shape.position = Vector3(0,0.65,-0.035)
	own(closure, closure_shape)
	var kiosk := group("BlankInformationPanel")
	box(kiosk, "Housing", Vector3(0.40,2.25,0.23), Vector3(1.37,1.125,2.2), "Charcoal", true)
	box(kiosk, "Face", Vector3(0.32,1.7,0.012), Vector3(1.37,1.29,2.322), "BlankSign")
	box(kiosk, "AccentCap", Vector3(0.42,0.055,0.25), Vector3(1.37,2.27,2.2), "Bronze")
	var marker := Marker3D.new()
	marker.name = "Approach"
	marker.position = Vector3(0,0,3.2)
	own(prop, marker)
	var triangles := 0
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		triangles += mesh.mesh.get_faces().size()/3
	assert(triangles < 500, "Entrance exceeds budget: %d" % triangles)
	prop.set_meta("rendered_triangles", triangles)
	var packed := PackedScene.new()
	assert(packed.pack(prop) == OK)
	assert(ResourceSaver.save(packed, BASE+"subway_entrance.tscn") == OK)
	print("SUBWAY_BUILD_PASS: %d rendered triangles" % triangles)
	prop.free()
	quit()

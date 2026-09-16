extends SceneTree
const BASE := "res://assets/aircraft/helicopter/"
func own(parent: Node, node: Node, scene: Node) -> void:
	parent.add_child(node)
	node.owner = scene
func _initialize() -> void: call_deferred("build")
func build() -> void:
	var scene := Node3D.new()
	scene.name = "HelicopterPreview"
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("a9bac8")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c3d3e1")
	world.environment.ambient_light_energy = .3
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	own(scene,world,scene)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = .9
	sun.shadow_enabled = true
	own(scene,sun,scene)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = PlaneMesh.new()
	floor_node.mesh.size = Vector2(100,100)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("626c73")
	mat.roughness = 1
	floor_node.material_override = mat
	own(scene,floor_node,scene)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(-27,23,-31)
	camera.look_at_from_position(camera.position,Vector3(0,1.5,0))
	camera.fov = 48
	camera.current = true
	camera.set_script(load(BASE+"tools/preview_camera.gd"))
	own(scene,camera,scene)
	for i in range(4):
		var heli: Node3D = load(BASE+"helicopter.tscn").instantiate()
		heli.name = ["ForestStatic","RescueSpinning","CoastalStatic","CharcoalSpinning"][i]
		heli.position = Vector3(-8.0 if i%2==0 else 8.0,0,-8.0 if i<2 else 8.0)
		heli.set("livery",i)
		heli.set("rotors_spinning",i%2==1)
		heli.set("parked_collision_enabled",true)
		own(scene,heli,scene)
		var label := Label3D.new()
		label.text = ["FOREST / CREAM · STATIC","RESCUE RED · SPINNING","COASTAL BLUE · STATIC","CHARCOAL / ORANGE · SPINNING"][i]
		label.position = heli.position + Vector3(0,.15,-5)
		label.font_size = 42
		label.pixel_size = .012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		own(scene,label,scene)
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	own(scene,canvas,scene)
	var help := Label.new()
	help.text = "HELICOPTER PREVIEW\nRight mouse + WASD: fly camera | Q/E: down/up | Shift: faster\nSelect a helicopter root in the Inspector to change livery, rotor speed or static mode."
	help.position = Vector2(18,18)
	help.add_theme_font_size_override("font_size",18)
	own(canvas,help,scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,BASE+"helicopter_preview.tscn")==OK)
	scene.free()
	print("HELICOPTER_PREVIEW_CREATED")
	quit()

extends SceneTree
const BASE := "res://assets/buildings/gas_station_hideout/"

func _initialize() -> void:
	var station := Node3D.new()
	station.name = "GasStationHideout"
	var model := (load(BASE + "gas_station_hideout.glb") as PackedScene).instantiate()
	model.name = "Model"
	station.add_child(model); model.owner = station
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	var collision := StaticBody3D.new()
	collision.name = "ExteriorCollision"
	station.add_child(collision); collision.owner = station
	for data: Dictionary in manifest.collision_boxes:
		var shape := BoxShape3D.new()
		shape.size = vector(data.size)
		var node := CollisionShape3D.new()
		node.name = String(data.name).replace(" ", "")
		node.shape = shape
		node.position = vector(data.center)
		collision.add_child(node,true); node.owner = station
	for label: String in ["Entry", "RearEntry"]:
		var marker := Marker3D.new(); marker.name = label
		marker.position = vector(manifest.entry_marker if label == "Entry" else manifest.rear_entry_marker)
		station.add_child(marker); marker.owner = station
	station.set_meta("rendered_triangles", int(manifest.exported_triangles))
	station.set_meta("exterior_only", true)
	if ResourceLoader.exists(BASE + "hideout_entrance.tscn"):
		var entrance := (load(BASE + "hideout_entrance.tscn") as PackedScene).instantiate()
		station.add_child(entrance); entrance.owner = station
	save(station, BASE + "gas_station_hideout.tscn")
	station.free()
	# Separate preview owns its camera and lights; the placeable asset has none.
	var preview := Node3D.new(); preview.name = "GasStationPreview"
	var asset := (load(BASE + "gas_station_hideout.tscn") as PackedScene).instantiate()
	preview.add_child(asset); asset.owner = preview
	var env := WorldEnvironment.new(); env.name = "Environment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16,0.20,0.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75,0.82,0.90)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	preview.add_child(env); env.owner = preview
	var sun := DirectionalLight3D.new(); sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48,-32,0); sun.light_energy = 1.25
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 100
	preview.add_child(sun); sun.owner = preview
	var camera := Camera3D.new(); camera.name = "Camera3D"
	camera.position = Vector3(29,24,34); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36; camera.far = 200; camera.current = true
	camera.rotation = Basis.looking_at(Vector3(0,1.7,0.8) - camera.position).get_euler()
	preview.add_child(camera); camera.owner = preview
	save(preview,BASE + "gas_station_preview.tscn")
	preview.free()
	print("GAS_STATION_SCENE_READY")
	quit()

func vector(data: Array) -> Vector3:
	return Vector3(data[0],data[1],data[2])

func save(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,path) == OK)

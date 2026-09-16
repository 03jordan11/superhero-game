extends SceneTree
## Run after Godot has imported hospital.glb; creates the reusable collision wrapper.
const FOLDER := "res://assets/buildings/hospital/"

func _initialize() -> void:
	var hospital := Node3D.new()
	hospital.name = "Hospital"
	hospital.set_script(load(FOLDER + "hospital.gd"))
	var model := (load(FOLDER + "hospital.glb") as PackedScene).instantiate()
	model.name = "Model"
	hospital.add_child(model)
	model.owner = hospital
	var body := StaticBody3D.new()
	body.name = "ExteriorCollision"
	hospital.add_child(body)
	body.owner = hospital
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "hospital_manifest.json"))
	for entry: Dictionary in manifest.collision_boxes:
		var shape := BoxShape3D.new()
		shape.size = Vector3(entry.size[0], entry.size[1], entry.size[2])
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(entry.center[0], entry.center[1], entry.center[2])
		body.add_child(collider)
		collider.owner = hospital
	# Faceted bays use small convex prisms, preserving the open U-shaped courtyard.
	for data: Dictionary in manifest.front_bays:
		var points := PackedVector3Array()
		for y: float in [data.bottom, data.top]:
			for i in int(data.segments) + 1:
				var angle := PI * float(i) / float(data.segments)
				points.append(Vector3(data.center[0] + cos(angle) * data.radius, y, data.center[2] + sin(angle) * data.radius))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collider := CollisionShape3D.new()
		collider.name = "RoundedWingLeft" if data.center[0] < 0 else "RoundedWingRight"
		collider.shape = shape
		body.add_child(collider)
		collider.owner = hospital
	var canopy_shape := BoxShape3D.new()
	canopy_shape.size = Vector3(21, 0.4, 12.3)
	var canopy_collision := CollisionShape3D.new()
	canopy_collision.name = "Canopy"
	canopy_collision.shape = canopy_shape
	canopy_collision.position = Vector3(0, 5.45, 25.2)
	body.add_child(canopy_collision)
	canopy_collision.owner = hospital
	for side in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.name = "EntranceLightLeft" if side < 0 else "EntranceLightRight"
		light.position = Vector3(side * 6.0, 4.4, 25)
		light.light_color = Color(1.0, 0.76, 0.48)
		light.light_energy = 0.0
		light.omni_range = 13.0
		light.omni_attenuation = 1.5
		hospital.add_child(light)
		light.owner = hospital
	var packed := PackedScene.new()
	assert(packed.pack(hospital) == OK)
	assert(ResourceSaver.save(packed, FOLDER + "hospital.tscn") == OK)
	hospital.free()
	print("HOSPITAL_SCENE_READY")
	quit()

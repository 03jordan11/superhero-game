extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var container := Node3D.new()
	container.name = "TrafficTest"
	root.add_child(container)
	var player := CharacterBody3D.new()
	root.add_child(player)
	var camera := Camera3D.new()
	player.add_child(camera)
	camera.position = Vector3(0.0, 0.8, 5.0)
	var interactor := PlayerVehicleInteractor.new()
	player.add_child(interactor)
	interactor.setup(player, camera)

	for model in ["cop", "normal_car_1", "normal_car_2", "sports_car", "sports_car_2", "suv", "taxi"]:
		var scene := load("res://scenes/vehicles/%s.tscn" % model) as PackedScene
		assert(scene != null, model)
		var vehicle := scene.instantiate() as Vehicle
		assert(vehicle != null, model)
		container.add_child(vehicle)
		assert(vehicle.freeze and is_equal_approx(vehicle.mass, 1200.0), model)
		assert(vehicle.get_node("CollisionShape3D").shape is BoxShape3D, model)
		var mesh := vehicle.get_node("MeshInstance3D") as MeshInstance3D
		assert(mesh.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE * 1.3), model)
		assert(is_equal_approx(vehicle.get_current_health(), 100.0), model)
		assert(vehicle.is_in_group(&"explodable"), model)
		await physics_frame
		await physics_frame
		assert(interactor.try_pick_up_vehicle(), "Pickup outside Vehicles parent: " + model)
		assert(interactor.held_vehicle == vehicle, model)
		interactor.drop_held_vehicle()
		assert(vehicle.get_parent() == container and not vehicle.freeze, model)
		vehicle.free()

	container.name = "Vehicles"
	var prop := RigidBody3D.new()
	prop.freeze = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 2.0)
	collision.shape = shape
	prop.add_child(collision)
	container.add_child(prop)
	await physics_frame
	await physics_frame
	assert(not interactor.try_pick_up_vehicle(), "Ordinary rigid bodies must not count as vehicles")
	container.free()
	player.free()
	print("PASS: All seven vehicle scenes and type-based pickup")
	quit()

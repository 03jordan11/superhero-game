extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var explosion_controller := ExplosionController.new()
	explosion_controller.minimum_impact_speed = 18.0
	root.add_child(explosion_controller)

	var source := Node3D.new()
	root.add_child(source)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)

	vehicle.arm_thrown_impact(17.0, source)
	assert(not vehicle.is_thrown_impact_armed)

	vehicle.linear_velocity = Vector3(20.0, 0.0, 0.0)
	vehicle.arm_thrown_impact(20.0, source)
	assert(vehicle.is_thrown_impact_armed)
	assert(vehicle.contact_monitor)
	assert(vehicle.max_contacts_reported == 8)
	assert(is_equal_approx(vehicle.last_thrown_impact_speed, 20.0))

	vehicle._physics_process(0.0)
	assert(vehicle.is_thrown_impact_armed)

	vehicle.linear_velocity = Vector3(5.0, 0.0, 0.0)
	vehicle._physics_process(0.0)
	assert(vehicle.is_thrown_impact_armed)
	vehicle._physics_process(0.0)
	assert(not vehicle.is_thrown_impact_armed)
	assert(is_equal_approx(vehicle.last_thrown_impact_speed, 0.0))

	vehicle.free()
	source.free()
	explosion_controller.free()
	print("PASS: Vehicle-owned thrown-impact tracking")
	quit()

extends SceneTree

var released_vehicle: RigidBody3D
var release_speed := -1.0
var throw_charge_visible := true


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var vehicle_parent := Node3D.new()
	vehicle_parent.name = "Vehicles"
	root.add_child(vehicle_parent)

	var player_body := CharacterBody3D.new()
	root.add_child(player_body)
	var camera := Camera3D.new()
	player_body.add_child(camera)
	var interactor := PlayerVehicleInteractor.new()
	player_body.add_child(interactor)
	interactor.setup(player_body, camera)
	interactor.vehicle_released.connect(_on_vehicle_released)
	interactor.throw_charge_changed.connect(_on_throw_charge_changed)

	var vehicle := RigidBody3D.new()
	vehicle.collision_layer = 5
	vehicle.collision_mask = 6
	vehicle_parent.add_child(vehicle)

	interactor.held_vehicle = vehicle
	interactor.held_vehicle_parent = vehicle_parent
	interactor.held_vehicle_collision_layer = vehicle.collision_layer
	interactor.held_vehicle_collision_mask = vehicle.collision_mask
	interactor.is_charging_vehicle_throw = true
	interactor.vehicle_throw_hold_time = 0.1
	vehicle.reparent(player_body)
	vehicle.collision_layer = 0
	vehicle.collision_mask = 0
	vehicle.freeze = true

	interactor.drop_held_vehicle()
	assert(not interactor.has_held_vehicle())
	assert(not interactor.is_charging_throw())
	assert(is_equal_approx(interactor.get_throw_charge_percent(), 0.0))
	assert(not throw_charge_visible)
	assert(vehicle.get_parent() == vehicle_parent)
	assert(vehicle.collision_layer == 5)
	assert(vehicle.collision_mask == 6)
	assert(not vehicle.freeze)
	assert(released_vehicle == vehicle)
	assert(is_equal_approx(release_speed, 0.0))

	vehicle_parent.free()
	player_body.free()
	print("PASS: PlayerVehicleInteractor release cleanup")
	quit()


func _on_vehicle_released(vehicle: RigidBody3D, speed: float) -> void:
	released_vehicle = vehicle
	release_speed = speed


func _on_throw_charge_changed(is_visible: bool, _hold: float, _maximum: float) -> void:
	throw_charge_visible = is_visible

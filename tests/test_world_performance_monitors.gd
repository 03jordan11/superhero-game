extends SceneTree

const CITY = preload("res://scripts/ui-scripts/city_performance_monitor.gd")
const CROWD = preload("res://scripts/ui-scripts/civilian_crowd_performance_monitor.gd")
const VEHICLES = preload("res://scripts/ui-scripts/vehicle_performance_monitor.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	# This test's fixed 17-car fixture is the gallery, independent of ambient traffic.
	main.get_node("SuperCity/TrafficManager").traffic_enabled = false
	root.add_child(main)
	current_scene = main
	var monitors := main.get_node("PerformanceMonitors")
	var city := monitors.get_node("CityPerformanceMonitor")
	var crowd := monitors.get_node("CivilianCrowdPerformanceMonitor")
	var vehicles := monitors.get_node("VehiclePerformanceMonitor")
	for monitor in [city, crowd, vehicles]: monitor.set_process(false)
	await create_timer(1.0).timeout
	var city_data: Dictionary = city.collect_sample()
	var crowd_data: Dictionary = crowd.collect_sample()
	var vehicle_data: Dictionary = vehicles.collect_sample()
	assert(city_data.city_present and city_data.routes.valid)
	assert(city_data.city_cpu_timings.walkable_area_check.calls > 0)
	assert(crowd_data.present and crowd_data.full + crowd_data.capsules > 0)
	assert(crowd_data.cpu_timings.population_manager.calls > 0)
	assert(crowd_data.cpu_timings.spawn_attempt.calls > 0)
	assert(vehicle_data.vehicles == 17 and vehicle_data.frozen == 17)
	assert(vehicle_data.cpu_timings.vehicle_physics.calls > 0)
	assert(city.collect_sample().city_cpu_timings.is_empty())
	assert(crowd.collect_sample().cpu_timings.is_empty())
	assert(vehicles.collect_sample().cpu_timings.is_empty())
	assert(CITY.begin(main.get_node("Player")) == 0)
	assert(CROWD.begin(main.get_node("Player")) == 0)
	# Aggregate timings must continue to include a carried vehicle.
	var car: Vehicle
	for node in main.get_node("Vehicles").get_children():
		if node is Vehicle:
			car = node
			break
	var original_parent := car.get_parent()
	car.reparent(main.get_node("Player"))
	assert(VEHICLES.begin(car) > 0)
	assert(vehicles.collect_sample().carried == 1)
	car.reparent(original_parent)
	for monitor in [city, crowd, vehicles]: monitor.enabled = false
	assert(CITY.begin(main.get_node("SuperCity/CityPedestrianRoutes")) == 0)
	assert(CROWD.begin(main.get_node("SuperCity/CivilianCrowd")) == 0)
	assert(VEHICLES.begin(car) == 0)
	vehicles.enabled = true
	car._physics_process(0.0)
	assert(vehicles.collect_sample().cpu_timings.vehicle_physics.calls == 1)
	assert(CROWD.begin(main.get_node("SuperCity/CivilianCrowd")) == 0)
	main.free()
	assert(VEHICLES.begin(null) == 0)
	assert(CITY.begin(null) == 0)
	assert(CROWD.begin(null) == 0)
	print("PASS: World monitor sampling, scope, reset, independent toggles, carried vehicles and teardown")
	quit()

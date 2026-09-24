extends SceneTree
const STREETS = preload("res://scripts/current_street_layout.gd")
const LIGHTS = preload("res://scripts/city_night_lights.gd")

func _initialize() -> void:
	var city := Node3D.new()
	var roads := Node3D.new()
	roads.name = "Roads"
	city.add_child(roads)
	var road = preload("res://assets/super-city/modular-roads/road_module.gd").new()
	road.length_m = 144.0
	road.width_m = 20
	roads.add_child(road)
	var before := LIGHTS.build_fixture_layout(STREETS.collect(city),72)
	assert(before.size() == 4, "144 m street should have two supported lamps per side")
	road.position = Vector3(400,2,-300)
	road.rotation.y = PI / 2
	var after := LIGHTS.build_fixture_layout(STREETS.collect(city),72)
	assert(after.size() == 4, "Moved/rotated road retains coverage")
	for lamp in after:
		var p: Vector3 = lamp.transform.origin
		assert(p.x>320 and p.x<480 and p.z>-315 and p.z<-285, "Lamps must follow the moved road, not old coordinates")
		assert(is_equal_approx(p.y,2.03), "Lamp bases must follow sidewalk height")
	road.visible = false
	assert(LIGHTS.build_fixture_layout(STREETS.collect(city),72).is_empty(), "Hidden/removed street must not retain lamps")
	city.free()
	print("CURRENT_STREETS: moved, rotated, raised and removed road placement PASS")
	quit()

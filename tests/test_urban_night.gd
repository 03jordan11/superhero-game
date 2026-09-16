extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var env:=WorldEnvironment.new(); env.name="Daylight"; world.add_child(env)
	for label in ["Sun","Moon"]:
		var light:=DirectionalLight3D.new(); light.name=label; world.add_child(light)
	var clock: Node=load("res://scripts/day_night_cycle.gd").new(); clock.cycle_running=false; world.add_child(clock); clock.set_time(0)
	assert(clock.star_intensity<=.2 and clock.star_density<=.1 and clock.milky_way_intensity==0)
	assert(clock._environment.glow_intensity<.25 and is_equal_approx(clock._environment.glow_hdr_threshold,1.8))
	assert(clock._environment.fog_density>.0003 and clock._environment.fog_density<.001)
	assert(clock._environment.ambient_light_energy>=.25,"Keep nearby/player readability")
	var building: StaticBody3D=load("res://assets/generated-buildings/commercial/commercial_skyscraper_02.tscn").instantiate()
	world.add_child(building)
	await process_frame
	await process_frame
	for material in building._night_materials:
		assert(material is StandardMaterial3D and material.emission_on_uv2)
		assert(is_equal_approx(material.emission_energy_multiplier,2.0),"Late spawn must use original emission")
	clock.set_time(12)
	for material in building._night_materials: assert(material.emission_energy_multiplier==0)
	clock.set_time(0)
	for material in building._night_materials: assert(material.emission_energy_multiplier==2)
	world.free()
	# Inspect nearby pools against actual layout, without unrelated city simulation.
	world=Node3D.new(); root.add_child(world)
	var camera:=Camera3D.new(); camera.position=Vector3(-1380,3,318); world.add_child(camera); camera.make_current()
	var lighting: Node3D=load("res://scripts/city_night_lights.gd").new(); world.add_child(lighting)
	lighting._set_night(1)
	assert(lighting._frontage_lights.size()==24 and lighting._lights.size()==96)
	assert(lighting.frontages.size()==702,"Both doors of all 351 commercial placements")
	var active:=0; var intersections:=0
	for fixture in lighting.fixtures:
		if fixture.get("intersection",false): intersections+=1
	for light in lighting._frontage_lights:
		assert(not light.shadow_enabled)
		if light.visible: active+=1
	assert(active>0 and active<=24 and intersections>40)
	camera.position.y=500; lighting._select_lights()
	for light in lighting._frontage_lights: assert(not light.visible,"Do not spend frontage lights during high flight")
	lighting._set_night(0)
	for light in lighting._lights: assert(not light.visible)
	world.free()
	print("URBAN_NIGHT_PASS: native seeded emissions, sky/haze/bloom preserved, late spawn/daylight, and bounded entrance/intersection pools")
	quit()

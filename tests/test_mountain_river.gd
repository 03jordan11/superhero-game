extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		if failures<30:push_error(message)
func run() -> void:
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/mountain-river/report.json"))
	var baseline: Dictionary=report.source_hashes
	for file in ["scenes/waterfront.tscn","scenes/central_park.tscn"]:
		check(FileAccess.get_sha256("res://"+file)==baseline[file],"Unchanged city/park/traffic/pedestrian source: "+file)
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for child in main.get_children():
		if child.name not in ["SuperCity","MountainRiver"]:child.free()
	var city := main.get_node("SuperCity")
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:city.get_node(label).free()
	root.add_child(main); current_scene=main
	await physics_frame;await physics_frame
	var river:=main.get_node("MountainRiver")
	check(not city.has_node("MountainRiver"),"Extension is a Main sibling, not part of the city")
	check(city.get_node("Waterfront/Water/River").visible,"City owns the updated curved urban water")
	check(not city.get_node("Waterfront/Riverbanks/RiverFoam").visible,"Stepped edge foam hidden")
	for wall in city.get_node("Waterfront/Riverbanks").get_children():
		if str(wall.name).begins_with("QuayWall"):
			if wall.position.z<799.9:
				check(not wall.visible,"Old river wall hidden")
				for shape in wall.find_children("*","CollisionShape3D",true,false):check(shape.disabled,"Old jagged collision disabled")
			else:check(wall.visible,"Harbor sea wall preserved")
	for path in ["CityLife/Highway/PinePassMountains","CityLife/Highway/NorthernGround","CoastalRegion/Landscape/CoastalTerrain"]:
		check(city.get_node(path).mesh.resource_path.begins_with("res://assets/mountain-river/"),"Main uses carved "+path)
	var space:=main.get_world_3d().direct_space_state
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	var samples:=0
	for i in report.river_rows.size()-1:
		var a: Array=report.river_rows[i];var b: Array=report.river_rows[i+1]
		if b[0]>-1000:continue # Urban geometry is covered by test_river_mouth.gd.
		var z: float=(a[0]+b[0])*.5;var x: float=(a[1]+b[1])*.5;var y: float=(a[2]+b[2])*.5;var width: float=(a[3]+b[3])*.5
		var crossing:=false
		for crossing_z in layout.crossings:
			if absf(z-crossing_z)<43:crossing=true
		if z>=-1000:
			var old: Array=layout.river_rects[clampi(int((z+1000)/40),0,44)]
			check(x-width>=old[0]-.01 and x+width<=old[0]+old[2]+.01,"Smoothed channel stays inside existing river footprint at "+str(z))
		if crossing:continue
		if z>=-1000:
			var old: Array=layout.river_rects[clampi(int((z+1000)/40),0,44)]
			for side in [-1,1]:
				var old_x: float=old[0] if side==-1 else old[0]+old[2]
				var p:=Vector3((old_x+x+side*width)*.5,4,z)
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*8))
				check(not hit.is_empty() and absf(hit.position.y-.03)<.04,"New curved promenade is walkable: "+str(p))
		for side in [-.7,0,.7]:
			var p:=Vector3(x+side*width,y+2,z)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*25))
			check(not hit.is_empty() and hit.position.y<y-4,"No invisible terrain over river; submerged floor at "+str(p))
			samples+=1
	# Banks face into the water and prevent walking through the cut terrain.
	for p in [Vector3(190,-3,-1000),Vector3(210,17,-2590)]:
		for side in [-1,1]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.RIGHT*side*100))
			check(not hit.is_empty(),"Solid bank faces into river at "+str(p))
	for z in layout.crossings:
		var r: Array=layout.river_curve_rows[clampi(int((float(z)+1000)/10),0,180)]
		var p:=Vector3((r[1]+r[2])*.5,6,z)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*12))
		check(not hit.is_empty() and absf(hit.position.y-.03)<.1,"Vehicle bridge preserved: "+str(z))
	var clock:=city.get_node("DayNightCycle");clock.cycle_running=false
	clock.set_time(0);check(float(river._water.get_shader_parameter("night_amount"))>.9,"Night water synchronized")
	clock.set_time(12);check(float(river._water.get_shader_parameter("night_amount"))<.1,"Day water synchronized")
	var elapsed: float=river._elapsed;paused=true;await process_frame;await process_frame
	check(river._elapsed==elapsed,"Pause freezes river motion");paused=false
	print("Mountain river: %d channel rays, %d failures"%[samples,failures])
	main.free();quit(0 if failures==0 else 1)

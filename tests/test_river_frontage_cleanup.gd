extends SceneTree
var failures:=0
var probes:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func run() -> void:
	create_timer(60).timeout.connect(func():push_error("River cleanup validation timed out");quit(1))
	var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/river-cleanup/cleanup.json"))
	var city:Node3D=load("res://scenes/super_city.tscn").instantiate()
	for path:String in audit.preserved_road_paths:check(city.has_node(path),"User road retained: "+path)
	for path:String in audit.removed_bridge_paths:check(not city.has_node(path),"Bridge remnant removed: "+path)
	var holder:=Node3D.new();root.add_child(holder)
	for label in ["Ground","Roads","Sidewalks","RiverFrontage"]:
		var node:=city.get_node(label);city.remove_child(node);holder.add_child(node)
	city.free();await physics_frame;await physics_frame
	var space:=holder.get_world_3d().direct_space_state
	for p:Array in audit.exposed_ground_samples:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p[0],.7,p[1]),Vector3(p[0],-.3,p[1])))
		check(not hit.is_empty() and absf(hit.position.y)<.001,"Ground fills exposed hole: "+str(p));probes+=1
	var quay:MeshInstance3D=holder.get_node("RiverFrontage/Quay")
	var arrays:=quay.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size()/3==audit.stats.quay_triangles,"Clean promenade geometry count")
	for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var i:=clampi(floori((p.z+1000)/10),0,audit.river_rows.size()-2)
		var a:Array=audit.river_rows[i];var b:Array=audit.river_rows[i+1];var t:=clampf((p.z-a[0])/10,0,1)
		var left:=lerpf(a[1],b[1],t);var right:=lerpf(a[2],b[2],t)
		check((p.x>=left-12.001 and p.x<=left+.001) or (p.x>=right-.001 and p.x<=right+12.001),"No stray promenade strip or bridge sidewalk")
	for i in audit.river_rows.size()-1:
		var a:Array=audit.river_rows[i];var b:Array=audit.river_rows[i+1]
		var z:float=(a[0]+b[0])*.5;var left:float=(a[1]+b[1])*.5;var right:float=(a[2]+b[2])*.5
		for x:float in [left-6,right+6]:
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,1,z),Vector3(x,-.2,z)))
			check(not hit.is_empty() and absf(hit.position.y-.03)<.001,"Continuous riverside walkway: "+str(Vector2(x,z)));probes+=1
		for t:float in [.05,.25,.5,.75,.95]:
			var x:=lerpf(left,right,t)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,2,z),Vector3(x,-2,z)))
			check(hit.is_empty(),"River remains open without decks, supports or land fill: "+str(Vector2(x,z)));probes+=1
	print("RIVER_FRONTAGE_CLEANUP: %d preserved roads; %d surface probes; %d failures"%[audit.preserved_road_paths.size(),probes,failures])
	holder.free();quit(1 if failures else 0)

extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for monitor in main.get_node("PerformanceMonitors").get_children(): monitor.enabled=false
	root.add_child(main)
	var city=main.get_node("SuperCity")
	for node in city.find_children("*","Node",true,false):
		check(not "bench" in str(node.name).to_lower(),"No outdoor bench geometry or collision remains: "+str(node.get_path()))
	var places: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city-life/placements.json"))
	check(not places.counts.has("Benches"),"Removed category absent from placement counts")
	for prop in places.props: check(prop.kind!="Benches","Removed benches absent from placement records")
	var group=city.get_node("Waterfront/Riverbanks")
	var rail: MeshInstance3D=group.get_node("RiverbankRailings")
	check(not rail.is_visible_in_tree(),"Main retains its previous hidden riverbank railing state")
	check(rail.mesh.get_surface_count()==1,"One material surface for the entire riverbank railing")
	check(rail.mesh.get_faces().size()/3==496,"Four triangles per authored railing run")
	check(rail.mesh.get_aabb().size.y<1.2,"Thin railing follows the authored height")
	check(rail.find_children("*","CollisionObject3D",true,false).is_empty(),"Cutout panels add no invisible collision wall")
	for node in group.find_children("*","MeshInstance3D",true,false):
		check(not str(node.name).begins_with("Railing"),"Individual bars/posts removed")
	var mat:=rail.mesh.surface_get_material(0) as StandardMaterial3D
	check(mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"Holes use opaque cutouts, not blended transparency")
	check(mat.cull_mode==BaseMaterial3D.CULL_DISABLED,"Railing visible from both banks")
	var image:=mat.albedo_texture.get_image()
	check(image.get_pixel(512,128).a<0.01 and image.get_pixel(512,4).a>0.99,"Texture has open gaps and an opaque top rail")
	var waterfront: Node3D=load("res://scenes/waterfront.tscn").instantiate()
	check(waterfront.get_node("Riverbanks/RiverbankRailings").visible,"Standalone waterfront retains its visible rails")
	# Preserve span metadata for the generator's one-mesh authoring path.
	check(waterfront.get_node("Riverbanks").get_children().filter(func(n):return n.has_meta("railing_length")).size()==124,"All authored rail spans survive for regeneration")
	waterfront.free()
	main.free()
	print("Benches and railings: ",failures," failures")
	quit(1 if failures else 0)

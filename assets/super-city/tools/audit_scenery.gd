extends SceneTree
## Static authored geometry inventory. These are not frame draw calls or GPU timings.
const PATHS := ["Waterfront/Riverbanks","Waterfront/Harbor","Waterfront/Boats","Roads",
	"CityLife/Benches","CityLife/Baseball","CityLife/Blimp","CityLife/Highway","NightLights"]
var histogram := {}
func _initialize() -> void: run.call_deferred()
func count(node: Node) -> Dictionary:
	var data := {"surfaces":0,"triangles":0,"mesh_nodes":0,"labels":0,"lights":0,"visible_surfaces":0,"visible_triangles":0}
	if "Forest" in str(node.name): return data # Forest originals/proxies already handled.
	var mesh: Mesh
	var instances := 1
	if node is MeshInstance3D: mesh=node.mesh
	if node is MultiMeshInstance3D and node.multimesh!=null:
		mesh=node.multimesh.mesh
		instances=node.multimesh.instance_count
	if mesh!=null:
		data.mesh_nodes=1
		data.surfaces=mesh.get_surface_count()
		data.triangles=mesh.get_faces().size()/3*instances
		if node.is_visible_in_tree():
			data.visible_surfaces=data.surfaces
			data.visible_triangles=data.triangles
		var stem:=str(node.name).rstrip("0123456789")
		if not histogram.has(stem): histogram[stem]={"meshes":0,"triangles":0}
		histogram[stem].meshes+=1
		histogram[stem].triangles+=data.triangles
	if node is Label3D: data.labels=1
	if node is Light3D: data.lights=1
	for child in node.get_children():
		var sub:=count(child)
		for key in data: data[key]+=sub[key]
	return data
func run() -> void:
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for monitor in main.get_node("PerformanceMonitors").get_children(): monitor.enabled=false
	root.add_child(main)
	var rows:=[]
	for path in PATHS:
		if not main.has_node("SuperCity/"+path): continue
		histogram={}
		var stats:=count(main.get_node("SuperCity/"+path))
		rows.append({"path":path,"geometry":stats,"parts":histogram.duplicate(true)})
		print(path,": ",stats)
	var file:=FileAccess.open("res://assets/super-city/regional_proxies/scenery_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Stored geometry includes hidden nodes and every MultiMesh instance. visible_* excludes nodes hidden in the scene tree at startup, but does not test camera/frustum/occlusion or distance; these are not frame draw calls. Forests omitted because they already have chunks.","categories":rows},"\t"))
	main.free()
	quit()

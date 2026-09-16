extends SceneTree
const OUT = "res://assets/mountain-river/"
var scene: Node3D
var meshes := {}
var mats := {}
var data: Dictionary

func _initialize() -> void: run.call_deferred()
func run() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/river_mountains/build.json"))
	DirAccess.make_dir_recursive_absolute(OUT+"meshes")
	for key in data.terrain:
		var d: Dictionary = data.terrain[key]
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in d.vertices.size():
			var c: Array = d.colors[i]
			st.set_color(Color(c[0],c[1],c[2],c[3])); st.add_vertex(vec(d.vertices[i]))
		st.generate_normals()
		var mesh := st.commit()
		ResourceSaver.save(mesh,OUT+"meshes/"+key+".res",ResourceSaver.FLAG_COMPRESS)
		ResourceSaver.save(mesh.create_trimesh_shape(),OUT+"meshes/"+key+"_collision.res",ResourceSaver.FLAG_COMPRESS)
	scene = Node3D.new(); scene.name = "MountainRiver"
	scene.set_script(load("res://scripts/mountain_river.gd"))
	mats.water = ShaderMaterial.new(); mats.water.shader = load("res://assets/waterfront/water.gdshader")
	mats.water.set_shader_parameter("river",true)
	mats.quay = material(Color("888a81")); mats.stone = material(Color("596269"))
	mats.rock = material(Color.WHITE); mats.rock.vertex_color_use_as_albedo = true; mats.rock.vertex_color_is_srgb = true
	mats.bed = material(Color("434d42"))
	mats.rail = ShaderMaterial.new(); mats.rail.shader = load(OUT+"railing.gdshader")
	for key in ["Water","Quay","Stone","Rock","Bed","Rail"]:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); meshes[key]=st
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	var distance := 0.0
	for i in data.rows.size()-1:
		var a: Array = data.rows[i]; var b: Array = data.rows[i+1]
		var al := Vector3(a[1]-a[3],a[2],a[0]); var ar := Vector3(a[1]+a[3],a[2],a[0])
		var bl := Vector3(b[1]-b[3],b[2],b[0]); var br := Vector3(b[1]+b[3],b[2],b[0])
		quad("Water",al,ar,br,bl)
		if b[0] <= -1000:
			quad("Bed",al+Vector3.DOWN*8,ar+Vector3.DOWN*8,br+Vector3.DOWN*8,bl+Vector3.DOWN*8)
		else:
			var old: Array = layout.river_rects[clampi(int(((a[0]+b[0])*.5+1000)/40),0,44)]
			for side in [-1,1]:
				var p := al if side == -1 else ar; var q := bl if side == -1 else br
				var old_x: float = old[0] if side == -1 else old[0]+old[2]
				p.y=.03; q.y=.03
				var outer_p := Vector3(old_x,.03,p.z); var outer_q := Vector3(old_x,.03,q.z)
				if side == -1: quad("Quay",outer_p,p,q,outer_q)
				else: quad("Quay",p,outer_p,outer_q,q)
				var low_p := Vector3(p.x,-12,p.z); var low_q := Vector3(q.x,-12,q.z)
				if side == -1: quad("Stone",p,low_p,low_q,q)
				else: quad("Stone",low_p,p,q,low_q)
				# A texture-cut rail uses two triangles per span, with clear gaps at road bridges.
				var crossing := false
				for z in layout.crossings:
					if absf((p.z+q.z)*.5-z)<43: crossing=true
				if not crossing:
					var st: SurfaceTool = meshes.Rail
					var pp := p+Vector3(side*.18,.15,0); var qq := q+Vector3(side*.18,.15,0)
					var d := p.distance_to(q)
					tri_uv(st,pp,pp+Vector3.UP*1.1,qq+Vector3.UP*1.1,Vector2(distance,0),Vector2(distance,1.1),Vector2(distance+d,1.1))
					tri_uv(st,pp,qq+Vector3.UP*1.1,qq,Vector2(distance,0),Vector2(distance+d,1.1),Vector2(distance+d,0))
			distance += al.distance_to(bl)
	for edge in data.bank_edges:
		var a := vec(edge.a); var b := vec(edge.b)
		var c := Vector3(a.x,edge.bed_a,a.z); var d := Vector3(b.x,edge.bed_b,b.z)
		# Earth along the lowland reach, exposed gray rock higher in the gorge.
		var color := Color("58644a").lerp(Color("757969"),clampf((a.y+b.y)*.01,0,1))
		if edge.side == -1: quad("Rock",a,c,d,b,color)
		else: quad("Rock",c,a,b,d,color)
	for key in meshes:
		var st: SurfaceTool=meshes[key]; st.generate_normals()
		var mesh := st.commit(); var node := MeshInstance3D.new(); node.name=key; node.mesh=mesh
		node.material_override=mats[key.to_lower()]; scene.add_child(node); node.owner=scene
		ResourceSaver.save(mesh,OUT+"meshes/"+key.to_lower()+".res",ResourceSaver.FLAG_COMPRESS)
		if key not in ["Water","Rail"]:
			var body := StaticBody3D.new(); body.name="Solid"; node.add_child(body);body.owner=scene
			var shape := CollisionShape3D.new(); shape.name="CollisionShape3D";shape.shape=mesh.create_trimesh_shape();body.add_child(shape);shape.owner=scene
		print("River ",key,": ",mesh.get_faces().size()/3," triangles")
	var packed := PackedScene.new(); assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/mountain_river.tscn")==OK)
	scene.free(); quit()

func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new();m.albedo_color=color;m.roughness=.87;return m
func tri_uv(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,u: Vector2,v: Vector2,w: Vector2) -> void:
	st.set_color(Color.WHITE)
	st.set_uv(u);st.add_vertex(a);st.set_uv(v);st.add_vertex(b);st.set_uv(w);st.add_vertex(c)
func quad(key: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color:=Color.WHITE) -> void:
	var st: SurfaceTool=meshes[key];st.set_color(color)
	for v in [a,b,c,a,c,d]:st.add_vertex(v)

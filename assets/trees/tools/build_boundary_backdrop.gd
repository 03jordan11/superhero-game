extends SceneTree
## Offline low-poly landscape painting and a single-surface curtain around the cut.
const OUT := "res://assets/trees/backdrop/"
const CLIP = preload("res://assets/trees/tools/forest_boundary_clip.gd")
const LAND = preload("res://scripts/coastal_landscape.gd")
const HEIGHT := 1000.0
const BASE := -60.0

func _initialize() -> void: run.call_deferred()

func noise_at(x: float, seed: float) -> float:
	var cell := floorf(x)
	var a := fposmod(sin(cell*127.1+seed*311.7)*43758.5453,1.0)
	var b := fposmod(sin((cell+1.0)*127.1+seed*311.7)*43758.5453,1.0)
	return lerpf(a,b,smoothstep(0,1,fposmod(x,1.0)))

func painting() -> Image:
	var image := Image.create(4096,512,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in image.get_width():
		var u := float(x)/float(image.get_width()-1)
		var ridge := 340.0+noise_at(u*24.0,1)*320.0+noise_at(u*69.0,7)*100.0
		var middle := 140.0+noise_at(u*43.0,2)*240.0+noise_at(u*93.0,6)*45.0
		var forest := 35.0+noise_at(u*87.0,3)*90.0
		var crown := (1.0-absf(fposmod(u*1900.0,1.0)*2.0-1.0))*(9.0+noise_at(u*1900,9)*24.0)
		for y in image.get_height():
			var elevation := lerpf(HEIGHT,BASE,float(y)/float(image.get_height()-1))
			if elevation > ridge: continue
			var color := Color("738a8a")
			if elevation <= middle:
				color = Color("51694f").lerp(Color("637959"),noise_at(u*57.0+elevation/180.0,4)*0.6)
			if elevation <= forest+crown:
				color = Color("344c30").lerp(Color("50663d"),noise_at(u*860.0,5)*0.55)
			# Match a grassy base rather than presenting a dark straight fence.
			color = color.lerp(Color("63774c"),1.0-smoothstep(0,65,elevation))
			image.set_pixel(x,y,color)
	return image

func polygon_from_planes(planes: Array[Plane]) -> Array[Vector2]:
	var polygon: Array[Vector2] = [Vector2(-50000,-50000),Vector2(50000,-50000),Vector2(50000,50000),Vector2(-50000,50000)]
	for plane in planes:
		var result: Array[Vector2] = []
		var normal := Vector2(plane.normal.x,plane.normal.z)
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i+1)%polygon.size()]
			var da := normal.dot(a)-plane.d
			var db := normal.dot(b)-plane.d
			if da <= 0: result.append(a)
			if (da <= 0) != (db <= 0): result.append(a.lerp(b,da/(da-db)))
		polygon = result
	return polygon

func wall_vertex(point: Vector2, top: bool) -> Vector3:
	var coast_gap := LAND.coast_z(point.x)-point.y
	var taper := smoothstep(0,600,coast_gap)
	var ground := maxf(-0.09,LAND.height_at(point.x,point.y))
	return Vector3(point.x, ground+HEIGHT*taper if top else BASE, point.y)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var painted := Image.load_from_file(OUT+"landscape.png") if "--use-existing-texture" in OS.get_cmdline_user_args() else painting()
	assert(painted != null and not painted.is_empty())
	if "--use-existing-texture" not in OS.get_cmdline_user_args():
		assert(painted.save_png(OUT+"landscape.png")==OK)
	painted.generate_mipmaps()
	var texture := ImageTexture.create_from_image(painted)
	assert(ResourceSaver.save(texture,OUT+"landscape.res",ResourceSaver.FLAG_COMPRESS)==OK)
	texture.take_over_path(OUT+"landscape.res")
	var polygon := polygon_from_planes(CLIP.saved_planes())
	# Put the UV seam in the omitted open-water arc, never on a visible wall.
	var start := 0
	for i in polygon.size():
		if polygon[i].y > polygon[start].y: start = i
	var ordered: Array[Vector2] = []
	for i in polygon.size(): ordered.append(polygon[(start+i)%polygon.size()])
	polygon = ordered
	var segments := []
	var distance := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var steps := maxi(1,ceili(a.distance_to(b)/50.0))
		for j in steps:
			var p := a.lerp(b,float(j)/steps)
			var q := a.lerp(b,float(j+1)/steps)
			# Leave the bay and open sea unobstructed. Fade each end into the shoreline.
			if p.y >= LAND.coast_z(p.x) and q.y >= LAND.coast_z(q.x): continue
			var length := p.distance_to(q)
			segments.append([p,q,distance,distance+length])
			distance += length
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in segments:
		var p: Vector2 = segment[0]
		var q: Vector2 = segment[1]
		var u0: float = segment[2]/distance
		var u1: float = segment[3]/distance
		var vertices := [wall_vertex(p,false),wall_vertex(p,true),wall_vertex(q,true),wall_vertex(p,false),wall_vertex(q,true),wall_vertex(q,false)]
		var uvs := [Vector2(u0,1),Vector2(u0,0),Vector2(u1,0),Vector2(u0,1),Vector2(u1,0),Vector2(u1,1)]
		for i in 6:
			surface.set_normal(Vector3.UP)
			surface.set_uv(uvs[i])
			surface.set_uv2(Vector2(wall_vertex(p if i in [0,1,3] else q,true).y,BASE))
			surface.add_vertex(vertices[i])
	surface.index()
	var mesh := surface.commit()
	assert(ResourceSaver.save(mesh,OUT+"landscape_wall.res",ResourceSaver.FLAG_COMPRESS)==OK)
	mesh.take_over_path(OUT+"landscape_wall.res")
	var material := ShaderMaterial.new()
	material.shader = load(OUT+"landscape.gdshader")
	material.set_shader_parameter("landscape",texture)
	material.set_shader_parameter("night_amount",0.0)
	material.set_shader_parameter("night_tint",Color(0.08,0.13,0.17))
	assert(ResourceSaver.save(material,OUT+"landscape_material.tres")==OK)
	material.take_over_path(OUT+"landscape_material.tres")
	var wall := MeshInstance3D.new()
	wall.name = "ForestBoundaryBackdrop"
	wall.mesh = mesh
	wall.material_override = material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	wall.ignore_occlusion_culling = true
	wall.set_script(load("res://scripts/forest_boundary_backdrop.gd"))
	var scene := PackedScene.new()
	assert(scene.pack(wall)==OK)
	assert(ResourceSaver.save(scene,OUT+"forest_boundary_backdrop.tscn")==OK)
	FileAccess.open(OUT+"audit.json",FileAccess.WRITE).store_string(JSON.stringify({"mesh_instances":1,"surfaces":mesh.get_surface_count(),"triangles":mesh.get_faces().size()/3,"wall_length_m":distance,"boundary_sha256":FileAccess.get_sha256(CLIP.CONFIG)},"\t"))
	print("BACKDROP: one mesh, ",mesh.get_surface_count()," surface, ",mesh.get_faces().size()/3," triangles")
	wall.free()
	quit()

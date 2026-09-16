extends "res://assets/generated-buildings/commercial/tools/generate_pack.gd"
const WORK := "res://artifacts/commercial_batch/"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(WORK + "before")
	var data := {"designs":get_designs(), "styles":STYLES, "meshes":{}, "textures":{}}
	for i in range(3,21):
		var slug := "commercial_skyscraper_%02d" % i
		var source := OUT + "meshes/" + slug + ".res"
		data.meshes[slug] = extract(load(source))
		DirAccess.copy_absolute(source, WORK + "before/" + slug + ".res")
		DirAccess.copy_absolute(OUT + slug + ".tscn", WORK + "before/" + slug + ".tscn")
	data.hvac = extract(load("res://assets/props/rooftop_hvac/rooftop_hvac.res"))
	FileAccess.open(WORK + "source.json", FileAccess.WRITE).store_string(JSON.stringify(data))
	print("BLENDER_SOURCE_EXPORTED: 18 building meshes and stock HVAC")
	quit()
func extract(mesh: Mesh) -> Array:
	var output := []
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var mat: StandardMaterial3D = mesh.surface_get_material(s)
		var row := {"material":mat.resource_path, "vertices":[], "uv":[], "colors":[], "indices":[], "texture":""}
		for v: Vector3 in a[Mesh.ARRAY_VERTEX]: row.vertices.append([v.x,v.y,v.z])
		for uv: Vector2 in a[Mesh.ARRAY_TEX_UV]: row.uv.append([uv.x,uv.y])
		if a[Mesh.ARRAY_COLOR] != null:
			for c: Color in a[Mesh.ARRAY_COLOR]: row.colors.append([c.r,c.g,c.b,c.a])
		if a[Mesh.ARRAY_INDEX] != null:
			for idx: int in a[Mesh.ARRAY_INDEX]: row.indices.append(idx)
		if mat.albedo_texture != null:
			var img := mat.albedo_texture.get_image()
			if img.is_compressed(): img.decompress()
			row.texture = WORK + mat.resource_path.get_file().get_basename() + "_albedo.png"
			img.save_png(row.texture)
		row.albedo = [mat.albedo_color.r,mat.albedo_color.g,mat.albedo_color.b,mat.albedo_color.a]
		output.append(row)
	return output

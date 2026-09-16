extends "res://assets/generated-buildings/commercial/tools/generate_pack.gd"
## Rebuild only asset 02; reuse the existing hospital HVAC without modifying it.
const SLUG := "commercial_skyscraper_02"
const HVAC := "res://assets/props/rooftop_hvac/rooftop_hvac.tscn"

func _initialize() -> void:
	revise.call_deferred()

func revise() -> void:
	materials.solid = load(OUT + "materials/solid.tres")
	materials.signs_and_doors = load(OUT + "materials/signs_and_doors.tres")
	materials.lobby = load(OUT + "materials/lobby.tres")
	# One editable mask fits both original facade tiles. Keep steel ribs dark.
	var mask := Image.create(64, 64, false, Image.FORMAT_RGB8)
	mask.fill(Color.BLACK)
	for y in 64:
		for x in 64:
			var lit := ((int(x / 16) * 3 + int(y / 16) * 5) % 7) < 4
			if lit and x % 16 >= 2 and x % 16 < 14 and y % 16 >= 2 and y % 16 <= 14:
				mask.set_pixel(x, y, Color("ffd6a0"))
	assert(mask.save_png(OUT + "textures/" + SLUG + "_emission.png") == OK)
	mask.generate_mipmaps()
	var texture := ImageTexture.create_from_image(mask)
	save(texture, OUT + "textures/" + SLUG + "_emission.res")
	for style in ["dark_glass", "steel"]:
		var material: StandardMaterial3D = load(OUT + "materials/" + style + ".tres").duplicate()
		material.emission_enabled = true
		material.emission = Color.WHITE
		material.emission_texture = texture
		material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		material.emission_energy_multiplier = 0
		material.set_meta("glow_energy", 2.0)
		save(material, OUT + "materials/" + SLUG + "_" + style + ".tres")
		materials[style] = material

	surfaces.clear()
	# Flush lobby and tower replace the projecting 32 x 23 m podium.
	walls(30, 21, 0, 4.2, "lobby")
	walls(30, 21, 4.2, 103.4, "dark_glass")
	walls(30, 21, 103.4, 104, "trim")
	# Preserve the smaller upper tier and only its exposed terrace surfaces.
	horizontal(-15, -10.5, 15, -9, 104)
	horizontal(-15, 9, 15, 10.5, 104)
	horizontal(-15, -9, -13, 9, 104)
	horizontal(13, -9, 15, 9, 104)
	walls(26, 18, 104, 109.4, "steel")
	walls(26, 18, 109.4, 110, "trim")
	horizontal(-13, -9, 13, 9, 110)
	quad([Vector3(-15,0,-10.5), Vector3(-15,0,10.5), Vector3(15,0,10.5), Vector3(15,0,-10.5)], [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO], "roof", Vector3.DOWN)
	# Retain both existing entrance orientations; no tenant plaque.
	sign_quad(3.4, .08, 3.5, 21, Rect2(.5/256, 240.5/256, 63.0/256, 15.0/256))
	var mesh := ArrayMesh.new()
	for key in surfaces:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var data: Array = surfaces[key]
		arrays[Mesh.ARRAY_VERTEX] = data[0]
		arrays[Mesh.ARRAY_NORMAL] = data[1]
		arrays[Mesh.ARRAY_TEX_UV] = data[2]
		arrays[Mesh.ARRAY_COLOR] = data[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
	var body: StaticBody3D = load(OUT + SLUG + ".tscn").instantiate()
	body.set_script(load(OUT + SLUG + ".gd"))
	body.get_node("MeshInstance3D").mesh = mesh
	var collision: CollisionShape3D = body.get_node("CollisionShape3D")
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(30, 104, 21.04)
	collision.position = Vector3(0, 52, 0)
	for label in ["UpperTierCollision", "RooftopHVAC"]:
		var old := body.get_node_or_null(NodePath(label))
		if old != null:
			old.free()
	var upper := CollisionShape3D.new()
	upper.name = "UpperTierCollision"
	upper.shape = BoxShape3D.new()
	upper.shape.size = Vector3(26, 6, 18)
	upper.position.y = 107
	body.add_child(upper)
	upper.owner = body
	var hvac: StaticBody3D = load(HVAC).instantiate()
	hvac.name = "RooftopHVAC"
	hvac.position.y = 110
	body.add_child(hvac)
	hvac.owner = body
	var building_triangles := mesh.get_faces().size() / 3
	var equipment: Mesh = hvac.get_node("MeshInstance3D").mesh
	var hvac_triangles := equipment.get_faces().size() / 3
	assert(building_triangles + hvac_triangles <= 108)
	save(mesh, OUT + "meshes/" + SLUG + ".res")
	var packed := PackedScene.new()
	assert(packed.pack(body) == OK)
	save(packed, OUT + SLUG + ".tscn")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(OUT + "manifest.json"))
	var entry: Dictionary = catalog[1]
	entry.name = SLUG
	entry.width_m = 30
	entry.depth_m = mesh.get_aabb().size.z
	entry.height_m = 110 + equipment.get_aabb().end.y
	entry.roof_height_m = 110
	entry.building_triangles = building_triangles
	entry.hvac_triangles = hvac_triangles
	entry.triangles = building_triangles + hvac_triangles
	entry.surfaces = mesh.get_surface_count() + equipment.get_surface_count()
	entry.night_illumination = true
	FileAccess.open(OUT + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(catalog, "\t"))
	print("SKYSCRAPER_02_BUILT: ", building_triangles, " building + ", hvac_triangles, " HVAC = ", entry.triangles, " triangles; previous 108")
	body.free()
	quit()

func walls(width: float, depth: float, bottom: float, top: float, material: String) -> void:
	var ring := [Vector2(-width/2,-depth/2), Vector2(width/2,-depth/2), Vector2(width/2,depth/2), Vector2(-width/2,depth/2)]
	for i in 4:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i+1)%4]
		var u := maxf(1, roundf(a.distance_to(b)/2.7))/4
		var v := maxf(1, roundf((top-bottom)/3.8))/4
		quad([Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y)], [Vector2(0,v),Vector2(u,v),Vector2(u,0),Vector2.ZERO], material, Vector3(b.y-a.y,0,a.x-b.x).normalized())

func horizontal(x: float, z: float, xx: float, zz: float, y: float) -> void:
	quad([Vector3(x,y,z),Vector3(xx,y,z),Vector3(xx,y,zz),Vector3(x,y,zz)], [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO], "roof", Vector3.UP)

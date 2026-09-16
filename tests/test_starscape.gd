extends SceneTree
const CENTERS := [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
const RIGHTS := [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT,Vector3.LEFT]
const DOWNS := [Vector3.DOWN,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD,Vector3.DOWN,Vector3.DOWN]

func _initialize() -> void:
	assert(DisplayServer.get_name() != "headless", "Use the real renderer to inspect cube image data")
	var galaxy := load("res://assets/sky/custom_galaxy.res") as Cubemap
	var stars := load("res://assets/sky/custom_stars.res") as Cubemap
	assert(galaxy != null and stars != null)
	var decoded: Array[Image] = []
	for cube: Cubemap in [galaxy,stars]:
		assert(cube.get_layers() == 6 and cube.has_mipmaps())
		assert(cube.get_format() == Image.FORMAT_BPTC_RGBFU)
		assert(cube.get_width() == (1024 if cube == galaxy else 2048))
		for face in 6:
			var data := cube.get_layer_data(face)
			assert(data != null and data.get_mipmap_count() > 0)
			assert(data.decompress() == OK)
			if cube == galaxy: decoded.append(data)
	# Matching edge directions must have continuous galaxy colour on adjacent faces.
	var max_error := 0.0
	for face in 6:
		for edge in 4:
			for step in 17:
				var t := -0.94 + float(step)*1.88/16.0
				var uv := Vector2(-1 if edge == 0 else 1,t) if edge<2 else Vector2(t,-1 if edge==2 else 1)
				var d: Vector3 = CENTERS[face]+RIGHTS[face]*uv.x+DOWNS[face]*uv.y
				var a := sample_face(decoded[face],uv)
				for neighbor in 6:
					if neighbor == face or not is_equal_approx(d.dot(CENTERS[neighbor]),1.0): continue
					var b := sample_face(decoded[neighbor],Vector2(d.dot(RIGHTS[neighbor]),d.dot(DOWNS[neighbor])))
					max_error = maxf(max_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	assert(max_error < 0.015,"Galaxy cubemap edge discontinuity: %f" % max_error)
	print("STARSCAPE_TEST_PASS: 12 compressed HDR faces, mipmaps, edge continuity; max edge error ",max_error)
	quit()

func sample_face(data: Image, uv: Vector2) -> Color:
	var size := data.get_width()
	return data.get_pixel(clampi(int((uv.x*.5+.5)*size),0,size-1),clampi(int((uv.y*.5+.5)*size),0,size-1))

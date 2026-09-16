extends SceneTree
## Run with the real renderer (not --headless): dummy rendering drops layered data.
## Offline packing keeps the runtime to two compressed, mipmapped cube lookups.
func _initialize() -> void:
	assert(DisplayServer.get_name() != "headless", "Cubemap serialization needs the real renderer")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/starscape_bake/manifest.json"))
	for kind in ["galaxy", "stars"]:
		var size := int(manifest.galaxy_face_size if kind == "galaxy" else manifest.stars_face_size)
		var faces: Array[Image] = []
		for face in 6:
			var bytes := FileAccess.get_file_as_bytes("res://artifacts/starscape_bake/%s_%d.rgbh" % [kind,face])
			assert(bytes.size() == size*size*6)
			var data := Image.create_from_data(size,size,false,Image.FORMAT_RGBH,bytes)
			assert(data.generate_mipmaps() == OK)
			assert(data.compress(Image.COMPRESS_BPTC) == OK)
			assert(data.get_format() == Image.FORMAT_BPTC_RGBFU)
			faces.append(data)
		var cube := Cubemap.new()
		assert(cube.create_from_images(faces) == OK)
		assert(cube.get_layer_data(0) != null)
		cube.resource_name = "Original synthetic " + kind + " cubemap"
		assert(ResourceSaver.save(cube,"res://assets/sky/custom_%s.res" % kind) == OK)
		print("PACKED_CUBEMAP ",kind," ",size," pixels/face; ",faces[0].get_data_size()*6," GPU bytes")
	print("STARSCAPE_PACK_COMPLETE")
	quit()

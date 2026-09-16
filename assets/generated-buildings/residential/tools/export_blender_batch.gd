extends "res://assets/generated-buildings/commercial/tools/export_blender_batch.gd"
const RESIDENTIAL := "res://assets/generated-buildings/residential/"
const BATCH := "res://artifacts/residential_batch/"
func _initialize() -> void:
	var data := {"meshes":{},"hvac":extract(load("res://assets/props/rooftop_hvac/rooftop_hvac_lowpoly.res"))}
	for i in range(1,21):
		var slug := "residential_building_%02d"%i
		data.meshes[slug] = extract(load(RESIDENTIAL+"meshes/"+slug+".res"))
		DirAccess.copy_absolute(RESIDENTIAL+"meshes/"+slug+".res",BATCH+"before/"+slug+".res")
		DirAccess.copy_absolute(RESIDENTIAL+slug+".tscn",BATCH+"before/"+slug+".tscn")
	DirAccess.copy_absolute(RESIDENTIAL+"manifest.json",BATCH+"before/manifest.json")
	FileAccess.open(BATCH+"source.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("RESIDENTIAL_BLENDER_SOURCE: 20 original meshes + shared hospital HVAC")
	quit()

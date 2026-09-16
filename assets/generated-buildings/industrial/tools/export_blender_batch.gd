extends "res://assets/generated-buildings/commercial/tools/export_blender_batch.gd"
const INDUSTRIAL := "res://assets/generated-buildings/industrial/"
const BATCH := "res://artifacts/industrial_batch/"
func _initialize() -> void:
	var data := {"meshes":{},"hvac":extract(load("res://assets/props/rooftop_hvac/rooftop_hvac_lowpoly.res"))}
	for i in range(1,11):
		var slug := "industrial_building_%02d"%i
		data.meshes[slug] = extract(load(INDUSTRIAL+"meshes/"+slug+".res"))
		DirAccess.copy_absolute(INDUSTRIAL+"meshes/"+slug+".res",BATCH+"before/"+slug+".res")
		DirAccess.copy_absolute(INDUSTRIAL+slug+".tscn",BATCH+"before/"+slug+".tscn")
	DirAccess.copy_absolute(INDUSTRIAL+"manifest.json",BATCH+"before/manifest.json")
	FileAccess.open(BATCH+"source.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	print("INDUSTRIAL_BLENDER_SOURCE: 10 original meshes + shared hospital HVAC")
	quit()

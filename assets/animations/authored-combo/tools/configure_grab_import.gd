extends SceneTree
func _initialize() -> void:
	var path:="res://assets/animations/authored-combo/hero_combo.glb.import"
	var config:=ConfigFile.new()
	assert(config.load(path)==OK)
	var subresources: Dictionary=config.get_value("params","_subresources",{})
	var clips: Dictionary={}
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/authored-combo/grab_manifest.json"))
	for clip in manifest.clips:
		clips[clip.name]={"settings/loop_mode":1 if clip.loop else 0}
	var charge_path := "res://assets/animations/authored-combo/charge_punch_manifest.json"
	if FileAccess.file_exists(charge_path):
		var charge: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(charge_path))
		for clip in charge.clips:
			clips[clip.name]={"settings/loop_mode":1 if clip.loop else 0}
	subresources["animations"]=clips
	config.set_value("params","_subresources",subresources)
	assert(config.save(path)==OK)
	print("GRAB_IMPORT_CONFIGURED")
	quit()

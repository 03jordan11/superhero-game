@tool
extends Node3D
## Named, saved boolean properties in the Inspector, one per generated module.
@export_storage var district_id := "WestVillage"
@export var district_enabled := true:
	set(value):
		district_enabled = value
		_refresh()
@export var show_debug := true:
	set(value):
		show_debug = value
		_refresh()
@export_storage var enabled_routes: Dictionary = {}
@export_tool_button("Enable all routes") var enable_all_action = enable_all_routes
@export_tool_button("Disable all routes") var disable_all_action = disable_all_routes
var modules: Dictionary = {}

func enable_all_routes() -> void:
	for key in modules:
		if modules[key].district == district_id: enabled_routes[key] = true
	notify_property_list_changed()
	_refresh()

func disable_all_routes() -> void:
	for key in modules:
		if modules[key].district == district_id: enabled_routes[key] = false
	notify_property_list_changed()
	_refresh()

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/pedestrians/network.json"))
	if data is Dictionary: modules = data.get("modules",{})
	notify_property_list_changed()

func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"name":"Route Checkboxes","type":TYPE_NIL,"usage":PROPERTY_USAGE_GROUP,"hint_string":"routes/"}]
	var keys := modules.keys()
	keys.sort()
	for key in keys:
		if modules[key].district == district_id:
			list.append({"name":"routes/"+modules[key].label,"type":TYPE_BOOL,"usage":PROPERTY_USAGE_EDITOR})
	return list

func _get(property: StringName):
	if str(property).begins_with("routes/"):
		return bool(enabled_routes.get(district_id+"_"+str(property).trim_prefix("routes/"),false))
	return null

func _set(property: StringName, value) -> bool:
	if not str(property).begins_with("routes/"): return false
	enabled_routes[district_id+"_"+str(property).trim_prefix("routes/")] = bool(value)
	_refresh()
	return true

func _refresh() -> void:
	if is_inside_tree() and get_parent().has_method("schedule_rebuild"):
		get_parent().schedule_rebuild()

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["No route modules found for this district."]) if modules.is_empty() else PackedStringArray()

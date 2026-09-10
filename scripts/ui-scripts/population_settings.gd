extends VBoxContainer
## Shared by the main and pause menus; no city node paths or manager fields here.
@onready var _crowd: OptionButton = $CrowdRow/Dropdown
@onready var _vehicles: OptionButton = $VehicleRow/Dropdown
@onready var _distance: OptionButton = $DistanceRow/Dropdown
@onready var _save_status: Label = $SaveStatus
var _settings: Node

func _ready() -> void:
	_settings = get_node("/root/GameSettings")
	for dropdown in [_crowd, _vehicles, _distance]:
		for label in ["Low", "Medium", "High"]: dropdown.add_item(label)
		dropdown.item_selected.connect(_on_selected)
	_settings.population_settings_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_crowd.select(_settings.crowd_density)
	_vehicles.select(_settings.vehicle_density)
	_distance.select(_settings.population_view_distance)

func _on_selected(_index: int) -> void:
	var result: Error = _settings.set_population_settings(_crowd.selected, _vehicles.selected, _distance.selected)
	_save_status.visible = result != OK
	if result != OK: _save_status.text = "Applied, but could not save settings."

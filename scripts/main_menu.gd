extends Control

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DISPLAY_MODE_NAMES: Array[String] = ["Windowed", "Borderless Windowed", "Fullscreen"]

@onready var main_menu: VBoxContainer = $Center/Menu
@onready var settings_menu: VBoxContainer = $Center/SettingsMenu
@onready var display_mode_dropdown: OptionButton = $Center/SettingsMenu/DisplayModeRow/DisplayModeDropdown
@onready var resolution_dropdown: OptionButton = $Center/SettingsMenu/ResolutionRow/ResolutionDropdown


func _ready() -> void:
	for display_mode_name in DISPLAY_MODE_NAMES:
		display_mode_dropdown.add_item(display_mode_name)

	for resolution in RESOLUTIONS:
		resolution_dropdown.add_item("%d x %d" % [resolution.x, resolution.y])

	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN:
		display_mode_dropdown.select(2)
	elif window.borderless:
		display_mode_dropdown.select(1)
	else:
		display_mode_dropdown.select(0)

	var current_resolution := window.size
	var current_index := RESOLUTIONS.find(current_resolution)
	if current_index >= 0:
		resolution_dropdown.select(current_index)
	else:
		resolution_dropdown.select(0)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_settings_pressed() -> void:
	main_menu.hide()
	settings_menu.show()


func _on_resolution_dropdown_item_selected(index: int) -> void:
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().size = RESOLUTIONS[index]


func _on_display_mode_dropdown_item_selected(index: int) -> void:
	var window := get_window()

	match index:
		0:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
			window.size = RESOLUTIONS[resolution_dropdown.selected]
		1:
			window.mode = Window.MODE_WINDOWED
			window.borderless = true
			window.size = RESOLUTIONS[resolution_dropdown.selected]
		2:
			window.mode = Window.MODE_FULLSCREEN


func _on_back_pressed() -> void:
	settings_menu.hide()
	main_menu.show()


func _on_quit_pressed() -> void:
	get_tree().quit()

extends CanvasLayer

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DISPLAY_MODE_NAMES: Array[String] = ["Windowed", "Borderless Windowed", "Fullscreen"]

@onready var resume_button: Button = $Center/Menu/ResumeButton
@onready var pause_actions: VBoxContainer = $Center/Menu
@onready var settings_menu: VBoxContainer = $Center/SettingsMenu
@onready var display_mode_dropdown: OptionButton = $Center/SettingsMenu/DisplayModeRow/DisplayModeDropdown
@onready var resolution_dropdown: OptionButton = $Center/SettingsMenu/ResolutionRow/ResolutionDropdown


func _ready() -> void:
	visible = false
	for display_mode_name in DISPLAY_MODE_NAMES:
		display_mode_dropdown.add_item(display_mode_name)
	for resolution in RESOLUTIONS:
		resolution_dropdown.add_item("%d x %d" % [resolution.x, resolution.y])
	_refresh_display_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			if settings_menu.visible:
				_show_pause_actions()
			else:
				resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()


func pause_game() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_pause_actions()
	resume_button.grab_focus()


func resume_game() -> void:
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	resume_game()


func _on_settings_pressed() -> void:
	pause_actions.visible = false
	settings_menu.visible = true
	_refresh_display_settings()


func _on_back_pressed() -> void:
	_show_pause_actions()


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


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _show_pause_actions() -> void:
	settings_menu.visible = false
	pause_actions.visible = true


func _refresh_display_settings() -> void:
	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN:
		display_mode_dropdown.select(2)
	elif window.borderless:
		display_mode_dropdown.select(1)
	else:
		display_mode_dropdown.select(0)

	var resolution_index := RESOLUTIONS.find(window.size)
	resolution_dropdown.select(maxi(resolution_index, 0))

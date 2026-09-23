extends Control
const PALETTE = preload("res://assets/ui/default_palette.tres")

@onready var main_menu: VBoxContainer = $Center/Menu
@onready var settings_menu: PanelContainer = $Center/SettingsMenu
@onready var load_button: Button = $Center/Menu/LoadButton
@onready var load_status: Label = $Center/Menu/LoadStatus
var _loading := false

func _ready() -> void:
	PALETTE.apply_menu_colors($Center)
	$Background.color = PALETTE.background
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_load_button()
	$Center/Menu/PlayButton.grab_focus()

func _refresh_load_button() -> void:
	var saves := get_node("/root/SaveManager")
	load_button.disabled = not saves.can_load_game()
	load_button.tooltip_text = "Resume your saved game in the hideout." if not load_button.disabled else ("The saved game could not be read." if saves.has_save() else "No saved game found.")

func _on_load_pressed() -> void:
	if _loading: return
	_loading = true
	for child in main_menu.get_children():
		if child is Button: child.disabled = true
	load_status.text = "Loading..."
	load_status.show()
	_load_saved_game.call_deferred()

func _load_saved_game() -> void:
	if await get_node("/root/SaveManager").start_saved_game(): return
	_loading = false
	for child in main_menu.get_children():
		if child is Button: child.disabled = false
	_refresh_load_button()
	load_status.text = "Could not load the saved game."
	$Center/Menu/PlayButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if get_node("/root/GameSettings").input_bindings.is_capturing: return
	if event.is_action_pressed("ui_cancel") and settings_menu.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_play_pressed() -> void:
	if _loading: return
	_loading = true
	for child in main_menu.get_children():
		if child is Button: child.disabled = true
	load_status.text = "Starting new game..."
	load_status.show()
	_start_new_game.call_deferred()

func _start_new_game() -> void:
	if await get_node("/root/SaveManager").start_new_game(): return
	_loading = false
	for child in main_menu.get_children():
		if child is Button: child.disabled = false
	_refresh_load_button()
	load_status.text = "Could not start a new game."
	$Center/Menu/PlayButton.grab_focus()

func _on_settings_pressed() -> void:
	main_menu.hide()
	settings_menu.open_page()

func _on_back_pressed() -> void:
	settings_menu.hide()
	main_menu.show()
	$Center/Menu/SettingsButton.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

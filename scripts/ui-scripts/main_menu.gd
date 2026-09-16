extends Control
const PALETTE = preload("res://assets/ui/default_palette.tres")

@onready var main_menu: VBoxContainer = $Center/Menu
@onready var settings_menu: PanelContainer = $Center/SettingsMenu

func _ready() -> void:
	PALETTE.apply_menu_colors($Center)
	$Background.color = PALETTE.background
	$Center/Menu/PlayButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if get_node("/root/GameSettings").input_bindings.is_capturing: return
	if event.is_action_pressed("ui_cancel") and settings_menu.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_play_pressed() -> void:
	get_node("/root/SaveManager").begin_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	main_menu.hide()
	settings_menu.open_page()

func _on_back_pressed() -> void:
	settings_menu.hide()
	main_menu.show()
	$Center/Menu/SettingsButton.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

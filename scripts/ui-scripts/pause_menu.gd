extends CanvasLayer
const PALETTE = preload("res://assets/ui/default_palette.tres")

const PLAYER_PERF = preload("res://scripts/ui-scripts/player_performance_monitor.gd")
@onready var resume_button: Button = $Center/Menu/ResumeButton
@onready var save_status_label: Label = $Center/Menu/SaveStatusLabel
@onready var pause_actions: VBoxContainer = $Center/Menu
@onready var settings_menu: PanelContainer = $Center/SettingsMenu


func _ready() -> void:
	PALETTE.apply_menu_colors($Center)
	$Dimmer.color = Color(PALETTE.background, 0.65)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var perf_started := PLAYER_PERF.begin(self)
	_profiled_unhandled_input(event)
	PLAYER_PERF.finish(&"pause_menu_input", perf_started)


func _profiled_unhandled_input(event: InputEvent) -> void:
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	if bindings.is_capturing: return
	if bindings.is_action_press(event, "pause") or (get_tree().paused and event.is_action_pressed("ui_cancel") and not event.is_echo()):
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
	save_status_label.text = ""
	resume_button.grab_focus()


func resume_game() -> void:
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	resume_game()


func _on_settings_pressed() -> void:
	pause_actions.visible = false
	settings_menu.open_page()


func _on_save_pressed() -> void:
	if SaveManager.save_game():
		save_status_label.text = "Saved to user://savegame.json"
	else:
		save_status_label.text = "Save failed. Check the Output panel."


func _on_back_pressed() -> void:
	_show_pause_actions()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _show_pause_actions() -> void:
	$Center.show()
	settings_menu.visible = false
	pause_actions.visible = true
	resume_button.grab_focus()

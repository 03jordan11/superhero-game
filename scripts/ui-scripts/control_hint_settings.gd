extends VBoxContainer
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
var toggle: CheckBox
var status: Label
var settings: Node

func _ready() -> void:
	name = "ControlHintSettings"
	settings = get_node("/root/GameSettings")
	toggle = CheckBox.new()
	toggle.custom_minimum_size.y = 48
	toggle.add_theme_font_size_override("font_size", 22)
	add_child(toggle)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	status.hide()
	toggle.toggled.connect(_on_toggled)
	settings.control_hints_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	toggle.text = COPY.text("hud.settings.hints")
	toggle.set_pressed_no_signal(settings.show_control_hints)

func _on_toggled(enabled: bool) -> void:
	status.visible = settings.set_show_control_hints(enabled) != OK
	status.text = COPY.text("hud.settings.save_failed")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(toggle):
		_refresh()

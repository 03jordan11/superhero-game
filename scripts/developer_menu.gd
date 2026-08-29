extends CanvasLayer

@onready var flying_check_box: CheckBox = $Panel/MarginContainer/Options/FlyingCheckBox
@onready var show_landing_check_box: CheckBox = $Panel/MarginContainer/Options/ShowLandingCheckBox

var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	visible = false
	flying_check_box.toggled.connect(_on_flying_check_box_toggled)
	show_landing_check_box.toggled.connect(_on_show_landing_check_box_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_set_menu_open(not visible)
		get_viewport().set_input_as_handled()


func _set_menu_open(is_open: bool) -> void:
	visible = is_open
	DebugManager.developer_menu_open = is_open

	if is_open:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		flying_check_box.set_pressed_no_signal(DebugManager.flying_enabled)
		show_landing_check_box.set_pressed_no_signal(DebugManager.show_landing_target)
	else:
		Input.mouse_mode = previous_mouse_mode


func _on_flying_check_box_toggled(is_enabled: bool) -> void:
	DebugManager.flying_enabled = is_enabled


func _on_show_landing_check_box_toggled(is_enabled: bool) -> void:
	DebugManager.show_landing_target = is_enabled

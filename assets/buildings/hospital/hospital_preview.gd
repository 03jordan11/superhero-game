extends Node3D
## Asset inspection only; does not change the main game's controls or scene.
var yaw := 0.58
var pitch := 0.25
var distance := 255.0

func _ready() -> void:
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: $DayNightCycle.set_time(13.0)
			KEY_2: $DayNightCycle.set_time(18.3)
			KEY_3: $DayNightCycle.set_time(0.0)
			KEY_4: $DayNightCycle.set_time(5.8)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, -0.16, 1.15)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(95.0, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(480.0, distance * 1.1)
		_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, 62, 0)
	$Camera3D.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	$Camera3D.look_at(target)

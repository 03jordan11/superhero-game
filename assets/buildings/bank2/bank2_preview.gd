extends Node3D
## Local inspection controls; no dependency on the player or main scene.
var yaw := 0.52
var pitch := 0.35
var distance := 220.0
var target := Vector3(0, 58, 0)

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: $DayNightCycle.set_time(13.0)
			KEY_2: $DayNightCycle.set_time(18.3)
			KEY_5: $DayNightCycle.set_time(0.0)
			KEY_6: $DayNightCycle.set_time(5.8)
			KEY_3:
				target = Vector3(0, 58, -8)
				yaw = PI
				pitch = .50
				distance = 200
				_update_camera()
			KEY_4:
				target = Vector3(0, 7, 15)
				yaw = 0
				pitch = .05
				distance = 65
				_update_camera()
			KEY_R:
				target = Vector3(0, 58, 0)
				yaw = .52
				pitch = .35
				distance = 220
				_update_camera()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * .006
		pitch = clampf(pitch + event.relative.y * .004, -.10, 1.4)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(12, distance * .9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(600, distance * 1.1)
		_update_camera()

func _update_camera() -> void:
	$Camera3D.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	$Camera3D.look_at(target)



extends Camera3D
## Free camera for running SuperCity directly (F6). Removed when embedded in Main.

@export var move_speed: float = 50.0
@export var fast_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.003


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	_configure_preview.call_deferred()


func _configure_preview() -> void:
	if get_tree().current_scene != get_parent():
		queue_free()
		return
	make_current()
	set_process(true)
	set_process_unhandled_input(true)
	# Let the standalone crowd follow the preview position without a player body.
	var crowd := get_parent().get_node_or_null("CivilianCrowd")
	if crowd != null:
		crowd.player_path = crowd.get_path_to(self)
	print("City preview: hold right mouse to look/move; WASD, Q/E down/up, Shift faster, Esc release.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.screen_relative.x * mouse_sensitivity
		rotation.x = clampf(rotation.x - event.screen_relative.y * mouse_sensitivity, -1.55, 1.55)


func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var direction := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	direction = global_basis * direction
	direction.y += float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var speed := move_speed * (fast_multiplier if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	global_position += direction.normalized() * speed * delta

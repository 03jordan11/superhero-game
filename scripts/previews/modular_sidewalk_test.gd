extends Node3D
## This preview script never generates or replaces the placed kit instances.
var walking := false
var orbit_target := Vector3(-5, 0, -15)
var yaw := 0.1
var pitch := 1.1
@onready var player: PlayerCharacter = $Player
@onready var overview: Camera3D = $OverviewCamera

func _ready() -> void:
	_set_walk_mode(false)
	_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F4:
			_set_walk_mode(not walking)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_HOME:
			player.global_transform = $PlayerStart.global_transform
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and walking:
			_set_walk_mode(false)
			get_viewport().set_input_as_handled()
	if walking: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: overview.size = maxf(overview.size * 0.85, 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: overview.size = minf(overview.size / 0.85, 220.0)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= event.relative.x * 0.005
			pitch = clampf(pitch + event.relative.y * 0.005, 0.3, 1.5)
			_update_camera()
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var shift: Vector3 = (-overview.global_basis.x * event.relative.x + overview.global_basis.y * event.relative.y) * overview.size / get_viewport().get_visible_rect().size.y
			shift.y = 0
			orbit_target += shift
			_update_camera()

func _update_camera() -> void:
	overview.position = orbit_target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)) * 150.0
	overview.look_at(orbit_target)

func _set_walk_mode(enabled: bool) -> void:
	walking = enabled
	player.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	player.visible = enabled
	player.get_node("GameplayHUD").visible = enabled
	player.velocity = Vector3.ZERO
	player.input_controller.reset()
	$Labels.visible = not enabled
	var panel: PanelContainer = $Instructions/Panel
	if enabled:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		panel.offset_left=-480; panel.offset_right=480; panel.offset_top=24; panel.offset_bottom=104
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_left=28; panel.offset_right=-28; panel.offset_top=-104; panel.offset_bottom=-24
	$Instructions/Panel/Help.text = "WALK TEST   |   Normal player controls\nHome: return to start   |   F4 / Esc: overview" if enabled else "SIDEWALK KIT   |   F4: walk test   |   Right-drag: orbit   |   Middle-drag: pan   |   Wheel: zoom\nEdit the saved instances in Godot: 2 m translation snap, 90° rotation snap. Existing city is unchanged."
	if enabled:
		player.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		overview.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

extends Node3D
## Standalone comparison scene. Fly camera intentionally has no player dependency.
@onready var garages: Array[Node3D] = [$Small, $Medium, $Large]
@onready var camera: Camera3D = $Camera3D
var selected := 1
var target := Vector3(-5, 14, 0)
var yaw := -.22
var pitch := .37
var distance := 175.0
var width_choice: OptionButton
var floor_slider: HSlider
var info: Label
var syncing := false
var labels: Array[Label3D] = []

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for garage: Node3D in garages:
		var label := Label3D.new()
		label.position = garage.position + Vector3(0, 2, -35)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		label.pixel_size = .02
		label.no_depth_test = false
		add_child(label)
		labels.append(label)
	_build_controls()
	_sync_controls()
	_update_camera()

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(26, 26)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "PARKING GARAGE  /  CONFIGURATION LAB"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in 3:
		var button := Button.new()
		button.text = ["1  Garage A", "2  Garage B", "3  Garage C"][i]
		button.pressed.connect(_select.bind(i))
		row.add_child(button)
	width_choice = OptionButton.new()
	for label: String in ["Small • 32 m wide", "Medium • 44 m wide", "Large • 56 m wide"]:
		width_choice.add_item(label)
	width_choice.item_selected.connect(_change_width)
	box.add_child(width_choice)
	floor_slider = HSlider.new()
	floor_slider.min_value = 3
	floor_slider.max_value = 10
	floor_slider.step = 1
	floor_slider.custom_minimum_size = Vector2(440, 35)
	floor_slider.value_changed.connect(_change_floors)
	box.add_child(floor_slider)
	info = Label.new()
	box.add_child(info)
	var help := Label.new()
	help.text = "LMB drag: orbit  •  Wheel: zoom  •  Home: overview\nHold RMB + WASD / Q E: fly  •  Shift: faster\n1 / 2 / 3: focus a garage. Changes here are temporary."
	box.add_child(help)

func _sync_controls() -> void:
	syncing = true
	width_choice.select(garages[selected].width_preset)
	floor_slider.value = garages[selected].floors
	syncing = false
	_update_labels.call_deferred()

func _update_labels() -> void:
	for i in 3:
		var garage: Node3D = garages[i]
		labels[i].text = "%s  /  %d LEVELS" % [["SMALL", "MEDIUM", "LARGE"][garage.width_preset], garage.floors]
	var garage: Node3D = garages[selected]
	info.text = "%d parking levels • %d × 54 m • %s triangles\nGround level included; open parking on the top deck." % [garage.floors, garage.WIDTHS[garage.width_preset], str(garage.get_meta("rendered_triangles", 0))]

func _select(index: int) -> void:
	selected = index
	target = garages[index].position + Vector3(0, garages[index].get_dimensions().y * .42, 0)
	distance = 92
	pitch = .36
	_update_camera()
	_sync_controls()

func _change_width(value: int) -> void:
	if syncing:
		return
	garages[selected].width_preset = value
	_update_labels.call_deferred()

func _change_floors(value: float) -> void:
	if syncing:
		return
	garages[selected].floors = int(value)
	_update_labels.call_deferred()

func _process(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var speed := 42.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 12.0
	camera.position += camera.basis * direction.normalized() * speed * delta
	target = camera.position - camera.basis.z * distance

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			_select(event.keycode - KEY_1)
		elif event.keycode == KEY_HOME:
			target = Vector3(-5,14,0)
			distance = 175
			yaw = -.22
			pitch = .37
			_update_camera()
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera.rotation.y -= event.relative.x * .003
			camera.rotation.x = clampf(camera.rotation.x-event.relative.y*.003, -1.5, 1.5)
			target = camera.position - camera.basis.z * distance
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			yaw -= event.relative.x * .005
			pitch = clampf(pitch+event.relative.y*.004, -.05, 1.4)
			_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(5, distance * .9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(350, distance * 1.1)
		else:
			return
		_update_camera()

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), -cos(yaw)*cos(pitch)) * distance
	camera.look_at(target)

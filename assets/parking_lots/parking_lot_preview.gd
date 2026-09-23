extends Node3D
@onready var lot: MeshInstance3D = $Adjustable
var info: Label
var width_slider: HSlider
var depth_slider: HSlider
var orbit_target := Vector3(12,0,0)
var yaw := 0.0
var pitch := 1.0

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_update_camera()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(24,24)
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation",8)
	margin.add_child(controls)
	var title := Label.new()
	title.text = "PARKING LOT / RESIZE PREVIEW"
	title.add_theme_font_size_override("font_size",26)
	controls.add_child(title)
	width_slider = _slider(controls,"Width",70,lot.width_m)
	depth_slider = _slider(controls,"Depth",80,lot.depth_m)
	width_slider.value_changed.connect(_resize)
	depth_slider.value_changed.connect(_resize)
	info = Label.new()
	controls.add_child(info)
	var help := Label.new()
	help.text = "Sliders resize the middle lot. Each space stays 2.6 × 5.2 m.\nRight-drag: orbit • Wheel: zoom • R: reset view\nVisual surface only. Save permanent dimensions in the Inspector."
	controls.add_child(help)
	_update_info()
	for piece: MeshInstance3D in [$Small,$Large]:
		var label := Label3D.new()
		label.position = piece.position+Vector3(0,1,piece.depth_m/2+4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.text = "%d × %d m" % [piece.width_m,piece.depth_m]
		label.font_size = 64
		label.pixel_size = .04
		add_child(label)

func _slider(parent: Node, title: String, maximum: float, value: float) -> HSlider:
	var label := Label.new()
	label.text=title
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value=2
	slider.max_value=maximum
	slider.step=.1
	slider.value=value
	slider.custom_minimum_size=Vector2(560,26)
	parent.add_child(slider)
	return slider

func _resize(_value: float) -> void:
	lot.width_m=width_slider.value
	lot.depth_m=depth_slider.value
	_update_info()

func _update_info() -> void:
	var layout: Vector2i = lot.get_parking_layout()
	info.text = "%.1f × %.1f m • %d spaces • 2 triangles" % [lot.width_m,lot.depth_m,layout.x*layout.y]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		yaw -= event.relative.x*.005
		pitch = clampf(pitch+event.relative.y*.005,.3,1.55)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: $Camera3D.size=maxf(20,$Camera3D.size*.9)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: $Camera3D.size=minf(200,$Camera3D.size/ .9)
	if event is InputEventKey and event.pressed and event.keycode==KEY_R:
		yaw=0
		pitch=1
		$Camera3D.size=110
		_update_camera()

func _update_camera() -> void:
	$Camera3D.position=orbit_target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*140
	$Camera3D.look_at(orbit_target)

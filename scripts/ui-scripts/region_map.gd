extends Control
## Static geography; marker uses the same SuperCity-local bounds as the export.
const MAP := preload("res://assets/ui/maps/region_map.png")
const DATA := preload("res://assets/ui/maps/region_map.json")
const COPY := preload("res://scripts/ui-scripts/powers_text.gd")
const PALETTE := preload("res://assets/ui/default_palette.tres")
@export_range(1.0, 12.0, 0.5) var maximum_zoom := 8.0
var player: Node3D
var city: Node3D
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(reset_view)
	visibility_changed.connect(_visibility_changed)

func _process(_delta: float) -> void:
	if is_visible_in_tree(): queue_redraw()

func _visibility_changed() -> void:
	dragging = false
	queue_redraw()

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	dragging = false
	queue_redraw()

func map_rect() -> Rect2:
	var available := Vector2(maxf(size.x - 32.0, 1.0), maxf(size.y - 64.0, 1.0))
	var scale_factor := minf(available.x / MAP.get_width(), available.y / MAP.get_height())
	var extent := MAP.get_size() * scale_factor * zoom
	return Rect2(Vector2(size.x, size.y - 40.0) * 0.5 - extent * 0.5 + pan, extent)

func world_to_uv(world_position: Vector3) -> Vector2:
	var local := city.to_local(world_position)
	var bounds: Array = DATA.data.bounds_xz
	return Vector2((local.x - bounds[0]) / (bounds[2] - bounds[0]), (local.z - bounds[1]) / (bounds[3] - bounds[1]))

func marker_position() -> Vector2:
	var rect := map_rect()
	return rect.position + world_to_uv(player.global_position) * rect.size

func _draw() -> void:
	var rect := map_rect()
	draw_texture_rect(MAP, rect, false)
	draw_rect(rect, PALETTE.border, false, 2.0)
	var outside := false
	if is_instance_valid(player) and is_instance_valid(city):
		var uv := world_to_uv(player.global_position)
		outside = uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0
		if not outside:
			var point := marker_position()
			draw_circle(point, 12.0, PALETTE.background)
			draw_circle(point, 9.0, Color.WHITE)
			draw_circle(point, 6.0, PALETTE.accent)
	# Footer covers the panned image, keeping controls and legend readable.
	draw_rect(Rect2(0, size.y - 36, size.x, 36), PALETTE.surface)
	draw_circle(Vector2(20, size.y - 17), 5, PALETTE.accent)
	var caption := COPY.text("gameplay.map.outside" if outside else "gameplay.map.help")
	draw_string(ThemeDB.fallback_font, Vector2(34, size.y - 10), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 18, PALETTE.text_primary)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.double_click: reset_view()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var old_rect := map_rect()
			var uv: Vector2 = (event.position - old_rect.position) / old_rect.size
			zoom = clampf(zoom * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, maximum_zoom)
			var new_rect := map_rect()
			pan += event.position - (new_rect.position + uv * new_rect.size)
			if is_equal_approx(zoom, 1.0): pan = Vector2.ZERO
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			dragging = false
			return
		if zoom > 1.0:
			pan += event.relative
			queue_redraw()
		accept_event()

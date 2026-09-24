extends Control
## North-up static map crop. No 3D camera or viewport is used.
const MAP := preload("res://assets/ui/maps/region_map.png")
const DATA := preload("res://assets/ui/maps/region_map.json")
const PALETTE := preload("res://assets/ui/default_palette.tres")
@export_range(80.0, 600.0, 10.0) var walking_radius := 180.0
@export_range(200.0, 1800.0, 10.0) var fast_radius := 650.0
@export_range(10.0, 300.0, 5.0) var full_zoom_speed := 100.0
@export_range(0.0, 600.0, 10.0) var flight_extra_radius := 180.0
@export_range(0.1, 10.0, 0.1) var zoom_response := 2.0
var player: PlayerCharacter
var city: Node3D
var current_radius := 180.0
var _frame: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = StyleBoxFlat.new()
	_frame.bg_color = PALETTE.background
	_frame.border_color = PALETTE.border
	_frame.set_border_width_all(2)
	_frame.set_corner_radius_all(16)
	_frame.shadow_color = Color(0, 0, 0, 0.35)
	_frame.shadow_size = 8
	current_radius = walking_radius

func radius_for_motion(speed: float, flying: bool) -> float:
	var weight := smoothstep(0.0, full_zoom_speed, maxf(speed, 0.0))
	return lerpf(walking_radius, maxf(walking_radius, fast_radius), weight) + (flight_extra_radius if flying else 0.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(player) or not is_instance_valid(city): return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	current_radius = lerpf(current_radius, radius_for_motion(speed, player.is_flying), 1.0 - exp(-zoom_response * delta))
	queue_redraw()

func source_rect() -> Rect2:
	var local := city.to_local(player.global_position)
	var bounds: Array = DATA.data.bounds_xz
	var pixels_per_metre: float = DATA.data.pixels_per_metre
	var center := Vector2(local.x - bounds[0], local.z - bounds[1]) * pixels_per_metre
	var extent := Vector2.ONE * current_radius * 2.0 * pixels_per_metre
	return Rect2(center - extent * 0.5, extent)

func heading_angle() -> float:
	# ground_facing_yaw follows the hero, including movement independent of camera yaw.
	var forward := Vector3(-sin(player.ground_facing_yaw), 0, -cos(player.ground_facing_yaw))
	var local_forward := city.global_basis.inverse() * forward
	return atan2(local_forward.x, -local_forward.z)

func _draw() -> void:
	if _frame == null: return
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var area := Rect2(Vector2(28, 28), size - Vector2(56, 56))
	draw_rect(area, PALETTE.surface)
	if is_instance_valid(player) and is_instance_valid(city):
		var source := source_rect()
		var clipped := source.intersection(Rect2(Vector2.ZERO, MAP.get_size()))
		if clipped.has_area():
			var destination := Rect2(area.position + (clipped.position - source.position) / source.size * area.size, clipped.size / source.size * area.size)
			draw_texture_rect_region(MAP, destination, clipped)
		var center := area.get_center()
		draw_circle(center, 13, PALETTE.background)
		var arrow := PackedVector2Array()
		for point in [Vector2(0, -11), Vector2(8, 9), Vector2(0, 5), Vector2(-8, 9)]:
			arrow.append(center + point.rotated(heading_angle()))
		draw_colored_polygon(arrow, PALETTE.accent)
		var outline := arrow.duplicate()
		outline.append(arrow[0])
		draw_polyline(outline, Color.WHITE, 1.5, true)
	draw_rect(area, PALETTE.border, false, 1.0)
	for entry in [["N", Vector2(size.x/2, 20)], ["S", Vector2(size.x/2, size.y-8)], ["W", Vector2(14, size.y/2+6)], ["E", Vector2(size.x-14, size.y/2+6)]]:
		var label: String = entry[0]
		var pos: Vector2 = entry[1]
		pos.x -= ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x / 2.0
		draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PALETTE.accent if label == "N" else PALETTE.text_primary)

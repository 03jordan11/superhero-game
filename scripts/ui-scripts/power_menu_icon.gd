extends Control
## Small native vector emblems, drawn at any UI scale without external assets.
var power := "super_leap"
var ink: Color = preload("res://assets/ui/default_palette.tres").accent
var line_width := 4.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var extent := minf(size.x, size.y)
	draw_set_transform((size - Vector2.ONE * extent) / 2.0, 0.0, Vector2.ONE * extent / 100.0)
	match power:
		"super_leap":
			draw_circle(Vector2(58, 23), 8, ink)
			stroke([Vector2(29, 45), Vector2(43, 32), Vector2(56, 40), Vector2(75, 31)])
			stroke([Vector2(56, 40), Vector2(48, 57), Vector2(28, 65), Vector2(18, 83)])
			stroke([Vector2(48, 57), Vector2(65, 65), Vector2(77, 57)])
			stroke([Vector2(15, 53), Vector2(8, 66)], 2)
			stroke([Vector2(26, 34), Vector2(15, 46)], 2)
		"flight":
			stroke([Vector2(18, 77), Vector2(29, 39), Vector2(79, 21), Vector2(65, 43), Vector2(39, 53), Vector2(70, 44), Vector2(55, 64), Vector2(32, 69), Vector2(58, 66), Vector2(43, 81), Vector2(18, 77)])
		"super_speed":
			for x in [14, 45]:
				stroke([Vector2(x, 25), Vector2(x + 25, 50), Vector2(x, 75)], 9)
		"ice":
			for i in 6:
				var direction := Vector2.UP.rotated(i * TAU / 6.0)
				var center := Vector2(50, 50)
				stroke([center, center + direction * 36])
				stroke([center + direction * 21 + direction.rotated(PI / 2) * 10, center + direction * 29, center + direction * 21 - direction.rotated(PI / 2) * 10], 3)
		"fire":
			stroke([Vector2(47, 12), Vector2(44, 37), Vector2(30, 29), Vector2(20, 55), Vector2(24, 73), Vector2(39, 84), Vector2(61, 84), Vector2(78, 66), Vector2(75, 46), Vector2(63, 27), Vector2(63, 52), Vector2(47, 12)])
			stroke([Vector2(42, 77), Vector2(40, 63), Vector2(51, 48), Vector2(60, 66), Vector2(55, 78)], 3)
		"electricity":
			draw_colored_polygon(PackedVector2Array([Vector2(56, 8), Vector2(22, 56), Vector2(45, 56), Vector2(38, 93), Vector2(80, 39), Vector2(55, 39), Vector2(56, 8)]), ink)
		"ground_slam", "strength":
			stroke([Vector2(8, 80), Vector2(32, 73), Vector2(21, 49), Vector2(43, 61), Vector2(50, 29), Vector2(58, 62), Vector2(79, 49), Vector2(69, 73), Vector2(92, 80)])
			stroke([Vector2(30, 88), Vector2(70, 88)], 3)
			stroke([Vector2(50, 10), Vector2(50, 20)], 3)
		"laser_eyes":
			stroke([Vector2(9, 44), Vector2(26, 29), Vector2(49, 25), Vector2(70, 32), Vector2(85, 44), Vector2(68, 57), Vector2(49, 62), Vector2(27, 57), Vector2(9, 44)])
			draw_arc(Vector2(48, 44), 12, 0, TAU, 32, ink, 3, true)
			stroke([Vector2(56, 52), Vector2(87, 82)], 5)
			stroke([Vector2(45, 59), Vector2(65, 87)], 2)
		"telekinesis", "mind":
			var points := PackedVector2Array()
			for i in 90:
				var angle := i * 0.14
				points.append(Vector2(50, 50) + Vector2.from_angle(angle) * (4 + i * 0.36))
			draw_polyline(points, ink, 4, true)
			draw_circle(Vector2(81, 20), 4, ink)

func stroke(points: Array, width := -1.0) -> void:
	draw_polyline(PackedVector2Array(points), ink, line_width if width < 0 else width, true)

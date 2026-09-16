extends Control

func _draw() -> void:
	var center := size * 0.5
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * 4.0, center + direction * 9.0, Color(0, 0, 0, 0.8), 3.0, true)
		draw_line(center + direction * 4.0, center + direction * 9.0, Color(1, 0.85, 0.75), 1.0, true)
	draw_circle(center, 1.3, Color.WHITE)

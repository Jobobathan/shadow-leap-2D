extends Node2D
## Draws a subtle grid overlay across the play area.

func _draw() -> void:
	var grid_color := Color(0.2, 0.25, 0.18, 0.15)
	var spacing := 100
	for x in range(-1500, 1500, spacing):
		draw_line(Vector2(x, -1500), Vector2(x, 1500), grid_color, 1.0)
	for y in range(-1500, 1500, spacing):
		draw_line(Vector2(-1500, y), Vector2(1500, y), grid_color, 1.0)

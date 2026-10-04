class_name TableBackdrop
extends Node2D
## Dev stand-in for the table scene of the reference: wall + shelf, then the table top and its
## front panel. The wall is drawn below the players (z -1) and the table between a player's
## Back (z 0) and Front (z 2).

enum Part { WALL, TABLE, EDGE }

@export var part := Part.WALL
@export var width := 215.0
@export var height := 360.0


func _draw() -> void:
	if part == Part.WALL:
		var wall := Color("#2e3248")
		draw_rect(Rect2(0, 0, width, height), wall)
		var stripe := wall.lerp(Color.BLACK, 0.12)
		for x in range(0, int(width), 46):
			draw_line(Vector2(x, 0), Vector2(x, 232), stripe, 2.0)
		draw_rect(Rect2(width * 0.04, 26, width * 0.92, 6), Color("#5a3924"))
	elif part == Part.EDGE:
		# portraits: the table top and its front panel, in figure coordinates (edge at y = 192)
		draw_rect(Rect2(0, 192, width, 40), Color("#8b5b3b"))
		draw_rect(Rect2(0, 232, width, height), Color("#5a3924"))
		draw_line(Vector2(0, 195), Vector2(width, 195), Color("#9b6a46"), 2.0)
	else:
		draw_rect(Rect2(0, 232, width, 36), Color("#8b5b3b"))
		draw_rect(Rect2(width * 0.2, 236, width * 0.6, 28), Color("#5f8a6a"))
		draw_rect(Rect2(0, 268, width, height - 268.0), Color("#5a3924"))
		draw_line(Vector2(0, 271), Vector2(width, 271), Color("#9b6a46"), 2.0)
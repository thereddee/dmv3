class_name PlayerLayer
extends Node2D
## One drawn layer of a table player. Holds flat draw ops and paints them in order; the node
## origin is the layer's animation pivot, so poses are plain Node2D transforms.

## Where the layer sits when no pose is applied (pose offsets are added to this).
var rest_position := Vector2.ZERO
var ops: Array[Dictionary] = []


func _draw() -> void:
	for op in ops:
		var pts: PackedVector2Array = op.pts
		match op.kind:
			"fill":
				_fill(pts, op)
				if op.width > 0.0:
					_stroke(pts, op.closed, op.line, op.width)
			"line":
				_stroke(pts, op.closed, op.line, op.width)
			"text":
				draw_string(ThemeDB.fallback_font, pts[0], op.text, HORIZONTAL_ALIGNMENT_CENTER,
						op.span, op.size, op.line)


func _stroke(pts: PackedVector2Array, closed: bool, color: Color, width: float) -> void:
	var path := pts
	if closed:
		path = pts.duplicate()
		path.append(pts[0])
	draw_polyline(path, color, width, true)

## Slivers (the drakeide horns) cannot be triangulated; their outline already shows them.
func _fill(pts: PackedVector2Array, op: Dictionary) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	var tex: Texture2D = op.get("tex")
	if tex != null:
		draw_colored_polygon(pts, op.fill, op.uvs, tex)
	else:
		draw_colored_polygon(pts, op.fill)

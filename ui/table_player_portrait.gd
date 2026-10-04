class_name TablePlayerPortrait
extends Control
## A TablePlayer boxed for Control layouts: the figure from the hat to the table edge, sitting
## behind a strip of table so the cut at the bottom reads as a table. Idles with the same
## poses as at the table.

const DEAD_TINT := Color(0.35, 0.35, 0.4)
## The part of the figure that is shown, in figure coordinates (centre line x = 100, table edge y = 192).
const VIEW := Rect2(20, -12, 160, 244)
const PLAYER_SCENE := preload("res://ui/table_player/table_player.tscn")

var _figure: Node2D
var _player: TablePlayer


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure = Node2D.new()
	add_child(_figure)
	_player = PLAYER_SCENE.instantiate()
	_figure.add_child(_player)


## Hides itself when the player has no table look (fixed v0 party).
func setup(look: PlayerAppearance, seat: int, display_scale: float) -> void:
	visible = look != null
	if look == null:
		return
	custom_minimum_size = VIEW.size * display_scale
	_figure.scale = Vector2.ONE * display_scale
	_figure.position = -VIEW.position * display_scale
	_player.seat = seat
	_player.apply(look)
	var table := TableBackdrop.new()
	table.part = TableBackdrop.Part.EDGE
	table.width = VIEW.size.x
	table.height = VIEW.size.y
	table.position = Vector2(VIEW.position.x, 0.0)
	_player.insert_table(table)


func set_dead(dead: bool) -> void:
	_figure.modulate = DEAD_TINT if dead else Color.WHITE
	_player.animate = not dead
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
var _base: PlayerAppearance
var _display_scale := 1.0
var _mood := ""
var _surprise_until := 0.0
var _phone := false
var _built_key := ""


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
	_base = look
	_mood = look.mood
	custom_minimum_size = VIEW.size * display_scale
	_figure.scale = Vector2.ONE * display_scale
	_figure.position = -VIEW.position * display_scale
	_player.seat = seat
	_rebuild()
	var table := TableBackdrop.new()
	table.part = TableBackdrop.Part.EDGE
	table.width = VIEW.size.x
	table.height = VIEW.size.y
	table.position = Vector2(VIEW.position.x, 0.0)
	_player.insert_table(table)


func set_dead(dead: bool) -> void:
	_figure.modulate = DEAD_TINT if dead else Color.WHITE
	_player.animate = not dead

## The seat's current face and prop: `mood` is a PlayerAppearance mood id, `phone` swaps the
## prop for the cell phone. Redraws only when something changed.
func set_state(mood: String, phone: bool) -> void:
	if _base == null:
		return
	_mood = mood
	_phone = phone
	_rebuild()


## Looks surprised for `seconds`, then goes back to the seat's own face.
func flash_surprise(seconds: float) -> void:
	if _base == null:
		return
	_surprise_until = Time.get_ticks_msec() / 1000.0 + seconds
	_rebuild()
	await get_tree().create_timer(seconds).timeout
	if Time.get_ticks_msec() / 1000.0 >= _surprise_until:
		_rebuild()


func _rebuild() -> void:
	var surprised := Time.get_ticks_msec() / 1000.0 < _surprise_until
	var mood := PlayerAppearance.MOOD_SURPRISED if surprised else _mood
	var key := "%s|%s" % [mood, _phone]
	if key == _built_key:
		return
	_built_key = key
	var look := _base.duplicate() as PlayerAppearance
	look.mood = mood
	if _phone:
		look.prop = PlayerAppearance.PROP_PHONE
	_player.apply(look)

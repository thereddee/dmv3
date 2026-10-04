extends Node2D
## Dev scene: seats a few generated table players.
## Keys: Space = next seed, P = Pixel mode, Q/E = pixel size, A/D = dithering, F = pattern,
## Z/C = colour count. Args after `--`: --seed=N, --count=N, --pixel, --ps=N,
## --shots=<dir> (saves one PNG per seed, then quits).

const SEAT_W := 215.0
const SCENE_H := 360.0
const SHOT_COUNT := 4
const PLAYER_TOP := 40.0
const DITHER_STEP := 5
const COLOR_STEP := 4
## Outline width per pixel of Pixel mode, as in the reference (sw = pixel size x 1.3).
const PIXEL_STROKE := 1.3

var _rng := RandomNumberGenerator.new()
var _seed_value := 1
var _count := 1
var _shots_dir := ""
var _pixel_mode := false
var _label: Label
var _stage: Node2D
var _pixel: PixelTable
var _zoom := 1.0


func _ready() -> void:
	var pixel_size := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed_value = int(arg.substr(7))
		elif arg.begins_with("--count="):
			_count = int(arg.substr(8))
		elif arg.begins_with("--shots="):
			_shots_dir = arg.substr(8)
		elif arg.begins_with("--ps="):
			pixel_size = int(arg.substr(5))
		elif arg == "--pixel":
			_pixel_mode = true
	_pixel = PixelTable.new()
	_pixel.pixel_size = pixel_size
	add_child(_pixel)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.z_index = 10
	add_child(_label)
	_seat()
	if _shots_dir != "":
		_take_shots()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_SPACE:
			_seed_value += 1
			_seat()
		KEY_P:
			_pixel_mode = not _pixel_mode
			_seat()
		KEY_Q:
			_pixel.pixel_size = maxi(2, _pixel.pixel_size - 1)
			_refresh_pixel()
		KEY_E:
			_pixel.pixel_size = mini(6, _pixel.pixel_size + 1)
			_refresh_pixel()
		KEY_A:
			_pixel.dither = maxi(0, _pixel.dither - DITHER_STEP)
		KEY_D:
			_pixel.dither = mini(100, _pixel.dither + DITHER_STEP)
		KEY_F:
			_pixel.pattern = (_pixel.pattern + 1) % PixelTable.Pattern.size()
		KEY_Z:
			_pixel.colors = maxi(PixelTable.MIN_COLORS, _pixel.colors - COLOR_STEP)
			_pixel.rebuild_palette()
		KEY_C:
			_pixel.colors = mini(PixelTable.MAX_COLORS, _pixel.colors + COLOR_STEP)
			_pixel.rebuild_palette()
	_update_label()


func _seat() -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = Node2D.new()
	var width := SEAT_W * _count
	_zoom = minf(2.0, minf(1280.0 / width, 720.0 / SCENE_H))
	var origin := Vector2((1280.0 - width * _zoom) / 2.0, 0.0)
	_pixel.visible = _pixel_mode
	if _pixel_mode:
		_pixel.content.add_child(_stage)
		_pixel.position = origin
		_pixel.size = Vector2(width, SCENE_H) * _zoom
		_pixel.scene_size = Vector2(width, SCENE_H)
	else:
		add_child(_stage)
		move_child(_stage, 0)
		_stage.scale = Vector2.ONE * _zoom
		_stage.position = origin
	var wall := TableBackdrop.new()
	wall.width = width
	wall.z_index = -1
	_stage.add_child(wall)
	var table := TableBackdrop.new()
	table.part = TableBackdrop.Part.TABLE
	table.width = width
	table.z_index = 1
	_stage.add_child(table)
	_rng.seed = _seed_value
	var scene: PackedScene = load("res://ui/table_player/table_player.tscn")
	for i in _count:
		var look := PlayerAppearance.new()
		look.randomize_with(_rng)
		var player: TablePlayer = scene.instantiate()
		player.seat = i
		if _pixel_mode:
			player.stroke_mult = _pixel.pixel_size * PIXEL_STROKE / TablePlayerBuilder.STROKE
		player.position = Vector2(i * SEAT_W + 12.0, PLAYER_TOP)
		_stage.add_child(player)
		player.apply(look)
	_update_label()
	if _pixel_mode:
		_pixel.rebuild_palette()


func _refresh_pixel() -> void:
	_seat()


func _update_label() -> void:
	var text := "seed %d  (Space = next, P = Pixel)" % _seed_value
	if _pixel_mode:
		text += "  pixel %d (Q/E)  tramage %d (A/D)  motif %s (F)  couleurs %d (Z/C)" % [
				_pixel.pixel_size, _pixel.dither, PixelTable.Pattern.keys()[_pixel.pattern], _pixel.colors]
	_label.text = text


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	for i in SHOT_COUNT:
		for f in 12:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("seed_%d.png" % _seed_value))
		_seed_value += 1
		_seat()
	get_tree().quit()
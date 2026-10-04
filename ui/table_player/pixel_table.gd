class_name PixelTable
extends Control
## Pixel mode: renders whatever is put under `content` into a SubViewport at 1/pixel_size of the
## scene, shows it with nearest filtering and snaps it to a palette with ordered dithering
## (shader ui/shaders/pixel_dither.gdshader). The palette is sampled from the scene itself, like
## the reference: the most frequent colours, at least PALETTE_MIN_DIST apart.
## Fill the control's rect with the scene, whatever its size; `scene_size` is in scene units.

enum Pattern { BAYER4, BAYER2, LINES, NOISE }

const MAX_COLORS := 64
const MIN_COLORS := 8
## Squared RGB distance (0..255 space) under which two palette colours count as the same.
const PALETTE_MIN_DIST := 260.0
const SHADER := preload("res://ui/shaders/pixel_dither.gdshader")

## Scene units per displayed pixel.
@export_range(2, 6) var pixel_size := 3:
	set(value):
		pixel_size = value
		_apply_size()
@export_range(0, 100) var dither := 35:
	set(value):
		dither = value
		_set_param("dither_strength", float(value))
@export var pattern := Pattern.BAYER4:
	set(value):
		pattern = value
		_set_param("pattern", int(value))
@export_range(8, 64) var colors := 48
## Re-render rate; the chunky look reads better at about 10 images per second. 0 = every frame.
@export var fps := 10.0
@export var scene_size := Vector2(860, 360):
	set(value):
		scene_size = value
		_apply_size()

## Parent the scene to draw here.
var content: Node2D
var _viewport: SubViewport
var _screen: TextureRect
var _material: ShaderMaterial
var _since_render := 0.0


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	content = Node2D.new()
	_viewport.add_child(content)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_screen = TextureRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.material = _material
	_screen.texture = _viewport.get_texture()
	add_child(_screen)
	_apply_size()
	_set_param("dither_strength", float(dither))
	_set_param("pattern", int(pattern))


func _process(delta: float) -> void:
	if fps <= 0.0:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		return
	_since_render += delta
	if _since_render >= 1.0 / fps:
		_since_render = 0.0
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Samples a fresh palette from the current frame (plain, undithered). Call it once the scene is
## set up, and again after changing `colors` or `pixel_size`.
func rebuild_palette() -> void:
	_set_param("palette_size", 0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var palette := build_palette(_viewport.get_texture().get_image(), colors)
	var padded := PackedVector3Array(palette)
	padded.resize(MAX_COLORS)
	_set_param("palette", padded)
	_set_param("palette_size", palette.size())


## Most frequent colours first (5 bits per channel buckets), skipping near-duplicates.
static func build_palette(img: Image, count: int) -> PackedVector3Array:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var buckets := {}
	for i in range(0, data.size(), 4):
		var key := (data[i] >> 3) << 10 | (data[i + 1] >> 3) << 5 | (data[i + 2] >> 3)
		var entry: Array = buckets.get(key, [0.0, 0.0, 0.0, 0])
		entry[0] += data[i]
		entry[1] += data[i + 1]
		entry[2] += data[i + 2]
		entry[3] += 1
		buckets[key] = entry
	var entries: Array = buckets.values()
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3])
	var palette := PackedVector3Array()
	var limit := clampi(count, MIN_COLORS, MAX_COLORS)
	for e: Array in entries:
		var c := Vector3(e[0], e[1], e[2]) / float(e[3])
		var distinct := true
		for q in palette:
			if (q * 255.0).distance_squared_to(c) <= PALETTE_MIN_DIST:
				distinct = false
				break
		if distinct:
			palette.append(c / 255.0)
			if palette.size() >= limit:
				break
	return palette


func _apply_size() -> void:
	if _viewport == null:
		return
	_viewport.size = Vector2i((scene_size / float(pixel_size)).round())
	_viewport.size_2d_override = Vector2i(scene_size)


func _set_param(param: String, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)
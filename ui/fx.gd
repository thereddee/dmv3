class_name Fx
extends RefCounted
## Combat feedback helpers: number pops, flashes, bumps.

const POP_TIME := 0.9
const POP_RISE := 44.0
const FLASH_TIME := 0.35

static var _pop_slot := 0


## Floating text rising from `host`. Successive pops are staggered sideways so they stay readable.
## `height` is where it starts on the host, from 0.0 (top) to 1.0 (bottom).
static func pop(host: Control, text: String, color: Color, font_size: int = 22, height: float = 0.3) -> void:
	var label := Label.new()
	label.text = text
	label.top_level = true
	label.z_index = 50
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	host.add_child(label)
	_pop_slot = (_pop_slot + 1) % 3
	var start := host.global_position + Vector2(host.size.x * (0.2 + 0.22 * _pop_slot), host.size.y * height)
	label.global_position = start
	var tween := host.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", start.y - POP_RISE, POP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, POP_TIME * 0.5).set_delay(POP_TIME * 0.5)
	tween.chain().tween_callback(label.queue_free)


static func flash(host: Control, color: Color) -> void:
	host.modulate = color
	host.create_tween().tween_property(host, "modulate", Color.WHITE, FLASH_TIME)


## Quick scale pulse: "this one is acting".
static func bump(host: Control) -> void:
	host.pivot_offset = host.size / 2.0
	host.scale = Vector2(1.07, 1.07)
	host.create_tween().tween_property(host, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)


static func ignore_mouse_below(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse_below(child)

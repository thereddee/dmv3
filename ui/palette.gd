class_name Palette
extends RefCounted
## Placeholder look: flat colours and a few StyleBox helpers.

const BG := Color("1b1a18")
const PANEL := Color("262522")
const PANEL_DEAD := Color("1f1e1c")
const BORDER := Color("3a3835")
const TEXT := Color("eeeeee")
const MUTED := Color("9a9892")
const ACCENT := Color("4f8ff0")
const DANGER := Color("ef4444")
const SUCCESS := Color("22c55e")
const POISON := Color("a3d65c")
const GOLD := Color("f5c542")
const FLASH_HIT := Color(2.0, 0.6, 0.6)
const FLASH_HEAL := Color(0.7, 1.8, 0.8)
const FLASH_ACT := Color(1.5, 1.5, 1.9)

const CLASS_COLORS := {
	"tank": Color("7db4f0"),
	"healer": Color("9bd16e"),
	"dps": Color("f0997b"),
	"cc": Color("b0a6f5"),
}


static func panel(border: Color = BORDER, width: int = 1, bg: Color = PANEL) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(8)
	return box


## Flat button look. `primary` fills it with the accent colour.
## `left_pad` leaves room on the left for something drawn over the button.
static func style_button(button: Button, primary: bool = false, selected: bool = false, left_pad: int = 8) -> void:
	var base := ACCENT.darkened(0.35) if primary else PANEL
	var edge := ACCENT if primary or selected else BORDER
	var states := {
		"normal": panel(edge, 3 if selected else 1, base),
		"hover": panel(ACCENT, 2, base.lightened(0.08)),
		"pressed": panel(ACCENT, 3, base.darkened(0.15)),
		"hover_pressed": panel(ACCENT, 3, base.darkened(0.05)),
		"disabled": panel(BORDER, 1, PANEL_DEAD),
		"focus": StyleBoxEmpty.new(),
	}
	for state: String in states:
		var box: StyleBox = states[state]
		box.set_content_margin_all(8)
		box.content_margin_left = left_pad
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))


static func bar(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	return box


static func style_bar(progress: ProgressBar, fill: Color) -> void:
	progress.add_theme_stylebox_override("background", bar(BG))
	progress.add_theme_stylebox_override("fill", bar(fill))

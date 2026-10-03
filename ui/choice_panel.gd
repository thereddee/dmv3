class_name ChoicePanel
extends VBoxContainer
## A row of selectable cards with an info line and an optional confirm button.
## Shared by the draft, the monster pick and the loot.

signal selection_changed
signal confirmed
## Emitted when a click would exceed `max_select` (and max_select > 1).
signal limit_hit

const CARD_SIZE := Vector2(214, 118)

var max_select := 1
var _buttons: Array[Button] = []

@onready var _cards: HFlowContainer = $Cards
@onready var _info: Label = $Footer/InfoLabel
@onready var _confirm: Button = $Footer/ConfirmButton


func _ready() -> void:
	_info.add_theme_color_override("font_color", Palette.ACCENT)
	Palette.style_button(_confirm, true)
	_confirm.pressed.connect(func() -> void: confirmed.emit())


## `entries[i]` is the card text; `locked[i]` greys it out. Empty `confirm_text` hides the button.
func open(entries: Array[String], locked: Array[bool], p_max_select: int, confirm_text: String) -> void:
	max_select = p_max_select
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for i in entries.size():
		var button := Button.new()
		button.text = entries[i]
		button.toggle_mode = true
		button.disabled = locked[i]
		button.custom_minimum_size = CARD_SIZE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 13)
		Palette.style_button(button)
		button.toggled.connect(_on_toggled.bind(i))
		_cards.add_child(button)
		_buttons.append(button)
	_confirm.visible = confirm_text != ""
	_confirm.text = confirm_text


func selected() -> Array[int]:
	var out: Array[int] = []
	for i in _buttons.size():
		if _buttons[i].button_pressed:
			out.append(i)
	return out


func set_info(text: String) -> void:
	_info.text = text


func card(index: int) -> Button:
	return _buttons[index]


func confirm_button() -> Button:
	return _confirm


func _on_toggled(is_pressed: bool, index: int) -> void:
	if is_pressed and selected().size() > max_select:
		if max_select == 1:
			for i in _buttons.size():
				if i != index:
					_buttons[i].set_pressed_no_signal(false)
		else:
			_buttons[index].set_pressed_no_signal(false)
			limit_hit.emit()
			return
	selection_changed.emit()

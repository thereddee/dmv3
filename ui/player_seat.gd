class_name PlayerSeat
extends PanelContainer
## One player at the table. Shows a *displayed* HP and satisfaction that the
## event feed animates step by step; refresh() snaps them back to the model.

signal pressed(player: PlayerState)

const BAR_TIME := 0.25

var player: PlayerState
var _shown_hp := 0
var _shown_sat := 0
var _class_name := ""
var _archetype_name := ""

@onready var _name_label: Label = $Margin/VBox/Header/NameLabel
@onready var _target_label: Label = $Margin/VBox/Header/TargetLabel
@onready var _class_label: Label = $Margin/VBox/ClassLabel
@onready var _status_label: Label = $Margin/VBox/StatusLabel
@onready var _hp_label: Label = $Margin/VBox/HpLabel
@onready var _hp_bar: ProgressBar = $Margin/VBox/HpBar
@onready var _sat_label: Label = $Margin/VBox/SatLabel
@onready var _sat_bar: ProgressBar = $Margin/VBox/SatBar


func _ready() -> void:
	Fx.ignore_mouse_below(self)
	Palette.style_bar(_hp_bar, Palette.DANGER)
	Palette.style_bar(_sat_bar, Palette.SUCCESS)
	_target_label.text = Strings.UI_TARGET_MARK
	_target_label.add_theme_color_override("font_color", Palette.DANGER)
	_status_label.add_theme_color_override("font_color", Palette.GOLD)


func setup(p: PlayerState, content: ContentDB) -> void:
	player = p
	_class_name = content.classes[p.class_key].display_name
	_archetype_name = content.archetypes[p.archetype_key].display_name
	_sat_bar.max_value = content.tuning.max_satisfaction
	_class_label.add_theme_color_override("font_color", Palette.CLASS_COLORS.get(p.class_key, Palette.MUTED))


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(player)


## Snap to the model. `targeted`: the DM aims at this player; `pickable`: waiting for a card target.
func refresh(targeted: bool, pickable: bool) -> void:
	_shown_hp = player.hp
	_shown_sat = player.satisfaction
	_hp_bar.max_value = player.max_hp
	_hp_bar.value = _shown_hp
	_sat_bar.value = _shown_sat
	_target_label.visible = targeted
	_class_label.text = Strings.UI_SEAT_LINE % [_class_name, _archetype_name, player.atk]
	_draw_state(targeted, pickable)


func show_damage(amount: int, color: Color = Palette.DANGER) -> void:
	_set_hp(_shown_hp - amount)
	Fx.pop(self, "-%d" % amount, color, 26)
	Fx.flash(self, Palette.FLASH_HIT)


func show_heal(amount: int) -> void:
	_set_hp(_shown_hp + amount)
	Fx.pop(self, "+%d" % amount, Palette.SUCCESS, 24)
	Fx.flash(self, Palette.FLASH_HEAL)


func show_satisfaction(delta: int) -> void:
	_shown_sat = clampi(_shown_sat + delta, 0, int(_sat_bar.max_value))
	_sat_label.text = Strings.UI_SAT % _shown_sat
	create_tween().tween_property(_sat_bar, "value", _shown_sat, BAR_TIME)
	Fx.pop(self, "%+d ☺" % delta, Palette.SUCCESS if delta > 0 else Palette.GOLD, 18, 0.85)


func show_death() -> void:
	_set_hp(0)
	Fx.pop(self, Strings.UI_POP_DEAD, Palette.DANGER, 28)
	_draw_dead()


func show_note(text: String, color: Color = Palette.GOLD) -> void:
	Fx.pop(self, text, color, 18)


func show_acting() -> void:
	Fx.bump(self)


func _set_hp(value: int) -> void:
	_shown_hp = clampi(value, 0, player.max_hp)
	_hp_label.text = Strings.UI_HP % [_shown_hp, player.max_hp]
	create_tween().tween_property(_hp_bar, "value", _shown_hp, BAR_TIME)


func _draw_state(targeted: bool, pickable: bool) -> void:
	_name_label.text = player.display_name
	_hp_label.text = Strings.UI_HP % [_shown_hp, player.max_hp]
	_sat_label.text = Strings.UI_SAT % _shown_sat
	var pills := PackedStringArray()
	if player.status != Keys.STATUS_NONE:
		pills.append(Strings.UI_STATUS[player.status])
	if player.poisoned:
		pills.append(Strings.UI_POISONED)
	if player.inspired:
		pills.append(Strings.UI_INSPIRED)
	if player.skip_turn:
		pills.append(Strings.UI_SKIP_TURN)
	_status_label.text = " · ".join(pills) if not pills.is_empty() else " "
	if not player.alive:
		_draw_dead()
	elif targeted:
		add_theme_stylebox_override("panel", Palette.panel(Palette.DANGER, 3))
	elif pickable:
		add_theme_stylebox_override("panel", Palette.panel(Palette.ACCENT, 3))
	else:
		add_theme_stylebox_override("panel", Palette.panel())
	if player.alive:
		_name_label.add_theme_color_override("font_color", Palette.TEXT)


func _draw_dead() -> void:
	_name_label.text = player.display_name + Strings.UI_DEAD_MARK
	_name_label.add_theme_color_override("font_color", Palette.MUTED)
	_target_label.visible = false
	add_theme_stylebox_override("panel", Palette.panel(Palette.BORDER, 1, Palette.PANEL_DEAD))

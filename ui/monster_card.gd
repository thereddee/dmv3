class_name MonsterCard
extends PanelContainer
## One monster in the encounter. Click to arm or disarm its special.

signal pressed(monster: MonsterState)

const BAR_TIME := 0.25

var monster: MonsterState
var _shown_hp := 0

@onready var _name_label: Label = $Margin/VBox/Header/NameLabel
@onready var _state_label: Label = $Margin/VBox/Header/StateLabel
@onready var _hp_label: Label = $Margin/VBox/HpLabel
@onready var _hp_bar: ProgressBar = $Margin/VBox/HpBar
@onready var _atk_label: Label = $Margin/VBox/AtkLabel
@onready var _special_label: Label = $Margin/VBox/SpecialLabel


func _ready() -> void:
	Fx.ignore_mouse_below(self)
	Palette.style_bar(_hp_bar, Palette.DANGER)
	_state_label.add_theme_color_override("font_color", Palette.GOLD)
	_atk_label.add_theme_color_override("font_color", Palette.MUTED)


func setup(m: MonsterState) -> void:
	monster = m
	tooltip_text = m.data.quip


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(monster)


## Snap to the model.
func refresh() -> void:
	_shown_hp = maxi(0, monster.hp)
	_hp_bar.max_value = monster.max_hp
	_hp_bar.value = _shown_hp
	_hp_label.text = Strings.UI_HP % [_shown_hp, monster.max_hp]
	_name_label.text = monster.display_name
	_atk_label.text = Strings.UI_MONSTER_ATK % [monster.atk, monster.data.cost]
	if monster.stunned:
		_state_label.text = Strings.UI_STUNNED
	elif monster.hesitating:
		_state_label.text = Strings.UI_HESITATES
	else:
		_state_label.text = ""
	if not monster.is_up():
		_draw_dead()
		return
	modulate = Color.WHITE
	var info := [monster.data.special_name, monster.data.special_desc]
	if monster.special_used:
		_special_label.text = Strings.UI_SPECIAL_USED
		_special_label.add_theme_color_override("font_color", Palette.MUTED)
		add_theme_stylebox_override("panel", Palette.panel())
	elif monster.special_armed:
		_special_label.text = Strings.UI_SPECIAL_ARMED % info
		_special_label.add_theme_color_override("font_color", Palette.ACCENT)
		add_theme_stylebox_override("panel", Palette.panel(Palette.ACCENT, 3))
	else:
		_special_label.text = Strings.UI_SPECIAL % info
		_special_label.add_theme_color_override("font_color", Palette.TEXT)
		add_theme_stylebox_override("panel", Palette.panel())


func show_damage(amount: int) -> void:
	_set_hp(_shown_hp - amount)
	Fx.pop(self, "-%d" % amount, Palette.TEXT, 26)
	Fx.flash(self, Palette.FLASH_HIT)


func show_heal(amount: int) -> void:
	_set_hp(_shown_hp + amount)
	Fx.pop(self, "+%d" % amount, Palette.SUCCESS, 24)
	Fx.flash(self, Palette.FLASH_HEAL)


func show_death() -> void:
	_set_hp(0)
	_draw_dead()


func show_note(text: String, color: Color = Palette.GOLD) -> void:
	Fx.pop(self, text, color, 18, 0.55)


func show_acting() -> void:
	Fx.bump(self)
	Fx.flash(self, Palette.FLASH_ACT)


func show_special() -> void:
	Fx.bump(self)
	Fx.pop(self, "✦ " + monster.data.special_name, Palette.ACCENT, 20)
	_special_label.text = Strings.UI_SPECIAL_USED
	_special_label.add_theme_color_override("font_color", Palette.MUTED)
	add_theme_stylebox_override("panel", Palette.panel())


func show_atk(atk: int) -> void:
	_atk_label.text = Strings.UI_MONSTER_ATK % [atk, monster.data.cost]


func _set_hp(value: int) -> void:
	_shown_hp = clampi(value, 0, monster.max_hp)
	_hp_label.text = Strings.UI_HP % [_shown_hp, monster.max_hp]
	create_tween().tween_property(_hp_bar, "value", _shown_hp, BAR_TIME)


func _draw_dead() -> void:
	_name_label.text = monster.display_name + Strings.UI_DEAD_MARK
	_special_label.text = " "
	_state_label.text = ""
	add_theme_stylebox_override("panel", Palette.panel(Palette.BORDER, 1, Palette.PANEL_DEAD))
	create_tween().tween_property(self, "modulate", Color(1, 1, 1, 0.4), 0.3)

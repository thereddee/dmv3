class_name CharacterPortrait
extends Control
## A CharacterSprite boxed for Control layouts: reserves the canvas size and keeps the feet at the bottom centre.

const DEAD_TINT := Color(0.35, 0.35, 0.4)

var _display_scale := 0.5

@onready var _sprite: CharacterSprite = $CharacterSprite


func _ready() -> void:
	resized.connect(_place)


## Hides itself when the player has no generated appearance (fixed v0 party).
func setup(appearance: CharacterAppearance, content: ContentDB, display_scale: float = 0.5) -> void:
	visible = appearance != null
	if appearance == null:
		return
	_display_scale = display_scale
	custom_minimum_size = CharacterSprite.CANVAS * display_scale
	_sprite.apply(appearance, content, display_scale)
	_place()


func set_dead(dead: bool) -> void:
	_sprite.modulate = DEAD_TINT if dead else Color.WHITE


func _place() -> void:
	_sprite.position = Vector2(size.x / 2.0, size.y)

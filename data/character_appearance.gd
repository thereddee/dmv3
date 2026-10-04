class_name CharacterAppearance
extends Resource
## What a generated player looks like: one part per layer plus three tints.
## Parts are referenced by id (CharacterPart.id), "" meaning nothing on that layer.

## Paper-doll layers, back to front. ui/character_sprite.tscn has one Sprite2D per entry.
const LAYERS: Array[String] = [
	"hair_back", "back_item", "body", "race_traits", "face",
	"outfit", "facial_hair", "hair_front", "accessory", "weapon",
]
const TINT_SKIN := "skin"
const TINT_HAIR := "hair"
const TINT_ACCENT := "accent"
## Which tint each layer takes. Layers not listed keep their own colours.
const LAYER_TINT := {
	"hair_back": TINT_HAIR,
	"back_item": TINT_ACCENT,
	"body": TINT_SKIN,
	"race_traits": TINT_SKIN,
	"outfit": TINT_ACCENT,
	"facial_hair": TINT_HAIR,
	"hair_front": TINT_HAIR,
}
## Layers that may stay empty even when parts exist for them.
const OPTIONAL_LAYERS: Array[String] = ["back_item", "facial_hair", "accessory"]

@export var parts: Dictionary[String, String] = {}
@export var skin: Color = Color.WHITE
@export var hair: Color = Color.WHITE
@export var accent: Color = Color.WHITE
## Uniform scale of the whole stack (race size).
@export var scale: float = 1.0


func tint_for(layer: String) -> Color:
	match LAYER_TINT.get(layer, ""):
		TINT_SKIN:
			return skin
		TINT_HAIR:
			return hair
		TINT_ACCENT:
			return accent
	return Color.WHITE

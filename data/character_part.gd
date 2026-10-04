class_name CharacterPart
extends Resource
## One drawing for one paper-doll layer. Adding art = a PNG in assets/characters/<layer>/
## plus one of these in data/character_parts/.

@export var id: String = ""
## One of CharacterAppearance.LAYERS.
@export var layer: String = ""
## 128x192, feet at the bottom centre, greyscale where the layer is tinted.
@export var texture: Texture2D
## Class this part belongs to (outfit, weapon, back item). Empty = any class.
@export var class_key: String = ""
## Race this part belongs to (race traits). Empty = any race.
@export var race_key: String = ""
## Body types that can wear it ("a", "b"). Empty = both.
@export var body_types: Array[String] = []


func fits(p_class_key: String, p_race_key: String, body_type: String) -> bool:
	return (class_key == "" or class_key == p_class_key) \
			and (race_key == "" or race_key == p_race_key) \
			and (body_types.is_empty() or body_types.has(body_type))

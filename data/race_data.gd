class_name RaceData
extends Resource
## Cosmetic in v0: size and palettes only.

@export var key: String = ""
@export var display_name: String = ""
## Uniform scale of the character sprite.
@export var scale: float = 1.0
## PlayerAppearance race id used by the table-player drawing.
@export var table_race: String = "humain"
@export var skin_tones: Array[Color] = []
@export var hair_colours: Array[Color] = []

class_name LootData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var atk: int = 0
@export var hp: int = 0
@export var satisfaction: int = 0
## Class this item fits (Keys.TANK...). Empty = any class.
@export var class_key: String = ""
@export var heal_bonus: int = 0
@export var stun_bonus: float = 0.0
@export var legendary: bool = false

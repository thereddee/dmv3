class_name ClassData
extends Resource

@export var key: String = ""
@export var display_name: String = ""
@export var blurb: String = ""
## Base stats of a generated player of this class.
@export var hp: int = 20
@export var atk: int = 4
@export var heal_power: int = 4
@export var stun_chance: float = 0.5
## Outfit tints a generated player of this class can roll.
@export var accent_colours: Array[Color] = []
## Satisfaction gained / lost at encounter end when the class hook is met / missed.
@export var satisfaction_bonus: int = 0
@export var satisfaction_malus: int = 0

class_name MonsterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: int = 1
@export var atk: int = 1
@export var cost: int = 1
## Targeting key resolved by core/behaviours.gd.
@export var behaviour: String = "random"
## Special key resolved by core/specials.gd.
@export var special: String = ""
@export var special_name: String = ""
@export var special_desc: String = ""
## Magnitude of the special (HP healed, ATK bonus, damage multiplier, attack count...).
@export var special_value: float = 0.0
## Monster id summoned by the "raise" special.
@export var special_summon: String = ""
## See Keys.FLAG_*.
@export var flags: Array[String] = []
@export var quip: String = ""


func has_flag(flag: String) -> bool:
	return flags.has(flag)

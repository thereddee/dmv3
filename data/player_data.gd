class_name PlayerData
extends Resource

@export var display_name: String = ""
@export var seat: int = 0
@export var class_key: String = ""
@export var archetype_key: String = ""
@export var hp: int = 20
@export var atk: int = 4
@export var heal_power: int = 4
@export var stun_chance: float = 0.5
## Cosmetic in v0.
@export var race_key: String = ""
@export var body_type: String = "a"
## One-line table quirk, flavour only.
@export var quirk: String = ""
## Null for the fixed v0 party: the seat then shows no portrait.
@export var appearance: CharacterAppearance
## Procedural look shown on the seats (ui/table_player). Null for the fixed v0 party.
@export var table_look: PlayerAppearance

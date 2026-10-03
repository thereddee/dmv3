class_name PlayerState
extends RefCounted
## Runtime state of one player at the table.

var data: PlayerData
var display_name: String
var class_key: String
var archetype_key: String
var hp: int
var max_hp: int
var atk: int
var satisfaction: int
var alive := true
var status := Keys.STATUS_NONE
var poisoned := false
var inspired := false
var skip_turn := false
var heal_power: int
var stun_chance: float

# Per-encounter counters, reset when a fight starts.
var enc_start_hp := 0
var enc_taken := 0
var enc_dealt := 0
var enc_kills := 0
var enc_healed := 0
var enc_stuns := 0


func _init(p_data: PlayerData, start_satisfaction: int) -> void:
	data = p_data
	display_name = p_data.display_name
	class_key = p_data.class_key
	archetype_key = p_data.archetype_key
	hp = p_data.hp
	max_hp = p_data.hp
	atk = p_data.atk
	heal_power = p_data.heal_power
	stun_chance = p_data.stun_chance
	satisfaction = start_satisfaction


## Back at the table with a fresh character: base stats, no loot. Satisfaction is kept.
func reroll(stat_ratio: float = 1.0) -> void:
	max_hp = maxi(1, roundi(data.hp * stat_ratio))
	hp = max_hp
	atk = maxi(1, roundi(data.atk * stat_ratio))
	heal_power = data.heal_power
	stun_chance = data.stun_chance
	alive = true


func is_up() -> bool:
	return alive and hp > 0


func reset_encounter_counters() -> void:
	enc_start_hp = hp
	enc_taken = 0
	enc_dealt = 0
	enc_kills = 0
	enc_healed = 0
	enc_stuns = 0

class_name MonsterState
extends RefCounted
## Runtime state of one monster in the current encounter.

var data: MonsterData
var display_name: String
var hp: int
var max_hp: int
var atk: int
var stunned := false
var hesitating := false
var special_used := false
var special_armed := false


func _init(p_data: MonsterData, p_special_used: bool = false) -> void:
	data = p_data
	display_name = p_data.display_name
	hp = p_data.hp
	max_hp = p_data.hp
	atk = p_data.atk
	special_used = p_special_used


func is_up() -> bool:
	return hp > 0

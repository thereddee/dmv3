class_name DeckCard
extends RefCounted
## A drafted monster card. Each card is used once per night.

var data: MonsterData
var used := false


func _init(p_data: MonsterData) -> void:
	data = p_data

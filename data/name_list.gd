class_name NameList
extends Resource
## First names for generated players, per body type.

@export var names_a: Array[String] = []
@export var names_b: Array[String] = []


func for_body_type(body_type: String) -> Array[String]:
	return names_b if body_type == "b" else names_a

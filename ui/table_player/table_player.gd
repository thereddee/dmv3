class_name TablePlayer
extends Node2D
## One player sitting at the table, drawn procedurally from a PlayerAppearance
## (reference/table-des-joueurs.html). The origin is the figure's local (0, 0); the centre line is
## x = 100 and the table edge y = 192, so a seat is placed at (seat_x - 100, top).
## `Back` is everything behind the table and sinks by race height; `Front` (hands, prop) is
## raised above the table, which must sit in between (z_index 1).

const FRONT_Z := 2

var appearance: PlayerAppearance
## Seat index: offsets this player's idle phase so the table does not breathe in unison.
var seat := 0
var animate := true
## See TablePlayerBuilder.stroke_mult; set before apply().
var stroke_mult := 1.0
## Animation groups by G() key, see TablePlayerBuilder.groups.
var groups: Dictionary = {}
var geo: Dictionary = {}

@onready var _back: Node2D = $Back
@onready var _front: Node2D = $Front


func apply(new_appearance: PlayerAppearance) -> void:
	appearance = new_appearance
	for container in [_back, _front]:
		for child in container.get_children():
			container.remove_child(child)
			child.free()
	var builder := TablePlayerBuilder.new()
	builder.stroke_mult = stroke_mult
	builder.build(appearance, _back, _front)
	groups = builder.groups
	geo = builder.geo

func _process(_delta: float) -> void:
	if animate and appearance != null:
		apply_pose(TablePlayerPose.pose_at(seat, appearance, Time.get_ticks_msec() / 1000.0, geo))


## Applies a pose from TablePlayerPose to the animation groups; groups it omits go back to rest.
func apply_pose(pose: Dictionary) -> void:
	for key: String in groups:
		var node: PlayerLayer = groups[key]
		var p: Dictionary = pose.get(key, {})
		node.position = node.rest_position + Vector2(p.get("tx", 0.0), p.get("ty", 0.0))
		node.rotation_degrees = p.get("r", 0.0)
		node.scale = Vector2(p.get("sx", 1.0), p.get("sy", 1.0))
		node.modulate.a = p.get("op", 1.0)

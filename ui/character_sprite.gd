class_name CharacterSprite
extends Node2D
## Layered paper doll: one Sprite2D per CharacterAppearance.LAYERS entry, in that order.
## Every texture shares the 128x192 canvas and the feet anchor, which is this node's origin.

const CANVAS := Vector2(128, 192)


func apply(appearance: CharacterAppearance, content: ContentDB, display_scale: float = 1.0) -> void:
	scale = Vector2.ONE * appearance.scale * display_scale
	for layer in CharacterAppearance.LAYERS:
		var sprite: Sprite2D = get_node(layer)
		var part := content.part_by_id(appearance.parts.get(layer, ""))
		sprite.texture = part.texture if part != null else null
		sprite.modulate = appearance.tint_for(layer)

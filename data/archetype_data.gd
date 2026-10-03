class_name ArchetypeData
extends Resource

@export var key: String = ""
@export var display_name: String = ""
@export var blurb: String = ""
## Satisfaction gained / lost at encounter end when the archetype hook is met / missed.
## Rule Lawyer: bonus = small fight, malus = Fudge triggered.
@export var satisfaction_bonus: int = 0
@export var satisfaction_malus: int = 0

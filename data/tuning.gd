class_name Tuning
extends Resource
## Every tuning number of Rules v0. Edit data/tuning.tres, not this script.

@export_group("Campaign")
@export var nights: int = 3
@export var encounters_per_night: int = 3
@export var rounds_before_midnight: int = 18
@export var max_rounds_per_encounter: int = 8
@export var budget_base: int = 5
@export var budget_per_night: int = 2
@export var draft_offer: int = 7
@export var draft_keep: int = 5
@export var flee_round_cost: int = 2
@export var flee_satisfaction_penalty: int = 8
@export var skip_satisfaction_penalty: int = 8
@export var recover_ratio: float = 0.35
## Share of base HP and ATK a rerolled character comes back with.
@export var reroll_stat_ratio: float = 0.8
## Satisfaction every other living player loses when someone dies.
@export var death_grief: int = 0

@export_group("Players")
## Candidates generated at campaign start; 0 uses the fixed party in data/party.
@export var party_candidates: int = 6
@export var party_size: int = 4
## Chance an optional appearance layer (accessory, facial hair, back item) stays empty.
@export var optional_layer_empty_chance: float = 0.5
@export var start_satisfaction: int = 50
@export var max_satisfaction: int = 100
@export var damage_die: int = 3
@export var damage_offset: int = -1
@export var heal_threshold: float = 0.4
@export var heal_die: int = 3
@export var inspiration_mult: int = 2
@export var stun_chance_cap: float = 0.9

@export_group("Statuses")
@export var status_chance: float = 0.75
@export var phone_skip_rounds: int = 3
## Players below this satisfaction start the encounter on their phone. 0 disables.
@export var bored_threshold: int = 40
@export var dice_tower_crit_chance: float = 0.25
@export var dice_tower_crit_mult: int = 2
@export var toxic_penalty: int = 6

@export_group("Monsters")
@export var taunt_chance: float = 0.5
@export var main_character_chance: float = 0.3
@export var poison_damage: int = 3
@export var multi_targets: int = 3
@export var multi_damage_factor: float = 0.5

@export_group("DM cards")
@export var dm_start_hand: int = 2
@export var dm_hand_size: int = 3
@export var dm_cards_per_round: int = 1
@export var fudge_survive_hp: int = 1
@export var reinforcement_max_cost: int = 2
@export var narration_satisfaction: int = 6
@export var narration_hobo_satisfaction: int = -6
@export var inspiration_satisfaction: int = 5
@export var crit_mult: float = 1.5

@export_group("Satisfaction")
@export var thrill_low: float = 0.15
@export var thrill_high: float = 0.6
@export var satisfaction_bored: int = -15
@export var satisfaction_good: int = 12
@export var satisfaction_great: int = 25
@export var timeout_penalty: int = 10
@export var rule_lawyer_max_monsters: int = 2

@export_group("Table look")
## Satisfaction from which a seat's face reads happy / focused / bored; below the last it is angry.
@export var mood_content_min: int = 70
@export var mood_focused_min: int = 45
@export var mood_bored_min: int = 25
## How long a seat looks surprised after taking damage.
@export var surprise_seconds: float = 1.2

@export_group("Loot")
@export var loot_offer: int = 3
@export var off_class_factor: float = 0.5
@export var jealousy: int = 4
@export var legendary_min_night: int = 2

@export_group("Score")
@export var power_atk_weight: int = 2
@export var power_hp_divisor: float = 5.0

## Face of a seat at this satisfaction (PlayerAppearance mood id).
func mood_for(satisfaction: int) -> String:
	if satisfaction >= mood_content_min:
		return PlayerAppearance.MOOD_CONTENT
	if satisfaction >= mood_focused_min:
		return PlayerAppearance.MOOD_FOCUSED
	if satisfaction >= mood_bored_min:
		return PlayerAppearance.MOOD_BORED
	return PlayerAppearance.MOOD_ANGRY

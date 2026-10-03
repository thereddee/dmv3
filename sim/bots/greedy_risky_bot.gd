class_name GreedyRiskyBot
extends SimBot
## Max budget, targets the lowest-HP player, arms every special, never flees.
## Its only brake: it fudges a lethal round when it happens to hold the card.

const OFFENSIVE: Array[String] = [DmEffects.CRIT, DmEffects.REINFORCEMENTS, DmEffects.INSPIRATION]


func label() -> String:
	return "greedy-risky"


func draft(c: Campaign) -> void:
	draft_sorted(c, true)


func pick(c: Campaign) -> void:
	pick_max_budget(c)


func play_round(c: Campaign) -> void:
	var weakest: PlayerState = null
	var strongest: PlayerState = null
	for p in c.alive_players():
		if weakest == null or p.hp < weakest.hp:
			weakest = p
		if strongest == null or p.atk > strongest.atk:
			strongest = p
	c.set_target(weakest)
	for m in c.alive_monsters():
		c.arm_special(m)
	var fudge := find_card(c, DmEffects.FUDGE)
	if fudge != null and weakest.hp <= focus_threat(c):
		c.play_dm_card(fudge)
	else:
		for effect in OFFENSIVE:
			var card := find_card(c, effect)
			if card != null:
				c.play_dm_card(card, strongest)
				break
	c.resolve_round()


func loot(c: Campaign) -> void:
	# Score gained by the recipient; jealousy is the same whoever gets it.
	give_best(c, func(item: LootData, p: PlayerState) -> float:
		var sat := mini(c.tuning.max_satisfaction, p.satisfaction + c.loot_satisfaction(item, p))
		var pow_after := (p.atk + item.atk) * c.tuning.power_atk_weight + roundi((p.max_hp + item.hp) / c.tuning.power_hp_divisor)
		return float(pow_after * sat - c.power(p) * p.satisfaction))

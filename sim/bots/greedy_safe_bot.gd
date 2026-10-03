class_name GreedySafeBot
extends SimBot
## Always targets the tank, never arms specials, flees at any death risk.
## Uses the full budget like greedy-risky: only the way it runs the fight differs.

enum Risk { NONE, DAMAGE, POISON }


func label() -> String:
	return "greedy-safe"


func draft(c: Campaign) -> void:
	draft_sorted(c, true)


func pick(c: Campaign) -> void:
	pick_max_budget(c)


func play_round(c: Campaign) -> void:
	var aim := _tank_or_sturdiest(c)
	c.set_target(aim)
	var risk := _death_risk(c, aim)
	if risk == Risk.POISON:
		c.flee()
		return
	if risk == Risk.DAMAGE:
		var saver := find_card(c, DmEffects.FUDGE)
		if saver == null:
			saver = find_card(c, DmEffects.NARRATION)
		if saver == null:
			c.flee()
			return
		c.play_dm_card(saver)
	else:
		var bonus := find_card(c, DmEffects.INSPIRATION)
		if bonus != null:
			c.play_dm_card(bonus, _strongest(c))
		else:
			bonus = find_card(c, DmEffects.NARRATION)
			if bonus != null:
				c.play_dm_card(bonus)
	c.resolve_round()


func loot(c: Campaign) -> void:
	give_best(c, func(item: LootData, p: PlayerState) -> float:
		return c.loot_satisfaction(item, p) + 0.01 * (item.hp + item.atk))


## Worst case this round: every roll maxed, no stun, no monster killed first.
func _death_risk(c: Campaign, aim: PlayerState) -> Risk:
	var t := c.tuning
	var max_roll := t.damage_die - 1 + t.damage_offset
	var alive := c.alive_players()
	var result := Risk.NONE
	for i in alive.size():
		var p := alive[i]
		var threat := 0
		if p.poisoned:
			if p.hp <= t.poison_damage:
				return Risk.POISON
			threat += t.poison_damage
		for m in c.alive_monsters():
			if Behaviours.is_split(m.data.behaviour):
				if i < t.multi_targets:
					threat += ceili((m.atk + max_roll) * t.multi_damage_factor)
			elif p == aim:
				threat += m.atk + max_roll
		if threat >= p.hp:
			result = Risk.DAMAGE
	return result


func _tank_or_sturdiest(c: Campaign) -> PlayerState:
	var best: PlayerState = null
	for p in c.alive_players():
		if p.class_key == Keys.TANK:
			return p
		if best == null or p.hp > best.hp:
			best = p
	return best


func _strongest(c: Campaign) -> PlayerState:
	var best: PlayerState = null
	for p in c.alive_players():
		if best == null or p.atk > best.atk:
			best = p
	return best

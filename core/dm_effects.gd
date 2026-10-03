class_name DmEffects
extends RefCounted
## Registry of DM card effects, keyed by DmCardData.effect.

const FUDGE := "fudge"
const REINFORCEMENTS := "reinforcements"
const NARRATION := "narration"
const INSPIRATION := "inspiration"
const CRIT := "crit"
const HESITATE := "hesitate"


## Returns false when the card cannot be played (missing or invalid target).
static func apply(c: Campaign, card: DmCardData, target: PlayerState) -> bool:
	var t := c.tuning
	match card.effect:
		FUDGE:
			c.fudge_active = true
			c.emit_event("dm_card", Strings.DM_FUDGE, {"card": card})
		REINFORCEMENTS:
			var pool: Array[MonsterData] = []
			for m in c.content.monsters:
				if m.cost <= t.reinforcement_max_cost:
					pool.append(m)
			if pool.is_empty():
				return false
			var data: MonsterData = pool[c.rng.randi_range(0, pool.size() - 1)]
			c.add_monster(data, false)
			c.emit_event("dm_card", Strings.DM_REINFORCEMENTS % data.display_name, {"card": card})
		NARRATION:
			c.narration_active = true
			c.chronicle.narrations += 1
			c.emit_event("dm_card", Strings.DM_NARRATION % c.flavour_name(), {"card": card})
			for p in c.party:
				if p.alive:
					var hobo := p.archetype_key == Keys.MURDER_HOBO
					c.add_satisfaction(p, t.narration_hobo_satisfaction if hobo else t.narration_satisfaction)
		INSPIRATION:
			if target == null or not target.is_up():
				return false
			target.inspired = true
			c.emit_event("dm_card", Strings.DM_INSPIRATION % target.display_name, {"card": card, "player": target})
			c.add_satisfaction(target, t.inspiration_satisfaction)
		CRIT:
			c.crit_active = true
			c.emit_event("dm_card", Strings.DM_CRIT, {"card": card})
		HESITATE:
			var best: MonsterState = null
			for m in c.monsters:
				if m.is_up() and not m.hesitating and (best == null or m.atk > best.atk):
					best = m
			if best != null:
				best.hesitating = true
				c.emit_event("dm_card", Strings.DM_HESITATE % best.display_name, {"card": card, "monster": best})
		_:
			push_error("Unknown DM card effect key: %s" % card.effect)
			return false
	return true

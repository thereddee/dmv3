class_name Specials
extends RefCounted
## Registry of monster special attacks, keyed by MonsterData.special.
## Magnitudes come from MonsterData.special_value.

const SWARM := "swarm"
const TRAP := "trap"
const REGEN := "regen"
const DOUBLE_DAMAGE := "double_damage"
const WEB := "web"
const HOWL := "howl"
const MONOLOGUE := "monologue"
const RAISE := "raise"
const BREATH := "breath"


## What the special changes about the monster's normal attack this round.
class Outcome:
	extends RefCounted
	var mult := 1.0
	var times := 1
	var skip_attack := false


static func resolve(c: Campaign, m: MonsterState, alive: Array[PlayerState], mult: float) -> Outcome:
	var out := Outcome.new()
	var value := m.data.special_value
	match m.data.special:
		REGEN:
			var healed := mini(m.max_hp, m.hp + int(value)) - m.hp
			m.hp += healed
			c.emit_event("monster_healed", "", {"monster": m, "amount": healed})
		HOWL:
			for x in c.monsters:
				x.atk += int(value)
			c.emit_event("monsters_buffed", "", {"amount": int(value)})
		MONOLOGUE:
			for p in c.party:
				if p.alive:
					c.add_satisfaction(p, int(value))
			c.chronicle.monologues += 1
			c.emit_event("monologue", Strings.MONOLOGUE % c.flavour_name())
			out.skip_attack = true
		RAISE:
			var summoned := c.content.monster_by_id(m.data.special_summon)
			if summoned != null:
				c.add_monster(summoned, true)
		DOUBLE_DAMAGE:
			out.mult = value
		SWARM:
			out.times = int(value)
		BREATH:
			for t in alive:
				c.hit(m, t, ceili(m.atk * mult * value))
			out.skip_attack = true
		WEB:
			var webbed := Behaviours.single_target(c, m, alive)
			webbed.skip_turn = true
			c.emit_event("webbed", Strings.WEBBED % webbed.display_name, {"player": webbed})
		TRAP:
			c.poison(Behaviours.single_target(c, m, alive))
		_:
			push_error("Unknown monster special key: %s" % m.data.special)
	return out

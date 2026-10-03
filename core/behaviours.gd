class_name Behaviours
extends RefCounted
## Registry of monster targeting behaviours, keyed by MonsterData.behaviour.
## With a DM target: taunt can intercept (assassins excepted), else the DM target.
## Without: assassin -> taunt -> Main Character -> behaviour.

const RANDOM := "random"
const WEAKEST := "weakest"
const STRONGEST := "strongest"
const HOBO := "murder_hobo"
const ASSASSIN := "assassin"
const MULTI := "multi"


## True when the behaviour spreads its attack (damage scaled by tuning.multi_damage_factor).
static func is_split(key: String) -> bool:
	return key == MULTI


## Players hit by one attack of this monster.
static func targets(c: Campaign, m: MonsterState, alive: Array[PlayerState]) -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	if m.data.behaviour == MULTI:
		out.assign(alive.slice(0, c.tuning.multi_targets))
	else:
		out.append(single_target(c, m, alive))
	return out


## DM override first, then the monster's own choice.
static func single_target(c: Campaign, m: MonsterState, alive: Array[PlayerState]) -> PlayerState:
	if c.target != null and c.target.is_up():
		# The tank can still step in front of the DM's pick. Assassins ignore taunt.
		if m.data.behaviour != ASSASSIN:
			var tank := _first_of_class(alive, Keys.TANK)
			if tank != null and tank != c.target and c.chance(c.tuning.taunt_chance):
				return tank
		return c.target
	return choose(c, m, alive)


static func choose(c: Campaign, m: MonsterState, alive: Array[PlayerState]) -> PlayerState:
	var key := m.data.behaviour
	if key == ASSASSIN:
		var healer := _first_of_class(alive, Keys.HEALER)
		return healer if healer != null else _lowest_hp(alive)
	var tank := _first_of_class(alive, Keys.TANK)
	if tank != null and c.chance(c.tuning.taunt_chance):
		return tank
	var mc := _first_of_archetype(alive, Keys.MAIN_CHARACTER)
	if mc != null and c.chance(c.tuning.main_character_chance):
		return mc
	match key:
		STRONGEST:
			return _highest_atk(alive)
		WEAKEST:
			return _lowest_hp(alive)
		HOBO:
			var hobo := _first_of_archetype(alive, Keys.MURDER_HOBO)
			return hobo if hobo != null else c.pick_player(alive)
		RANDOM, MULTI:
			return c.pick_player(alive)
	push_error("Unknown monster behaviour key: %s" % key)
	return c.pick_player(alive)


static func _first_of_class(alive: Array[PlayerState], key: String) -> PlayerState:
	for p in alive:
		if p.class_key == key:
			return p
	return null


static func _first_of_archetype(alive: Array[PlayerState], key: String) -> PlayerState:
	for p in alive:
		if p.archetype_key == key:
			return p
	return null


static func _lowest_hp(alive: Array[PlayerState]) -> PlayerState:
	var best := alive[0]
	for p in alive:
		if p.hp < best.hp:
			best = p
	return best


static func _highest_atk(alive: Array[PlayerState]) -> PlayerState:
	var best := alive[0]
	for p in alive:
		if p.atk > best.atk:
			best = p
	return best

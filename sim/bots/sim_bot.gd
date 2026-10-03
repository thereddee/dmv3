class_name SimBot
extends RefCounted
## Base class for headless bots. One method per decision phase.

var rng := RandomNumberGenerator.new()


func label() -> String:
	return "bot"


## Default table: one of each class when the candidates allow it, then whoever is left.
func recruit(c: Campaign) -> void:
	var picks: Array[PlayerData] = []
	for class_key: String in [Keys.TANK, Keys.HEALER, Keys.DPS, Keys.CC]:
		for d in c.candidates:
			if d.class_key == class_key and not picks.has(d) and picks.size() < c.tuning.party_size:
				picks.append(d)
				break
	for d in c.candidates:
		if not picks.has(d) and picks.size() < c.tuning.party_size:
			picks.append(d)
	c.recruit(picks)


func draft(_c: Campaign) -> void:
	pass


func pick(_c: Campaign) -> void:
	pass


func play_round(_c: Campaign) -> void:
	pass


func loot(_c: Campaign) -> void:
	pass


## Drives one campaign to its end.
func play(c: Campaign) -> void:
	rng.seed = c.seed_value + 7919
	c.start()
	var guard := 0
	while c.phase != Campaign.Phase.OVER and guard < 10000:
		guard += 1
		match c.phase:
			Campaign.Phase.RECRUIT:
				recruit(c)
			Campaign.Phase.DRAFT:
				draft(c)
			Campaign.Phase.PICK:
				pick(c)
			Campaign.Phase.FIGHT:
				play_round(c)
			Campaign.Phase.LOOT:
				loot(c)
	if guard >= 10000:
		push_error("%s got stuck in phase %d" % [label(), c.phase])


# ===== Shared helpers =====

func draft_sorted(c: Campaign, expensive_first: bool) -> void:
	var sorted := c.offer.duplicate()
	sorted.sort_custom(func(a: MonsterData, b: MonsterData) -> bool:
		return a.cost > b.cost if expensive_first else a.cost < b.cost)
	var picks: Array[MonsterData] = []
	picks.assign(sorted.slice(0, c.tuning.draft_keep))
	c.draft_pick(picks)


## Spends as much budget as possible, keeping one card for each later encounter.
func pick_max_budget(c: Campaign) -> void:
	var unused := c.unused_cards()
	unused.sort_custom(func(a: DeckCard, b: DeckCard) -> bool: return a.data.cost > b.data.cost)
	var spendable := maxi(1, unused.size() - (encounters_left(c) - 1))
	var cards: Array[DeckCard] = []
	var cost := 0
	for card in unused:
		if cards.size() < spendable and cost + card.data.cost <= c.budget:
			cards.append(card)
			cost += card.data.cost
	if cards.is_empty():
		cards.append(unused[-1])
	c.start_encounter(cards)


## Sum of every living monster's best roll: what one focused player can take this round.
func focus_threat(c: Campaign) -> int:
	var max_roll := c.tuning.damage_die - 1 + c.tuning.damage_offset
	var threat := 0
	for m in c.alive_monsters():
		threat += m.atk + max_roll
	return threat


func encounters_left(c: Campaign) -> int:
	return c.tuning.encounters_per_night - c.encounter + 1


func find_card(c: Campaign, effect: String) -> DmCardData:
	for card in c.hand:
		if card.effect == effect:
			return card
	return null


## Gives the (item, player) pair with the best value according to `value`.
func give_best(c: Campaign, value: Callable) -> void:
	var best_item: LootData = null
	var best_player: PlayerState = null
	var best_value := -INF
	for item in c.loot_offer:
		for p in c.party:
			if not p.alive:
				continue
			var v: float = value.call(item, p)
			if v > best_value:
				best_value = v
				best_item = item
				best_player = p
	c.give_loot(best_item, best_player)
